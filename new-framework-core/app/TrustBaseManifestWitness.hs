module Main
  ( main
  ) where

import Data.Char
  ( isSpace )
import Data.List
  ( isPrefixOf )
import System.Exit
  ( ExitCode (..)
  )
import qualified System.Process as Process
import Bootstrap.CoreSurface
  ( CoreSurfaceModule (..)
  , coreSurfaceModules
  )
import Framework.TrustBase
  ( ArtifactManifest (..)
  , ArtifactSource (..)
  , TrustBaseManifest (..)
  , TrustBaseManifestEvidencePayload (..)
  , TrustBaseManifestEvidenceStatus (..)
  , TrustBaseGatePolicy (..)
  , defaultSelfArtifactManifest
  , defaultTrustBaseManifest
  , renderArtifactCommand
  , renderTrustBaseManifest
  , renderTrustBaseManifestEvidencePayload
  , renderTrustBaseManifestEvidencePayloadsJson
  , renderTrustBaseManifestJson
  , trustBaseManifestEvidencePayloadPassed
  , trustBaseManifestRequiredCoreSurfaceModules
  , trustBaseManifestRequiredGatePolicies
  , trustBaseManifestRequiredJsonSchemas
  )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  payloads <- trustBaseManifestEvidencePayloads defaultTrustBaseManifest
  let failures =
        evidenceFailures payloads
  case args of
    ["--evidence-json"] -> do
      putStrLn (renderTrustBaseManifestEvidencePayloadsJson payloads)
      failWhenEvidenceFailed failures
    ["--json"] -> do
      failWhenEvidenceFailed failures
      putStrLn (renderTrustBaseManifestJson defaultTrustBaseManifest)
    _ -> do
      failWhenEvidenceFailed failures
      mapM_ putStrLn (renderTrustBaseManifest defaultTrustBaseManifest)
      putStrLn "[witness] trust base manifest evidence payloads"
      mapM_ putStrLn (concatMap renderPayloadBlock payloads)
      putStrLn
        ( "[witness] ok trust base manifest "
            ++ trustBaseManifestSchema defaultTrustBaseManifest
            ++ " evidence "
            ++ show (length payloads)
            ++ " payload claims"
        )

trustBaseManifestEvidencePayloads :: TrustBaseManifest -> IO [TrustBaseManifestEvidencePayload]
trustBaseManifestEvidencePayloads manifest = do
  coreCabal <- readFile "new-framework-core/new-framework-core.cabal"
  domainCabal <- readFile "domain-app/domain-app.cabal"
  let exposedModules =
        cabalExposedModules coreCabal ++ cabalExposedModules domainCabal
      executables =
        cabalExecutables coreCabal ++ cabalExecutables domainCabal
      manifestModules =
        trustBaseManifestKernelModules manifest ++ trustBaseManifestFacadeModules manifest
  gatePolicyOutput <- observedGatePolicyOutput
  pure
    [ manifestEvidence
        "trust-base-kernel-modules-exposed"
        (null (missingItems exposedModules (trustBaseManifestKernelModules manifest)))
        "all TrustBase kernel modules are cabal exposed-modules"
        (observedItems "missing kernel modules" (missingItems exposedModules (trustBaseManifestKernelModules manifest)))
        "TrustBaseKernelModulesArtifact"
    , manifestEvidence
        "trust-base-facade-modules-exposed"
        (null (missingItems exposedModules (trustBaseManifestFacadeModules manifest)))
        "all TrustBase facade modules are cabal exposed-modules"
        (observedItems "missing facade modules" (missingItems exposedModules (trustBaseManifestFacadeModules manifest)))
        "TrustBaseFacadeModulesArtifact"
    , manifestEvidence
        "trust-base-report-executables-present"
        (null (missingItems executables (trustBaseManifestReportExecutables manifest)))
        "all TrustBase report executables are cabal executable stanzas"
        (observedItems "missing report executables" (missingItems executables (trustBaseManifestReportExecutables manifest)))
        "TrustBaseReportExecutablesArtifact"
    , manifestEvidence
        "trust-base-witness-executables-present"
        (null (missingItems executables (trustBaseManifestWitnessExecutables manifest)))
        "all TrustBase witness executables are cabal executable stanzas"
        (observedItems "missing witness executables" (missingItems executables (trustBaseManifestWitnessExecutables manifest)))
        "TrustBaseWitnessExecutablesArtifact"
    , manifestEvidence
        "trust-base-artifact-gate-executable-present"
        (null (missingItems executables [trustBaseManifestArtifactGateExecutable manifest]))
        "TrustBase artifact gate executable is a cabal executable stanza"
        (observedItems "missing artifact gate executable" (missingItems executables [trustBaseManifestArtifactGateExecutable manifest]))
        "TrustBaseArtifactGateExecutableArtifact"
    , manifestEvidence
        "trust-base-artifact-sources-synced"
        (trustBaseManifestArtifactSources manifest == currentArtifactSources)
        "TrustBase artifact sources mirror defaultSelfArtifactManifest"
        (observedDrift "artifact sources" (trustBaseManifestArtifactSources manifest) currentArtifactSources)
        "TrustBaseArtifactSourcesArtifact"
    , manifestEvidence
        "trust-base-artifact-commands-synced"
        (trustBaseManifestArtifactCommands manifest == currentArtifactCommands)
        "TrustBase artifact commands mirror defaultSelfArtifactManifest"
        (observedDrift "artifact commands" (trustBaseManifestArtifactCommands manifest) currentArtifactCommands)
        "TrustBaseArtifactCommandsArtifact"
    , manifestEvidence
        "trust-base-core-surface-covered"
        ( null (missingItems coreSurfaceModuleNames trustBaseManifestRequiredCoreSurfaceModules)
            && null (missingItems manifestModules trustBaseManifestRequiredCoreSurfaceModules)
        )
        "required TrustBase modules are present in CoreSurface and manifest"
        (observedCoreSurfaceCoverage manifestModules)
        "TrustBaseCoreSurfaceCoverageArtifact"
    , manifestEvidence
        "trust-base-json-schemas-synced"
        (trustBaseManifestJsonSchemas manifest == trustBaseManifestRequiredJsonSchemas)
        "TrustBase manifest lists every published machine-readable schema"
        (observedDrift "json schemas" (trustBaseManifestJsonSchemas manifest) trustBaseManifestRequiredJsonSchemas)
        "TrustBaseJsonSchemaCatalogArtifact"
    , manifestEvidence
        "trust-base-gate-policies-synced"
        ( trustBaseManifestGatePolicies manifest == trustBaseManifestRequiredGatePolicies
            && null (gatePolicyDrift gatePolicyOutput (trustBaseManifestGatePolicies manifest))
        )
        "TrustBase manifest gate policies match check script -List output"
        (observedGatePolicyDrift gatePolicyOutput (trustBaseManifestGatePolicies manifest))
        "TrustBaseGatePolicyCatalogArtifact"
    ]

manifestEvidence :: String -> Bool -> String -> String -> String -> TrustBaseManifestEvidencePayload
manifestEvidence claim passed expected observed artifact =
  TrustBaseManifestEvidencePayload
    { trustBaseManifestEvidenceClaim = claim
    , trustBaseManifestEvidenceStatus =
        if passed
          then TrustBaseManifestEvidencePassed
          else TrustBaseManifestEvidenceFailed
    , trustBaseManifestEvidenceExpected = expected
    , trustBaseManifestEvidenceObserved = observed
    , trustBaseManifestEvidenceArtifact = artifact
    }

currentArtifactSources :: [String]
currentArtifactSources =
  map renderArtifactSourceText (artifactManifestSources defaultSelfArtifactManifest)

currentArtifactCommands :: [String]
currentArtifactCommands =
  map renderArtifactCommand (artifactManifestCommands defaultSelfArtifactManifest)

renderArtifactSourceText :: ArtifactSource -> String
renderArtifactSourceText source =
  artifactSourcePath source ++ " -> " ++ artifactTargetPath source

coreSurfaceModuleNames :: [String]
coreSurfaceModuleNames =
  map surfaceModuleName coreSurfaceModules

observedItems :: String -> [String] -> String
observedItems _ [] =
  "all present"
observedItems label missing =
  label ++ ": " ++ joinWith ", " missing

observedDrift :: String -> [String] -> [String] -> String
observedDrift label actual expected
  | actual == expected =
      label ++ " synced"
  | otherwise =
      label ++ " drifted"

observedCoreSurfaceCoverage :: [String] -> String
observedCoreSurfaceCoverage manifestModules =
  observedItems
    "missing CoreSurface modules"
    (missingItems coreSurfaceModuleNames trustBaseManifestRequiredCoreSurfaceModules)
    ++ "; "
    ++ observedItems
      "missing manifest modules"
      (missingItems manifestModules trustBaseManifestRequiredCoreSurfaceModules)

observedGatePolicyOutput :: IO [(String, [String])]
observedGatePolicyOutput =
  mapM readGatePolicyOutput trustBaseManifestRequiredGatePolicies

readGatePolicyOutput :: TrustBaseGatePolicy -> IO (String, [String])
readGatePolicyOutput policy = do
  let command =
        trustBaseGatePolicyCommand policy
  (exitCode, stdoutText, stderrText) <-
    Process.readCreateProcessWithExitCode
      (Process.proc "cmd" ("/c" : words command))
      ""
  case exitCode of
    ExitSuccess ->
      pure (trustBaseGatePolicyName policy, nonEmptyLines stdoutText)
    ExitFailure code ->
      pure
        ( trustBaseGatePolicyName policy
        , [ "command failed "
              ++ show code
              ++ ": "
              ++ command
              ++ " stderr="
              ++ trimLine stderrText
          ]
        )

gatePolicyDrift :: [(String, [String])] -> [TrustBaseGatePolicy] -> [String]
gatePolicyDrift outputs policies =
  [ trustBaseGatePolicyName policy
  | policy <- policies
  , lookup (trustBaseGatePolicyName policy) outputs /= Just (trustBaseGatePolicyCommands policy)
  ]

observedGatePolicyDrift :: [(String, [String])] -> [TrustBaseGatePolicy] -> String
observedGatePolicyDrift outputs policies
  | trustBaseManifestRequiredGatePolicies /= policies =
      "manifest gate policies drifted"
  | null drift =
      "gate policies synced"
  | otherwise =
      "gate policies drifted: " ++ joinWith ", " drift
  where
    drift =
      gatePolicyDrift outputs policies

nonEmptyLines :: String -> [String]
nonEmptyLines text =
  [ trimLine line
  | line <- lines text
  , trimLine line /= ""
  ]

trimLine :: String -> String
trimLine =
  reverse . dropWhile isSpace . reverse . dropWhile isSpace

missingItems :: [String] -> [String] -> [String]
missingItems available expected =
  [ item
  | item <- expected
  , item `notElem` available
  ]

evidenceFailures :: [TrustBaseManifestEvidencePayload] -> [String]
evidenceFailures payloads =
  [ trustBaseManifestEvidenceClaim payload
      ++ ": "
      ++ trustBaseManifestEvidenceObserved payload
  | payload <- payloads
  , not (trustBaseManifestEvidencePayloadPassed payload)
  ]

failWhenEvidenceFailed :: [String] -> IO ()
failWhenEvidenceFailed [] =
  pure ()
failWhenEvidenceFailed failures =
  ioError (userError ("trust base manifest failed\n" ++ unlines failures))

renderPayloadBlock :: TrustBaseManifestEvidencePayload -> [String]
renderPayloadBlock payload =
  renderTrustBaseManifestEvidencePayload payload ++ [""]

cabalExposedModules :: String -> [String]
cabalExposedModules =
  mapMaybeModule . lines

mapMaybeModule :: [String] -> [String]
mapMaybeModule [] =
  []
mapMaybeModule (currentLine : rest) =
  case cabalModuleName currentLine of
    Just name ->
      name : mapMaybeModule rest
    Nothing ->
      mapMaybeModule rest

cabalModuleName :: String -> Maybe String
cabalModuleName line =
  case takeWhile (not . isSpace) (dropModulePrefix line) of
    [] ->
      Nothing
    name
      | '.' `elem` name || name == "Blueprint" ->
          Just name
      | otherwise ->
          Nothing

dropModulePrefix :: String -> String
dropModulePrefix =
  dropWhile isSpace . dropWhile (== ',') . dropWhile isSpace

cabalExecutables :: String -> [String]
cabalExecutables =
  mapMaybeExecutable . lines

mapMaybeExecutable :: [String] -> [String]
mapMaybeExecutable [] =
  []
mapMaybeExecutable (currentLine : rest) =
  case cabalExecutableName currentLine of
    Just name ->
      name : mapMaybeExecutable rest
    Nothing ->
      mapMaybeExecutable rest

cabalExecutableName :: String -> Maybe String
cabalExecutableName line =
  case stripPrefix "executable " (dropWhile isSpace line) of
    Just name ->
      Just (takeWhile (not . isSpace) name)
    Nothing ->
      Nothing

stripPrefix :: String -> String -> Maybe String
stripPrefix prefix text
  | prefix `isPrefixOf` text =
      Just (drop (length prefix) text)
  | otherwise =
      Nothing

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
