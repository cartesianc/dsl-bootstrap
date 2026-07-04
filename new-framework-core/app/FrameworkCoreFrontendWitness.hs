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
import Domain.Vocabulary
  ( pattern AstStructureExpressedFact
  , pattern EffectTheoryDslExpressedFact
  , pattern RegistryCodegenExpressedFact
  , pattern RuntimeBackendParityExpressedFact
  , pattern RuntimeConcurrencySemanticsExpressedFact
  , pattern RuntimeDiagnosisExpressedFact
  , pattern RuntimeFactClosureExpressedFact
  , pattern SelfArtifactManifestExpressedFact
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
import Data.Char
  ( isSpace )
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
        length claimModuleLinks
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
  let claimPayloads =
        map (claimModuleLinkEvidencePayload currentAst cabalText) claimModuleLinks
  pure (generatedPayloads ++ claimPayloads)

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

data ClaimModuleLink = ClaimModuleLink
  { claimModuleFact :: WorkflowFact
  , claimModuleName :: String
  }

claimModuleLinks :: [ClaimModuleLink]
claimModuleLinks =
  [ ClaimModuleLink AstStructureExpressedFact "Framework.Ast"
  , ClaimModuleLink EffectTheoryDslExpressedFact "Framework.Effect"
  , ClaimModuleLink RuntimeConcurrencySemanticsExpressedFact "Framework.Runtime.Concurrency"
  , ClaimModuleLink RuntimeDiagnosisExpressedFact "Framework.Runtime.Diagnosis"
  , ClaimModuleLink RuntimeBackendParityExpressedFact "Framework.FixedPoint"
  , ClaimModuleLink RuntimeFactClosureExpressedFact "Framework.Runtime.Evidence"
  , ClaimModuleLink RegistryCodegenExpressedFact "Framework.RegistryCodegen"
  , ClaimModuleLink SelfArtifactManifestExpressedFact "Framework.SelfArtifact"
  ]

checkClaimModuleLink :: AppBlueprint -> String -> ClaimModuleLink -> [String]
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
      claimModuleFact link
    moduleName =
      claimModuleName link

claimModuleLinkEvidencePayload :: AppBlueprint -> String -> ClaimModuleLink -> FrameworkCoreFrontendEvidencePayload
claimModuleLinkEvidencePayload blueprint cabalText link =
  frontendEvidence
    ("framework-core-frontend-claim-link:" ++ show fact)
    (null failures)
    "AST claim, CoreSurface module, and cabal exposed-module stay linked"
    observed
    ("FrameworkCoreClaimModuleLinkArtifact:" ++ moduleName)
  where
    fact =
      claimModuleFact link
    moduleName =
      claimModuleName link
    failures =
      checkClaimModuleLink blueprint cabalText link
    observed
      | null failures =
          "all present: " ++ show fact ++ " -> " ++ moduleName
      | otherwise =
          joinWith "; " failures

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
