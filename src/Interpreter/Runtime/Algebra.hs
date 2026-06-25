module Interpreter.Runtime.Algebra
  ( runtimeAlgebra
  ) where

import Control.Exception
  ( SomeException
  , try
  )

import AST.Vocabulary
import Core.Architecture
import Core.Architecture.Cata
import Core.Architecture.Internal
  ( ChoiceBranch (..)
  , FreeAlternative (..)
  , FreeChoice (..)
  , foldFreeApplicativeState
  , foldFreeMonadState
  , foldRequirementEffectState
  )
import Interpreter.Runtime.Types

runtimeAlgebra :: WorkflowAlgebra WorkflowFact Interceptor WorkflowProgram
runtimeAlgebra =
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

factProgram :: Fact WorkflowFact -> WorkflowProgram
factProgram currentFact runtime =
  recordFact runtime currentFact

chainProgram :: WorkflowName -> Chain WorkflowProgram -> WorkflowProgram
chainProgram _ steps runtime =
  foldFreeMonadState runProgram runtime (chainSteps steps)

parallelProgram :: WorkflowName -> Parallel WorkflowProgram -> WorkflowProgram
parallelProgram _ branches runtime =
  foldFreeApplicativeState runProgram runtime (parallelBranches branches)

fallbackProgram :: Fallback WorkflowProgram -> WorkflowProgram
fallbackProgram branches runtime =
  runFallbackWorkflow runtime (freeAlternativeBranches (fallbackBranches branches))

raceProgram :: Race WorkflowProgram -> WorkflowProgram
raceProgram branches runtime =
  runRaceWorkflow runtime (freeAlternativeBranches (raceBranches branches))

choiceProgram :: ChoiceKey -> Choice WorkflowProgram -> WorkflowProgram
choiceProgram selectedKey branches runtime =
  runChoiceWorkflow runtime selectedKey (freeChoiceBranches (choiceBranches branches))

waitProgram :: Wait WorkflowFact -> WorkflowProgram -> WorkflowProgram
waitProgram _ body runtime =
  body runtime

middlewareProgram :: Middleware Interceptor -> WorkflowProgram -> WorkflowProgram
middlewareProgram currentMiddleware body runtime = do
  beforeRuntime <- runInterceptor BeforePhase runtime (middlewareHook currentMiddleware)
  nextRuntime <- body beforeRuntime
  runInterceptor AfterPhase nextRuntime (middlewareHook currentMiddleware)

runProgram :: Runtime -> WorkflowProgram -> IO Runtime
runProgram runtime program =
  program runtime

recordFact :: Runtime -> Fact WorkflowFact -> IO Runtime
recordFact runtime currentFact = do
  newFacts <- collectFactExpr (factExpression currentFact)
  pure runtime {availableFacts = mergeFacts (availableFacts runtime) newFacts}

collectFactExpr :: FactExpr WorkflowFact -> IO [WorkflowFact]
collectFactExpr (FactItems currentFacts) =
  collectFacts currentFacts
collectFactExpr (FactAll currentFacts) =
  concat <$> mapM collectFactExpr currentFacts
collectFactExpr (FactAny currentFacts) =
  concat <$> mapM collectFactExpr currentFacts

collectFacts :: Requirement WorkflowFact -> IO [WorkflowFact]
collectFacts =
  foldRequirementEffectState collectFact [] . requirementFacts
  where
    collectFact facts currentFact =
      pure (currentFact : facts)

mergeFacts :: [WorkflowFact] -> [WorkflowFact] -> [WorkflowFact]
mergeFacts =
  foldl addFact
  where
    addFact facts currentFact
      | currentFact `elem` facts = facts
      | otherwise = currentFact : facts

runFallbackWorkflow ::
  Runtime ->
  [WorkflowProgram] ->
  IO Runtime
runFallbackWorkflow _ [] =
  ioError (userError "Fallback workflow has no successful branch")
runFallbackWorkflow runtime (branch : rest) = do
  branchResult <- try (branch runtime)
  case (branchResult :: Either SomeException Runtime) of
    Right nextRuntime ->
      pure nextRuntime
    Left _ ->
      runFallbackWorkflow runtime rest

runRaceWorkflow ::
  Runtime ->
  [WorkflowProgram] ->
  IO Runtime
runRaceWorkflow _ [] =
  ioError (userError "Race workflow has no branches")
runRaceWorkflow runtime (branch : _) =
  branch runtime

runChoiceWorkflow ::
  Runtime ->
  ChoiceKey ->
  [ChoiceBranch ChoiceKey WorkflowProgram] ->
  IO Runtime
runChoiceWorkflow _ selectedKey [] =
  ioError (userError ("Choice workflow has no branch for " ++ renderChoiceKey selectedKey))
runChoiceWorkflow runtime selectedKey (ChoiceBranch branchKey branch : rest)
  | selectedKey == branchKey =
      branch runtime
  | otherwise =
      runChoiceWorkflow runtime selectedKey rest

data InterceptorPhase
  = BeforePhase
  | AfterPhase

runInterceptor :: InterceptorPhase -> Runtime -> Interceptor -> IO Runtime
runInterceptor BeforePhase runtime BootMiddleware = do
  putStrLn ("[LOG] " ++ renderLogEvent AppStarted)
  pure runtime
runInterceptor AfterPhase runtime RuntimeMiddleware = do
  putStrLn ("[LOG] " ++ renderLogEvent RuntimePrepared)
  pure runtime
runInterceptor AfterPhase runtime ReportMiddleware = do
  putStrLn ("[LOG] " ++ renderLogEvent ReportFinished)
  pure runtime
runInterceptor AfterPhase runtime ShutdownMiddleware = do
  putStrLn ("[LOG] " ++ renderLogEvent AppFinished)
  pure runtime
runInterceptor _ runtime _ =
  pure runtime

renderLogEvent :: LogEvent -> String
renderLogEvent AppStarted = "应用启动"
renderLogEvent RuntimePrepared = "运行时准备完成"
renderLogEvent AppFinished = "应用结束"
renderLogEvent UserRemembered = "用户输入"
renderLogEvent ReportFinished = "计算报告完成"

renderChoiceKey :: ChoiceKey -> String
renderChoiceKey (ChoiceKey value) =
  value
