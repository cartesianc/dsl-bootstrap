module Main
  ( main
  ) where

import Data.List
  ( isInfixOf )
import System.Environment
  ( getArgs )
import System.Exit
  ( ExitCode (..) )
import qualified System.Process as Process

import Framework.TrustBase
  ( trustBaseManifestRequiredJsonSchemas )

data SchemaCatalogEvidencePayload = SchemaCatalogEvidencePayload
  { schemaCatalogEvidenceClaim :: String
  , schemaCatalogEvidenceStatus :: SchemaCatalogEvidenceStatus
  , schemaCatalogEvidenceExpected :: String
  , schemaCatalogEvidenceObserved :: String
  , schemaCatalogEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data SchemaCatalogEvidenceStatus
  = SchemaCatalogEvidencePassed
  | SchemaCatalogEvidenceFailed
  deriving (Eq, Show)

data SchemaCatalogEntry = SchemaCatalogEntry
  { schemaCatalogEntrySchema :: String
  , schemaCatalogEntryCommand :: String
  }
  deriving (Eq, Show)

main :: IO ()
main = do
  args <- getArgs
  payloads <- mapM schemaCatalogPayload trustBaseManifestRequiredJsonSchemas
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

schemaCatalogEvidence :: String -> Bool -> String -> String -> String -> SchemaCatalogEvidencePayload
schemaCatalogEvidence claim passed expected observed artifact =
  SchemaCatalogEvidencePayload
    { schemaCatalogEvidenceClaim = claim
    , schemaCatalogEvidenceStatus =
        if passed
          then SchemaCatalogEvidencePassed
          else SchemaCatalogEvidenceFailed
    , schemaCatalogEvidenceExpected = expected
    , schemaCatalogEvidenceObserved = observed
    , schemaCatalogEvidenceArtifact = artifact
    }

schemaCatalogEvidencePayloadPassed :: SchemaCatalogEvidencePayload -> Bool
schemaCatalogEvidencePayloadPassed payload =
  schemaCatalogEvidenceStatus payload == SchemaCatalogEvidencePassed

renderPayloadBlock :: SchemaCatalogEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderSchemaCatalogEvidencePayload payload)
    ++ [""]

renderSchemaCatalogEvidencePayload :: SchemaCatalogEvidencePayload -> [String]
renderSchemaCatalogEvidencePayload payload =
  [ "claim: " ++ schemaCatalogEvidenceClaim payload
  , "status: " ++ renderSchemaCatalogEvidenceStatus (schemaCatalogEvidenceStatus payload)
  , "expected: " ++ schemaCatalogEvidenceExpected payload
  , "observed: " ++ schemaCatalogEvidenceObserved payload
  , "artifact: " ++ schemaCatalogEvidenceArtifact payload
  ]

renderSchemaCatalogEvidenceStatus :: SchemaCatalogEvidenceStatus -> String
renderSchemaCatalogEvidenceStatus SchemaCatalogEvidencePassed =
  "passed"
renderSchemaCatalogEvidenceStatus SchemaCatalogEvidenceFailed =
  "failed"

renderSchemaCatalogEvidencePayloadsJson :: [SchemaCatalogEvidencePayload] -> String
renderSchemaCatalogEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "schema-catalog-evidence.v1")
    , jsonField "status" (jsonString status)
    , jsonField "payloads" (jsonArray (map schemaCatalogEvidencePayloadJson payloads))
    ]
  where
    status =
      if all schemaCatalogEvidencePayloadPassed payloads
        then "passed"
        else "failed"

schemaCatalogEvidencePayloadJson :: SchemaCatalogEvidencePayload -> String
schemaCatalogEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (schemaCatalogEvidenceClaim payload))
    , jsonField "status" (jsonString (renderSchemaCatalogEvidenceStatus (schemaCatalogEvidenceStatus payload)))
    , jsonField "expected" (jsonString (schemaCatalogEvidenceExpected payload))
    , jsonField "observed" (jsonString (schemaCatalogEvidenceObserved payload))
    , jsonField "artifact" (jsonString (schemaCatalogEvidenceArtifact payload))
    ]

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

jsonObject :: [String] -> String
jsonObject fields =
  "{" ++ joinWith "," fields ++ "}"

jsonField :: String -> String -> String
jsonField name value =
  jsonString name ++ ":" ++ value

jsonArray :: [String] -> String
jsonArray values =
  "[" ++ joinWith "," values ++ "]"

jsonString :: String -> String
jsonString value =
  "\"" ++ concatMap jsonChar value ++ "\""

jsonChar :: Char -> String
jsonChar currentChar =
  case currentChar of
    '"' ->
      "\\\""
    '\\' ->
      "\\\\"
    '\n' ->
      "\\n"
    '\r' ->
      "\\r"
    '\t' ->
      "\\t"
    _ ->
      [currentChar]

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
