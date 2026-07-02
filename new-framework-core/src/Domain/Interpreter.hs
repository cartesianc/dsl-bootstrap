module Domain.Interpreter
  ( InterpreterRegistration (..)
  , astTreeInterpreter
  , frameworkCoreInterpreterRegistration
  , interpreterRegistrationNames
  , printAstTree
  , registeredInterpreters
  , renderAstTree
  , runRegisteredInterpreter
  , runtimeInterpreter
  ) where

import Bootstrap.Runtime
  ( RuntimeEffectEnvironment
  , runNativeBlueprintWithEffectEnvironment
  )
import Bootstrap.Effect
  ( EffectTheory
  )
import Bootstrap.Workflow
  ( AppBlueprint (..)
  , ChoiceKey (..)
  , Fact (..)
  , FactExpr (..)
  , HangingAction (..)
  , Workflow (..)
  , chainItems
  , choiceItems
  , fallbackItems
  , hangingItems
  , parallelItems
  , raceItems
  , requirementItems
  )
import qualified Bootstrap.Workflow

data InterpreterRegistration = InterpreterRegistration
  { interpreterRegistrationName :: String
  , interpreterAction :: RuntimeEffectEnvironment -> AppBlueprint -> EffectTheory -> IO ()
  }

runtimeInterpreter :: InterpreterRegistration
runtimeInterpreter =
  InterpreterRegistration
    { interpreterRegistrationName = "runtime"
    , interpreterAction = runRuntime
    }

astTreeInterpreter :: InterpreterRegistration
astTreeInterpreter =
  InterpreterRegistration
    { interpreterRegistrationName = "ast-tree"
    , interpreterAction = runAstTree
    }

frameworkCoreInterpreterRegistration :: InterpreterRegistration
frameworkCoreInterpreterRegistration =
  runtimeInterpreter

registeredInterpreters :: [InterpreterRegistration]
registeredInterpreters =
  [ runtimeInterpreter
  , astTreeInterpreter
  ]

interpreterRegistrationNames :: [String]
interpreterRegistrationNames =
  map interpreterRegistrationName registeredInterpreters

runRegisteredInterpreter ::
  InterpreterRegistration ->
  RuntimeEffectEnvironment ->
  AppBlueprint ->
  EffectTheory ->
  IO ()
runRegisteredInterpreter =
  interpreterAction

renderAstTree :: AppBlueprint -> [String]
renderAstTree blueprint =
  ["blueprint"]
    ++ indentLines 2 ("app" : renderWorkflow (blueprintApp blueprint))
    ++ indentLines 2 ("hanging" : concatMap renderHangingAction (hangingItems (blueprintHanging blueprint)))

printAstTree :: AppBlueprint -> IO ()
printAstTree =
  mapM_ putStrLn . renderAstTree

runRuntime :: RuntimeEffectEnvironment -> AppBlueprint -> EffectTheory -> IO ()
runRuntime handlers ast effects =
  runNativeBlueprintWithEffectEnvironment handlers effects ast

runAstTree :: RuntimeEffectEnvironment -> AppBlueprint -> EffectTheory -> IO ()
runAstTree _ ast _ =
  printAstTree ast

renderWorkflow :: (Show fact) => Workflow fact hook -> [String]
renderWorkflow workflow =
  case workflow of
    FactWorkflow (Fact expression) ->
      ["fact " ++ renderFactExpr expression]
    ChainWorkflow name steps ->
      ("chain " ++ show name) : indentLines 2 (concatMap renderWorkflow (chainItems steps))
    ParallelWorkflow name branches ->
      ("parallel " ++ show name) : indentLines 2 (concatMap renderWorkflow (parallelItems branches))
    FallbackWorkflow branches ->
      "fallback" : indentLines 2 (concatMap renderWorkflow (fallbackItems branches))
    RaceWorkflow branches ->
      "race" : indentLines 2 (concatMap renderWorkflow (raceItems branches))
    ChoiceWorkflow key branches ->
      ("choice " ++ choiceKeyText key) : indentLines 2 (concatMap renderChoice (choiceItems branches))
    WaitWorkflow wait body ->
      ("wait " ++ renderFactExpr (Bootstrap.Workflow.waitFacts wait)) : indentLines 2 (renderWorkflow body)

renderChoiceBranch :: (String, [String]) -> [String]
renderChoiceBranch (key, lines') =
  ("branch " ++ key) : indentLines 2 lines'

renderChoice :: (Show fact) => (Bootstrap.Workflow.ChoiceKey, Workflow fact hook) -> [String]
renderChoice (key, branch) =
  renderChoiceBranch (choiceKeyText key, renderWorkflow branch)

choiceKeyText :: ChoiceKey -> String
choiceKeyText (ChoiceKey text) =
  text

renderHangingAction :: (Show fact, Show hook) => HangingAction fact hook (Workflow fact hook) -> [String]
renderHangingAction action =
  case action of
    HangingCallback callback ->
      ["callback " ++ show (Bootstrap.Workflow.callbackTarget callback)]
        ++ indentLines 2 (renderWorkflow (Bootstrap.Workflow.callbackBody callback))
    HangingSuspense suspense ->
      ["suspense " ++ show (Bootstrap.Workflow.suspenseTarget suspense)]
    HangingLoop loop ->
      "loop" : indentLines 2 (renderWorkflow (Bootstrap.Workflow.loopBody loop))
    HangingMiddleware middleware body ->
      ("middleware " ++ show (Bootstrap.Workflow.middlewareHook middleware))
        : indentLines 2 (renderWorkflow body)

renderFactExpr :: (Show fact) => FactExpr fact -> String
renderFactExpr expression =
  case expression of
    FactItems requirements ->
      show (requirementItems requirements)
    FactAll expressions ->
      "allOf " ++ show (map renderFactExpr expressions)
    FactAny expressions ->
      "anyOf " ++ show (map renderFactExpr expressions)

indentLines :: Int -> [String] -> [String]
indentLines count =
  map (replicate count ' ' ++)
