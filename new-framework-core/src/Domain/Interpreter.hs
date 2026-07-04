module Domain.Interpreter
  ( AstTreeNode (..)
  , InterpreterRegistration (..)
  , astTreeStructure
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

data AstTreeNode = AstTreeNode
  { astTreeNodeKind :: String
  , astTreeNodeName :: String
  , astTreeNodePath :: [String]
  , astTreeNodeMetadata :: [(String, [String])]
  , astTreeNodeChildren :: [AstTreeNode]
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

astTreeStructure :: AppBlueprint -> AstTreeNode
astTreeStructure blueprint =
  AstTreeNode
    { astTreeNodeKind = "blueprint"
    , astTreeNodeName = "blueprint"
    , astTreeNodePath = ["blueprint"]
    , astTreeNodeMetadata = []
    , astTreeNodeChildren =
        [ AstTreeNode
            { astTreeNodeKind = "app"
            , astTreeNodeName = "app"
            , astTreeNodePath = ["blueprint", "app"]
            , astTreeNodeMetadata = []
            , astTreeNodeChildren = [workflowTreeNode ["blueprint", "app", "root"] (blueprintApp blueprint)]
            }
        , AstTreeNode
            { astTreeNodeKind = "hanging"
            , astTreeNodeName = "hanging"
            , astTreeNodePath = ["blueprint", "hanging"]
            , astTreeNodeMetadata = []
            , astTreeNodeChildren =
                indexedMap
                  (hangingActionTreeNode ["blueprint", "hanging"])
                  (hangingItems (blueprintHanging blueprint))
            }
        ]
    }

printAstTree :: AppBlueprint -> IO ()
printAstTree =
  mapM_ putStrLn . renderAstTree

runRuntime :: RuntimeEffectEnvironment -> AppBlueprint -> EffectTheory -> IO ()
runRuntime handlers ast effects =
  runNativeBlueprintWithEffectEnvironment handlers effects ast

runAstTree :: RuntimeEffectEnvironment -> AppBlueprint -> EffectTheory -> IO ()
runAstTree _ ast _ =
  printAstTree ast

workflowTreeNode :: (Show fact) => [String] -> Workflow fact hook -> AstTreeNode
workflowTreeNode path workflow =
  case workflow of
    RunWorkflow system ->
      effectSystemTreeNode path system
    ChainWorkflow steps ->
      branchContainerTreeNode "chain" "step" path (chainItems steps)
    ParallelWorkflow branches ->
      branchContainerTreeNode "parallel" "branch" path (parallelItems branches)
    FallbackWorkflow branches ->
      branchContainerTreeNode "fallback" "branch" path (fallbackItems branches)
    RaceWorkflow branches ->
      branchContainerTreeNode "race" "branch" path (raceItems branches)
    ChoiceWorkflow key branches ->
      AstTreeNode
        { astTreeNodeKind = "choice"
        , astTreeNodeName = choiceKeyText key
        , astTreeNodePath = path
        , astTreeNodeMetadata = [("selected", [choiceKeyText key])]
        , astTreeNodeChildren =
            map (choiceBranchTreeNode path) (choiceItems branches)
        }
    WaitWorkflow wait body ->
      AstTreeNode
        { astTreeNodeKind = "wait"
        , astTreeNodeName = "wait"
        , astTreeNodePath = path
        , astTreeNodeMetadata = [("waitFacts", [renderFactExpr (Bootstrap.Workflow.waitFacts wait)])]
        , astTreeNodeChildren = [workflowTreeNode (path ++ ["body"]) body]
        }

branchContainerTreeNode :: (Show fact) => String -> String -> [String] -> [Workflow fact hook] -> AstTreeNode
branchContainerTreeNode kind childPrefix path children =
  AstTreeNode
    { astTreeNodeKind = kind
    , astTreeNodeName = kind
    , astTreeNodePath = path
    , astTreeNodeMetadata = [("children", [show (length children)])]
    , astTreeNodeChildren =
        indexedMap
          (\index child -> workflowTreeNode (path ++ [childPrefix ++ ":" ++ show index]) child)
          children
    }

choiceBranchTreeNode :: (Show fact) => [String] -> (ChoiceKey, Workflow fact hook) -> AstTreeNode
choiceBranchTreeNode path (key, branch) =
  AstTreeNode
    { astTreeNodeKind = "choice-branch"
    , astTreeNodeName = choiceKeyText key
    , astTreeNodePath = path ++ ["branch:" ++ choiceKeyText key]
    , astTreeNodeMetadata = [("choiceKey", [choiceKeyText key])]
    , astTreeNodeChildren =
        [workflowTreeNode (path ++ ["branch:" ++ choiceKeyText key, "body"]) branch]
    }

effectSystemTreeNode :: (Show fact) => [String] -> Bootstrap.Workflow.EffectSystem fact -> AstTreeNode
effectSystemTreeNode path system =
  AstTreeNode
    { astTreeNodeKind = "run"
    , astTreeNodeName = show (Bootstrap.Workflow.effectSystemName system)
    , astTreeNodePath = path
    , astTreeNodeMetadata =
        [ ("success", [renderFactExpr (Bootstrap.Workflow.effectSystemSuccess system)])
        , ("imports", map show (Bootstrap.Workflow.effectSystemBoundaryImports boundary))
        , ("privateFacts", map show (Bootstrap.Workflow.effectSystemBoundaryPrivateFacts boundary))
        , ("exports", map show (Bootstrap.Workflow.effectSystemBoundaryExports boundary))
        , ("sends", map show (Bootstrap.Workflow.effectSystemBoundarySends boundary))
        , ("transforms", map show (Bootstrap.Workflow.effectSystemBoundaryTransforms boundary))
        , ("policies", map show (Bootstrap.Workflow.effectSystemBoundaryPolicies boundary))
        , ("pipelines", map show (Bootstrap.Workflow.effectSystemBoundaryPipelines boundary))
        , ("handlers", map show (Bootstrap.Workflow.effectSystemBoundaryHandlers boundary))
        , ("boundaryExplicit", [if Bootstrap.Workflow.effectSystemBoundaryExplicit system then "true" else "false"])
        ]
    , astTreeNodeChildren = []
    }
  where
    boundary =
      Bootstrap.Workflow.effectSystemBoundary system

hangingActionTreeNode ::
  (Show fact, Show hook) =>
  [String] ->
  Int ->
  HangingAction fact hook (Workflow fact hook) ->
  AstTreeNode
hangingActionTreeNode path index action =
  case action of
    HangingCallback callback ->
      AstTreeNode
        { astTreeNodeKind = "callback"
        , astTreeNodeName = show (Bootstrap.Workflow.callbackTarget callback)
        , astTreeNodePath = path ++ ["callback:" ++ show index]
        , astTreeNodeMetadata = [("target", [show (Bootstrap.Workflow.callbackTarget callback)])]
        , astTreeNodeChildren =
            [workflowTreeNode (path ++ ["callback:" ++ show index, "body"]) (Bootstrap.Workflow.callbackBody callback)]
        }
    HangingSuspense suspense ->
      AstTreeNode
        { astTreeNodeKind = "suspense"
        , astTreeNodeName = show (Bootstrap.Workflow.suspenseTarget suspense)
        , astTreeNodePath = path ++ ["suspense:" ++ show index]
        , astTreeNodeMetadata = [("target", [show (Bootstrap.Workflow.suspenseTarget suspense)])]
        , astTreeNodeChildren = []
        }
    HangingLoop loop ->
      AstTreeNode
        { astTreeNodeKind = "loop"
        , astTreeNodeName = "loop"
        , astTreeNodePath = path ++ ["loop:" ++ show index]
        , astTreeNodeMetadata = []
        , astTreeNodeChildren =
            [workflowTreeNode (path ++ ["loop:" ++ show index, "body"]) (Bootstrap.Workflow.loopBody loop)]
        }
    HangingMiddleware middleware body ->
      AstTreeNode
        { astTreeNodeKind = "middleware"
        , astTreeNodeName = show (Bootstrap.Workflow.middlewareHook middleware)
        , astTreeNodePath = path ++ ["middleware:" ++ show index]
        , astTreeNodeMetadata = [("hook", [show (Bootstrap.Workflow.middlewareHook middleware)])]
        , astTreeNodeChildren =
            [workflowTreeNode (path ++ ["middleware:" ++ show index, "body"]) body]
        }

renderWorkflow :: (Show fact) => Workflow fact hook -> [String]
renderWorkflow workflow =
  case workflow of
    RunWorkflow system ->
      renderEffectSystem system
    ChainWorkflow steps ->
      "chain" : indentLines 2 (concatMap renderWorkflow (chainItems steps))
    ParallelWorkflow branches ->
      "parallel" : indentLines 2 (concatMap renderWorkflow (parallelItems branches))
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

renderEffectSystem :: (Show fact) => Bootstrap.Workflow.EffectSystem fact -> [String]
renderEffectSystem system
  | null imports && null privateFacts =
      [ "run "
          ++ show (Bootstrap.Workflow.effectSystemName system)
          ++ " succeeds "
          ++ renderFactExpr (Bootstrap.Workflow.effectSystemSuccess system)
      ]
  | otherwise =
      [ "run "
          ++ show (Bootstrap.Workflow.effectSystemName system)
          ++ " imports "
          ++ show imports
          ++ " private "
          ++ show privateFacts
          ++ " exports "
          ++ show exports
      ]
  where
    boundary =
      Bootstrap.Workflow.effectSystemBoundary system
    imports =
      Bootstrap.Workflow.effectSystemBoundaryImports boundary
    privateFacts =
      Bootstrap.Workflow.effectSystemBoundaryPrivateFacts boundary
    exports =
      Bootstrap.Workflow.effectSystemBoundaryExports boundary

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

indexedMap :: (Int -> item -> result) -> [item] -> [result]
indexedMap mapper =
  go (0 :: Int)
  where
    go _ [] =
      []
    go index (item : rest) =
      mapper index item : go (index + 1) rest
