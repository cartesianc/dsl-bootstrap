module Main
  ( main
  ) where

import Control.Concurrent
  ( MVar
  , forkIO
  , newEmptyMVar
  , putMVar
  , takeMVar
  )
import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import Data.List
  ( isInfixOf )
import System.Environment
  ( getArgs )
import System.Exit
  ( ExitCode (..) )
import qualified System.Process as Process

import Framework.TrustBase
  ( SchemaCatalogEvidencePayload
  , renderSchemaCatalogEvidencePayload
  , renderSchemaCatalogEvidencePayloadsJson
  , schemaCatalogEvidence
  , schemaCatalogEvidencePayloadPassed
  , trustBaseManifestRequiredJsonSchemas
  )

data SchemaCatalogEntry = SchemaCatalogEntry
  { schemaCatalogEntrySchema :: String
  , schemaCatalogEntryCommand :: String
  }
  deriving (Eq, Show)

main :: IO ()
main = do
  args <- getArgs
  payloads <- schemaCatalogPayloads trustBaseManifestRequiredJsonSchemas
  let failedPayloads =
        filter (not . schemaCatalogEvidencePayloadPassed) payloads
  case args of
    ["--json"] -> do
      putStrLn (renderSchemaCatalogEvidencePayloadsJson payloads)
      failWhenEvidenceFailed failedPayloads
    _ -> do
      putStrLn "[witness] schema catalog evidence payloads"
      mapM_ putStrLn (concatMap renderPayloadBlock payloads)
      putStrLn
        ( "[witness] "
            ++ statusText payloads
            ++ " schema catalog evidence "
            ++ show (length payloads)
            ++ " payload claims"
        )
      failWhenEvidenceFailed failedPayloads

schemaCatalogPayloads :: [String] -> IO [SchemaCatalogEvidencePayload]
schemaCatalogPayloads entries =
  fmap concat (mapM schemaCatalogPayloadChunk (chunksOf schemaCatalogParallelism entries))

schemaCatalogParallelism :: Int
schemaCatalogParallelism =
  4

schemaCatalogPayloadChunk :: [String] -> IO [SchemaCatalogEvidencePayload]
schemaCatalogPayloadChunk entries = do
  resultVars <- mapM startPayload entries
  mapM takeMVar resultVars
  where
    startPayload :: String -> IO (MVar SchemaCatalogEvidencePayload)
    startPayload entryText = do
      resultVar <- newEmptyMVar
      _ <-
        forkIO $ do
          result <- try (schemaCatalogPayload entryText)
          putMVar resultVar (schemaCatalogPayloadResult entryText result)
      pure resultVar

schemaCatalogPayloadResult :: String -> Either SomeException SchemaCatalogEvidencePayload -> SchemaCatalogEvidencePayload
schemaCatalogPayloadResult _ (Right payload) =
  payload
schemaCatalogPayloadResult entryText (Left exception) =
  schemaCatalogEvidence
    (schemaCatalogTextClaim entryText)
    False
    "schema catalog command completes and emits declared JSON schema"
    ("command raised exception: " ++ compactPrefix (displayException exception))
    "SchemaCatalogCommandArtifact"

schemaCatalogPayload :: String -> IO SchemaCatalogEvidencePayload
schemaCatalogPayload text =
  case parseSchemaCatalogEntry text of
    Nothing ->
      pure
        ( schemaCatalogEvidence
            ("schema-catalog-entry:" ++ text)
            False
            "schema catalog entry has '<schema> <- <command>' form"
            "could not parse schema catalog entry"
            "SchemaCatalogEntryArtifact"
        )
    Just entry
      | schemaCatalogCommandIsSelf (schemaCatalogEntryCommand entry) ->
          pure (schemaCatalogSelfPayload entry)
      | otherwise ->
          runSchemaCatalogEntry entry

schemaCatalogSelfPayload :: SchemaCatalogEntry -> SchemaCatalogEvidencePayload
schemaCatalogSelfPayload entry =
  schemaCatalogEvidence
    (schemaCatalogClaim entry)
    True
    ("command emits JSON schema " ++ schemaCatalogEntrySchema entry)
    "self schema entry is checked by this process without recursive invocation"
    "SchemaCatalogSelfEntryArtifact"

runSchemaCatalogEntry :: SchemaCatalogEntry -> IO SchemaCatalogEvidencePayload
runSchemaCatalogEntry entry =
  case words (schemaCatalogEntryCommand entry) of
    [] ->
      pure
        ( schemaCatalogEvidence
            (schemaCatalogClaim entry)
            False
            ("command emits JSON schema " ++ schemaCatalogEntrySchema entry)
            "empty schema catalog command"
            "SchemaCatalogCommandArtifact"
        )
    executable : arguments -> do
      let commandArguments =
            schemaCatalogCommandArguments arguments
      (exitCode, stdoutText, stderrText) <-
        Process.readCreateProcessWithExitCode
          (Process.proc executable commandArguments)
          ""
      let matched =
            exitCode == ExitSuccess && schemaFieldPresent (schemaCatalogEntrySchema entry) stdoutText
          observed =
            observedSchemaOutput entry exitCode stdoutText stderrText
      pure
        ( schemaCatalogEvidence
            (schemaCatalogClaim entry)
            matched
            ("command emits JSON schema " ++ schemaCatalogEntrySchema entry)
            observed
            "SchemaCatalogCommandArtifact"
        )

schemaCatalogClaim :: SchemaCatalogEntry -> String
schemaCatalogClaim entry =
  "schema-catalog-output:" ++ schemaCatalogEntrySchema entry

schemaCatalogTextClaim :: String -> String
schemaCatalogTextClaim text =
  case parseSchemaCatalogEntry text of
    Just entry ->
      schemaCatalogClaim entry
    Nothing ->
      "schema-catalog-entry:" ++ text

schemaCatalogCommandIsSelf :: String -> Bool
schemaCatalogCommandIsSelf command =
  case words command of
    "schema-catalog-witness" : _ ->
      True
    _ ->
      False

schemaCatalogCommandArguments :: [String] -> [String]
schemaCatalogCommandArguments arguments =
  filter (/= "--") arguments

parseSchemaCatalogEntry :: String -> Maybe SchemaCatalogEntry
parseSchemaCatalogEntry text =
  case breakOn " <- " text of
    Just (schemaName, command) ->
      Just (SchemaCatalogEntry schemaName command)
    Nothing ->
      Nothing

breakOn :: String -> String -> Maybe (String, String)
breakOn marker text =
  go "" text
  where
    go _ [] =
      Nothing
    go prefix rest
      | marker `isPrefixOfLocal` rest =
          Just (prefix, drop (length marker) rest)
      | otherwise =
          case rest of
            current : next ->
              go (prefix ++ [current]) next

schemaFieldPresent :: String -> String -> Bool
schemaFieldPresent schemaName output =
  ("\"schema\":\"" ++ schemaName ++ "\"") `isInfixOf` output

observedSchemaOutput :: SchemaCatalogEntry -> ExitCode -> String -> String -> String
observedSchemaOutput entry exitCode stdoutText stderrText =
  case exitCode of
    ExitSuccess
      | schemaFieldPresent (schemaCatalogEntrySchema entry) stdoutText ->
          "schema field matched: " ++ schemaCatalogEntrySchema entry
      | otherwise ->
          "schema field missing from stdout prefix: " ++ compactPrefix stdoutText
    ExitFailure code ->
      "command failed "
        ++ show code
        ++ ": "
        ++ schemaCatalogEntryCommand entry
        ++ " stderr="
        ++ compactPrefix stderrText

renderPayloadBlock :: SchemaCatalogEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderSchemaCatalogEvidencePayload payload)
    ++ [""]

failWhenEvidenceFailed :: [SchemaCatalogEvidencePayload] -> IO ()
failWhenEvidenceFailed [] =
  pure ()
failWhenEvidenceFailed failedPayloads =
  ioError
    ( userError
        ( "[witness] schema catalog evidence failed\n"
            ++ unlines (concatMap renderPayloadBlock failedPayloads)
        )
    )

statusText :: [SchemaCatalogEvidencePayload] -> String
statusText payloads =
  if all schemaCatalogEvidencePayloadPassed payloads
    then "ok"
    else "failed"

compactPrefix :: String -> String
compactPrefix text =
  take 240 (unwords (words text))

chunksOf :: Int -> [a] -> [[a]]
chunksOf _ [] =
  []
chunksOf size items =
  current : chunksOf size rest
  where
    (current, rest) =
      splitAt size items

isPrefixOfLocal :: String -> String -> Bool
isPrefixOfLocal [] _ =
  True
isPrefixOfLocal _ [] =
  False
isPrefixOfLocal (left : leftRest) (right : rightRest)
  | left == right =
      isPrefixOfLocal leftRest rightRest
  | otherwise =
      False
