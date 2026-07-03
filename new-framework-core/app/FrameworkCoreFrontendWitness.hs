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
  ( pattern RuntimeDiagnosisExpressedFact )
import Framework.Ast
  ( App
  , AppBlueprint (..)
  , Callback (..)
  , EffectSystem (..)
  , FactExpr (..)
  , HangingAction (..)
  , Loop (..)
  , Requirement (..)
  , Wait (..)
  , Workflow (..)
  , WorkflowFact
  , chainItems
  , choiceItems
  , fallbackItems
  , hangingItems
  , parallelItems
  , raceItems
  )
import FrameworkCore.CurrentAst
  ( currentAst )
import Data.Char
  ( isSpace )

main :: IO ()
main = do
  results <- mapM checkGeneratedSource frameworkCoreFrontendSources
  cabalText <- readFile "new-framework-core/new-framework-core.cabal"
  let failures =
        concat results
          ++ concatMap (checkClaimModuleLink currentAst cabalText) claimModuleLinks
  case failures of
    [] ->
      putStrLn
        ( "[witness] ok framework-core frontend generated sources "
            ++ show (length frameworkCoreFrontendSources)
            ++ " modules; claim-module links "
            ++ show (length claimModuleLinks)
        )
    currentFailures ->
      ioError
        ( userError
            ( "[witness] framework-core frontend generated sources failed\n"
                ++ unlines currentFailures
            )
        )

checkGeneratedSource :: GeneratedSource -> IO [String]
checkGeneratedSource source = do
  actualText <- readFile (generatedSourcePath source)
  let actualLines =
        lines actualText
  if generatedLinesMatch (generatedSourceLines source) actualLines
    then pure []
    else
      pure
        ( ("generated source differs from " ++ generatedSourcePath source)
            : take 40 (diffGeneratedLines (generatedSourceLines source) actualLines)
        )

data ClaimModuleLink = ClaimModuleLink
  { claimModuleFact :: WorkflowFact
  , claimModuleName :: String
  }

claimModuleLinks :: [ClaimModuleLink]
claimModuleLinks =
  [ ClaimModuleLink RuntimeDiagnosisExpressedFact "Framework.Runtime.Diagnosis"
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
      factExprFacts (effectSystemSuccess system)
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
