module Interpreter.View.Algebra
  ( Program
  , algebra
  , runProgram
  , runBlueprint
  ) where

import Data.Char
  ( toLower
  )

import AST.Vocabulary
import Core.Architecture
import Core.Architecture.Cata
import Core.Architecture.Internal
  ( ChoiceBranch (..)
  , FreeAlternative (..)
  , FreeApplicative (..)
  , FreeChoice (..)
  , FreeMonad (..)
  , FreeMonoid (..)
  , RequirementEffect (..)
  )

type Program = Int -> IO ()

algebra :: WorkflowAlgebra WorkflowFact Interceptor Program
algebra =
  WorkflowAlgebra
    { onFact = factProgram
    , onChain = chainProgram
    , onParallel = parallelProgram
    , onFallback = fallbackProgram
    , onRace = raceProgram
    , onChoice = choiceProgram
    , onWait = waitProgram
    , onMiddleware = middlewareProgram
    }

runProgram :: Program -> IO ()
runProgram program = do
  putStrLn "app"
  program firstChildIndent

runBlueprint :: Program -> Hanging (HangingAction WorkflowFact Program) -> IO ()
runBlueprint appProgram hooks = do
  putStrLn "blueprint"
  printNode firstChildIndent "app"
  appProgram (childIndent firstChildIndent)
  printNode firstChildIndent "hanging"
  runHanging (childIndent firstChildIndent) hooks

firstChildIndent :: Int
firstChildIndent =
  indentStep

indentStep :: Int
indentStep =
  4

childIndent :: Int -> Int
childIndent indent =
  indent + indentStep

factProgram :: Fact WorkflowFact -> Program
factProgram currentFact indent =
  case factExpression currentFact of
    FactItems currentFacts ->
      printNode indent ("fact " ++ renderFacts currentFacts)
    currentFacts -> do
      printNode indent "fact"
      printFactExpr (childIndent indent) currentFacts

chainProgram :: WorkflowName -> Chain Program -> Program
chainProgram label steps indent = do
  printNode indent ("chain " ++ renderWorkflowName label)
  runChildren (childIndent indent) (freeMonadSteps (chainSteps steps))

parallelProgram :: WorkflowName -> Parallel Program -> Program
parallelProgram label branches indent = do
  printNode indent ("parallel " ++ renderWorkflowName label)
  runChildren (childIndent indent) (freeApplicativeBranches (parallelBranches branches))

fallbackProgram :: Fallback Program -> Program
fallbackProgram branches indent = do
  printNode indent "fallback"
  runChildren (childIndent indent) (freeAlternativeBranches (fallbackBranches branches))

raceProgram :: Race Program -> Program
raceProgram branches indent = do
  printNode indent "race"
  runChildren (childIndent indent) (freeAlternativeBranches (raceBranches branches))

choiceProgram :: ChoiceKey -> Choice Program -> Program
choiceProgram selectedKey choices indent = do
  printNode indent ("choice " ++ renderChoiceKey selectedKey)
  mapM_ (runChoiceBranch (childIndent indent)) (freeChoiceBranches (choiceBranches choices))

waitProgram :: Wait WorkflowFact -> Program -> Program
waitProgram currentWait body indent = do
  printNode indent "wait"
  printFactExpr (childIndent indent) (waitFacts currentWait)
  printNode (childIndent indent) "continue"
  body (childIndent indent)

middlewareProgram :: Middleware Interceptor -> Program -> Program
middlewareProgram currentMiddleware body indent = do
  printNode indent ("middleware " ++ renderInterceptor (middlewareHook currentMiddleware))
  body (childIndent indent)

runHanging :: Int -> Hanging (HangingAction WorkflowFact Program) -> IO ()
runHanging indent actions =
  mapM_ (runHangingAction indent) (freeMonoidItems (hangingActions actions))

runHangingAction :: Int -> HangingAction WorkflowFact Program -> IO ()
runHangingAction indent (HangingCallback currentCallback) = do
  printNode indent "callback"
  printNode (childIndent indent) "when"
  printFactExpr (childIndent (childIndent indent)) (callbackFacts currentCallback)
  printNode (childIndent indent) "run"
  callbackBody currentCallback (childIndent (childIndent indent))
runHangingAction indent (HangingSuspense currentSuspense) = do
  printNode indent "suspense"
  printNode (childIndent indent) "when"
  printFactExpr (childIndent (childIndent indent)) (suspenseFacts currentSuspense)
  printNode (childIndent indent) "suspend"
  suspenseTarget currentSuspense (childIndent (childIndent indent))

printFactExpr :: Int -> FactExpr WorkflowFact -> IO ()
printFactExpr indent (FactItems currentFacts) =
  printNode indent ("fact " ++ renderFacts currentFacts)
printFactExpr indent (FactAll currentFacts) = do
  printNode indent "and"
  mapM_ (printFactExpr (childIndent indent)) currentFacts
printFactExpr indent (FactAny currentFacts) = do
  printNode indent "or"
  mapM_ (printFactExpr (childIndent indent)) currentFacts

runChildren :: Int -> [Program] -> IO ()
runChildren indent =
  mapM_ (\child -> child indent)

runChoiceBranch :: Int -> ChoiceBranch ChoiceKey Program -> IO ()
runChoiceBranch indent (ChoiceBranch key body) = do
  printNode indent ("branch " ++ renderChoiceKey key)
  body (childIndent indent)

printNode :: Int -> String -> IO ()
printNode indent =
  putStrLn . indentLine indent . ("|-- " ++)

indentLine :: Int -> String -> String
indentLine indent text =
  replicate indent ' ' ++ text

renderFacts :: Requirement WorkflowFact -> String
renderFacts currentFacts =
  "[" ++ joinWith ", " (map renderWorkflowFact (requirementEffectItems (requirementFacts currentFacts))) ++ "]"

renderWorkflowFact :: WorkflowFact -> String
renderWorkflowFact =
  show

renderInterceptor :: Interceptor -> String
renderInterceptor =
  lowerFirst . show

renderChoiceKey :: ChoiceKey -> String
renderChoiceKey (ChoiceKey value) =
  value

renderWorkflowName :: WorkflowName -> String
renderWorkflowName =
  lowerFirst . show

lowerFirst :: String -> String
lowerFirst [] =
  []
lowerFirst (firstChar : rest) =
  toLower firstChar : rest

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
