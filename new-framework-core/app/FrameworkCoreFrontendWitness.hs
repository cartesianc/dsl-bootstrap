{-# LANGUAGE PatternSynonyms #-}

module Main
  ( main
  ) where

import Framework.RegistryCodegen
  ( GeneratedSource (..)
  , diffGeneratedLines
  , frameworkCoreFrontendSources
  , generatedLinesMatch
  )
import Bootstrap.CoreSurface
  ( CoreSurfaceModule (..)
  , coreSurfaceModules
  )
import Framework.Frontend.Evidence
  ( FrontendClaimModuleLink (..)
  , frameworkCoreFrontendCoreClaimNames
  , frameworkCoreFrontendEvidenceClaimNames
  , frontendClaimModuleLinkEvidenceClaimName
  , frontendClaimModuleLinks
  )
import Framework.Ast
  ( App
  , AppBlueprint (..)
  , Callback (..)
  , FactExpr (..)
  , HangingAction (..)
  , Loop (..)
  , Requirement (..)
  , Wait (..)
  , Workflow (..)
  , WorkflowFact
  , chainItems
  , choiceItems
  , effectSystemRuntimeFacts
  , fallbackItems
  , hangingItems
  , parallelItems
  , raceItems
  )
import FrameworkCore.CurrentAst
  ( currentAst )
import Control.Monad
  ( filterM )
import Data.Char
  ( isSpace )
import Data.List
  ( isInfixOf )
import System.Directory
  ( doesFileExist )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  payloads <- frameworkCoreFrontendEvidencePayloads
  let failedPayloads =
        filter (not . frameworkCoreFrontendEvidencePayloadPassed) payloads
      generatedSourceCount =
        length frameworkCoreFrontendSources
      claimLinkCount =
        length frontendClaimModuleLinks
      coreSurfaceModuleCount =
        length coreSurfaceModuleNames
  case args of
    ["--json"] -> do
      putStrLn (renderFrameworkCoreFrontendEvidencePayloadsJson payloads)
      failWhenEvidenceFailed failedPayloads
    _ -> do
      case failedPayloads of
        [] ->
          putStrLn
            ( "[witness] ok framework-core frontend generated sources "
                ++ show generatedSourceCount
                ++ " modules; claim-module links "
                ++ show claimLinkCount
                ++ "; core-surface modules "
                ++ show coreSurfaceModuleCount
            )
        currentFailures ->
          ioError
            ( userError
                ( "[witness] framework-core frontend generated sources failed\n"
                    ++ unlines (concatMap renderPayloadBlock currentFailures)
                )
            )

frameworkCoreFrontendEvidencePayloads :: IO [FrameworkCoreFrontendEvidencePayload]
frameworkCoreFrontendEvidencePayloads = do
  generatedPayloads <- mapM generatedSourceEvidencePayload frameworkCoreFrontendSources
  cabalText <- readFile "new-framework-core/new-framework-core.cabal"
  sourceBackedModules <- coreSurfaceSourceBackedModuleNames
  runtimeDiagnosisBoundaryPayload <- runtimeDiagnosisImplementationBoundaryEvidencePayload
  let claimPayloads =
        map (claimModuleLinkEvidencePayload currentAst cabalText) frontendClaimModuleLinks
      exposurePayload =
        coreSurfaceExposedModulesEvidencePayload cabalText sourceBackedModules
      corePayloads =
        generatedPayloads ++ claimPayloads ++ [exposurePayload, runtimeDiagnosisBoundaryPayload]
  pure (corePayloads ++ [frameworkCoreFrontendClaimManifestPayload corePayloads])

data FrameworkCoreFrontendEvidencePayload = FrameworkCoreFrontendEvidencePayload
  { frameworkCoreFrontendEvidenceClaim :: String
  , frameworkCoreFrontendEvidenceStatus :: FrameworkCoreFrontendEvidenceStatus
  , frameworkCoreFrontendEvidenceExpected :: String
  , frameworkCoreFrontendEvidenceObserved :: String
  , frameworkCoreFrontendEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data FrameworkCoreFrontendEvidenceStatus
  = FrameworkCoreFrontendEvidencePassed
  | FrameworkCoreFrontendEvidenceFailed
  deriving (Eq, Show)

frameworkCoreFrontendEvidencePayloadPassed :: FrameworkCoreFrontendEvidencePayload -> Bool
frameworkCoreFrontendEvidencePayloadPassed payload =
  frameworkCoreFrontendEvidenceStatus payload == FrameworkCoreFrontendEvidencePassed

generatedSourceEvidencePayload :: GeneratedSource -> IO FrameworkCoreFrontendEvidencePayload
generatedSourceEvidencePayload source = do
  actualText <- readFile (generatedSourcePath source)
  let actualLines =
        lines actualText
      matches =
        generatedLinesMatch (generatedSourceLines source) actualLines
      observed =
        if matches
          then "matched: " ++ generatedSourcePath source
          else
            "diff: "
              ++ joinWith " | " (take 40 (diffGeneratedLines (generatedSourceLines source) actualLines))
  pure
    ( frontendEvidence
        ("framework-core-frontend-generated-source:" ++ generatedSourcePath source)
        matches
        "generated frontend source matches Framework.RegistryCodegen definition"
        observed
        ("FrameworkCoreGeneratedSourceArtifact:" ++ generatedSourcePath source)
    )

checkClaimModuleLink :: AppBlueprint -> String -> FrontendClaimModuleLink -> [String]
checkClaimModuleLink blueprint cabalText link =
  [ "AST claim missing: " ++ show fact
  | fact `notElem` appBlueprintFacts blueprint
  ]
    ++
  [ "CoreSurface module missing for " ++ show fact ++ ": " ++ moduleName
  | not (moduleName `elem` coreSurfaceModuleNames)
  ]
    ++
  [ "cabal exposed-module missing for " ++ show fact ++ ": " ++ moduleName
  | not (moduleName `elem` cabalExposedModules cabalText)
  ]
  where
    fact =
      frontendClaimModuleFact link
    moduleName =
      frontendClaimModuleName link

claimModuleLinkEvidencePayload :: AppBlueprint -> String -> FrontendClaimModuleLink -> FrameworkCoreFrontendEvidencePayload
claimModuleLinkEvidencePayload blueprint cabalText link =
  frontendEvidence
    (frontendClaimModuleLinkEvidenceClaimName link)
    (null failures)
    "AST claim, CoreSurface module, and cabal exposed-module stay linked"
    observed
    ("FrameworkCoreClaimModuleLinkArtifact:" ++ moduleName)
  where
    fact =
      frontendClaimModuleFact link
    moduleName =
      frontendClaimModuleName link
    failures =
      checkClaimModuleLink blueprint cabalText link
    observed
      | null failures =
          "all present: " ++ show fact ++ " -> " ++ moduleName
      | otherwise =
          joinWith "; " failures

coreSurfaceExposedModulesEvidencePayload :: String -> [String] -> FrameworkCoreFrontendEvidencePayload
coreSurfaceExposedModulesEvidencePayload cabalText sourceBackedModules =
  frontendEvidence
    "framework-core-frontend-core-surface-exposed-modules"
    (null missing)
    "every source-backed CoreSurface module is a cabal exposed-module"
    observed
    "FrameworkCoreSurfaceExposedModulesArtifact"
  where
    exposed =
      cabalExposedModules cabalText
    missing =
      [ moduleName
      | moduleName <- sourceBackedModules
      , moduleName `notElem` exposed
      ]
    observed
      | null missing =
          "all source-backed CoreSurface modules exposed: " ++ show (length sourceBackedModules)
      | otherwise =
          "missing exposed modules: " ++ joinWith ", " missing

runtimeDiagnosisImplementationBoundaryEvidencePayload :: IO FrameworkCoreFrontendEvidencePayload
runtimeDiagnosisImplementationBoundaryEvidencePayload = do
  diagnosisSource <- readFile "new-framework-core/src/Framework/Runtime/Diagnosis.hs"
  interpreterSource <- readFile "new-framework-core/src/Framework/Runtime/Interpreter.hs"
  let missingAnchors =
        [ anchor
        | anchor <- runtimeDiagnosisImplementationAnchors
        , not (anchor `isInfixOf` diagnosisSource)
        ]
      forbiddenAnchors =
        [ anchor
        | anchor <- runtimeDiagnosisForbiddenFacadeAnchors
        , anchor `isInfixOf` diagnosisSource
        ]
      interpreterImportsDiagnosis =
        "import Framework.Runtime.Diagnosis" `isInfixOf` interpreterSource
      interpreterOwnsDiagnosisBuilder =
        "buildFailureDiagnosisWithSystem ::" `isInfixOf` interpreterSource
      failures =
        [ "missing implementation anchors: " ++ joinWith ", " missingAnchors
        | not (null missingAnchors)
        ]
          ++
        [ "forbidden facade anchors: " ++ joinWith ", " forbiddenAnchors
        | not (null forbiddenAnchors)
        ]
          ++
        [ "Interpreter does not import Framework.Runtime.Diagnosis"
        | not interpreterImportsDiagnosis
        ]
          ++
        [ "Interpreter still owns buildFailureDiagnosisWithSystem"
        | interpreterOwnsDiagnosisBuilder
        ]
  pure
    ( frontendEvidence
        "framework-core-frontend-runtime-diagnosis-implementation-boundary"
        (null failures)
        "Framework.Runtime.Diagnosis owns diagnosis implementation and Interpreter consumes it"
        ( if null failures
            then "Diagnosis owns construction, graph, root-cause, rendering, and JSON evidence anchors"
            else joinWith "; " failures
        )
        "FrameworkRuntimeDiagnosisImplementationBoundaryArtifact"
    )

runtimeDiagnosisImplementationAnchors :: [String]
runtimeDiagnosisImplementationAnchors =
  [ "buildFailureDiagnosisWithSystem ::"
  , "diagnosisNodesFrom ::"
  , "runtimeDiagnosisRootCause ::"
  , "renderRuntimeDiagnosisEvidencePayloadsJson ::"
  ]

runtimeDiagnosisForbiddenFacadeAnchors :: [String]
runtimeDiagnosisForbiddenFacadeAnchors =
  [ "( module Framework.Runtime"
  , "import Framework.Runtime\n"
  ]

frameworkCoreFrontendClaimManifestPayload :: [FrameworkCoreFrontendEvidencePayload] -> FrameworkCoreFrontendEvidencePayload
frameworkCoreFrontendClaimManifestPayload payloads =
  frontendEvidence
    "framework-core-frontend-claim-manifest"
    manifestSynced
    "framework-core frontend executable claims match exported claim manifest"
    observed
    "FrameworkCoreFrontendClaimManifestArtifact"
  where
    actualClaimNames =
      map frameworkCoreFrontendEvidenceClaim payloads
    actualEvidenceClaimNames =
      actualClaimNames ++ ["framework-core-frontend-claim-manifest"]
    manifestSynced =
      actualClaimNames == frameworkCoreFrontendCoreClaimNames
        && actualEvidenceClaimNames == frameworkCoreFrontendEvidenceClaimNames
    observed
      | manifestSynced =
          "claim manifest synced: " ++ show (length actualClaimNames) ++ " core claims"
      | otherwise =
          "expected " ++ show frameworkCoreFrontendEvidenceClaimNames
            ++ "; actual "
            ++ show actualEvidenceClaimNames

frontendEvidence :: String -> Bool -> String -> String -> String -> FrameworkCoreFrontendEvidencePayload
frontendEvidence claim passed expected observed artifact =
  FrameworkCoreFrontendEvidencePayload
    { frameworkCoreFrontendEvidenceClaim = claim
    , frameworkCoreFrontendEvidenceStatus =
        if passed
          then FrameworkCoreFrontendEvidencePassed
          else FrameworkCoreFrontendEvidenceFailed
    , frameworkCoreFrontendEvidenceExpected = expected
    , frameworkCoreFrontendEvidenceObserved = observed
    , frameworkCoreFrontendEvidenceArtifact = artifact
    }

renderPayloadBlock :: FrameworkCoreFrontendEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderFrameworkCoreFrontendEvidencePayload payload)
    ++ [""]

renderFrameworkCoreFrontendEvidencePayload :: FrameworkCoreFrontendEvidencePayload -> [String]
renderFrameworkCoreFrontendEvidencePayload payload =
  [ "claim: " ++ frameworkCoreFrontendEvidenceClaim payload
  , "status: " ++ renderFrameworkCoreFrontendEvidenceStatus (frameworkCoreFrontendEvidenceStatus payload)
  , "expected: " ++ frameworkCoreFrontendEvidenceExpected payload
  , "observed: " ++ frameworkCoreFrontendEvidenceObserved payload
  , "artifact: " ++ frameworkCoreFrontendEvidenceArtifact payload
  ]

renderFrameworkCoreFrontendEvidenceStatus :: FrameworkCoreFrontendEvidenceStatus -> String
renderFrameworkCoreFrontendEvidenceStatus FrameworkCoreFrontendEvidencePassed =
  "passed"
renderFrameworkCoreFrontendEvidenceStatus FrameworkCoreFrontendEvidenceFailed =
  "failed"

renderFrameworkCoreFrontendEvidencePayloadsJson :: [FrameworkCoreFrontendEvidencePayload] -> String
renderFrameworkCoreFrontendEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "framework-core-frontend-evidence.v1")
    , jsonField "status" (jsonString statusText)
    , jsonField "payloads" (jsonArray (map frameworkCoreFrontendEvidencePayloadJson payloads))
    ]
  where
    statusText =
      if all frameworkCoreFrontendEvidencePayloadPassed payloads
        then "passed"
        else "failed"

frameworkCoreFrontendEvidencePayloadJson :: FrameworkCoreFrontendEvidencePayload -> String
frameworkCoreFrontendEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (frameworkCoreFrontendEvidenceClaim payload))
    , jsonField "status" (jsonString (renderFrameworkCoreFrontendEvidenceStatus (frameworkCoreFrontendEvidenceStatus payload)))
    , jsonField "expected" (jsonString (frameworkCoreFrontendEvidenceExpected payload))
    , jsonField "observed" (jsonString (frameworkCoreFrontendEvidenceObserved payload))
    , jsonField "artifact" (jsonString (frameworkCoreFrontendEvidenceArtifact payload))
    ]

failWhenEvidenceFailed :: [FrameworkCoreFrontendEvidencePayload] -> IO ()
failWhenEvidenceFailed [] =
  pure ()
failWhenEvidenceFailed failedPayloads =
  ioError
    ( userError
        ( "[witness] framework-core frontend evidence failed\n"
            ++ unlines (concatMap renderPayloadBlock failedPayloads)
        )
    )

coreSurfaceModuleNames :: [String]
coreSurfaceModuleNames =
  map surfaceModuleName coreSurfaceModules

coreSurfaceSourceBackedModuleNames :: IO [String]
coreSurfaceSourceBackedModuleNames =
  filterM moduleSourceExists coreSurfaceModuleNames

moduleSourceExists :: String -> IO Bool
moduleSourceExists moduleName =
  doesFileExist (moduleSourcePath moduleName)

moduleSourcePath :: String -> FilePath
moduleSourcePath moduleName =
  "new-framework-core/src/" ++ map modulePathChar moduleName ++ ".hs"

modulePathChar :: Char -> Char
modulePathChar '.' =
  '/'
modulePathChar currentChar =
  currentChar

appBlueprintFacts :: AppBlueprint -> [WorkflowFact]
appBlueprintFacts blueprint =
  appFacts (blueprintApp blueprint)
    ++ concatMap hangingActionFacts (hangingItems (blueprintHanging blueprint))

appFacts :: App -> [WorkflowFact]
appFacts app =
  case app of
    RunWorkflow system ->
      factExprFacts (effectSystemRuntimeFacts system)
    ChainWorkflow chain ->
      concatMap appFacts (chainItems chain)
    ParallelWorkflow currentParallel ->
      concatMap appFacts (parallelItems currentParallel)
    FallbackWorkflow currentFallback ->
      concatMap appFacts (fallbackItems currentFallback)
    RaceWorkflow currentRace ->
      concatMap appFacts (raceItems currentRace)
    ChoiceWorkflow _ currentChoice ->
      concatMap (appFacts . snd) (choiceItems currentChoice)
    WaitWorkflow currentWait next ->
      factExprFacts (waitFacts currentWait) ++ appFacts next

hangingActionFacts :: HangingAction WorkflowFact hook App -> [WorkflowFact]
hangingActionFacts action =
  case action of
    HangingCallback callback ->
      appFacts (callbackBody callback)
    HangingSuspense _ ->
      []
    HangingLoop loop ->
      appFacts (loopBody loop)
    HangingMiddleware _ app ->
      appFacts app

factExprFacts :: FactExpr WorkflowFact -> [WorkflowFact]
factExprFacts expr =
  case expr of
    FactItems requirement ->
      requirementFacts requirement
    FactAll items ->
      concatMap factExprFacts items
    FactAny items ->
      concatMap factExprFacts items

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
