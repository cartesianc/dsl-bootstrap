module Interpreter.Runtime.Workflow.Node
  ( requestSuspense
  , runNamedWorkflow
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
  , try
  )

import Core.Architecture
  ( WorkflowName
  )
import Interpreter.Runtime.Facts
  ( mergeRuntime
  )
import Interpreter.Runtime.Monad
  ( askRuntimeEnv
  , getRuntimeState
  , liftRuntimeIO
  , modifyRuntimeState
  , runRuntimeM
  , throwRuntimeError
  , traceRuntimeM
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , RuntimeCallback (..)
  , RuntimeCallbackEvent (..)
  , RuntimeComponentEvent (..)
  , RuntimeComponentStatus (..)
  , RuntimeEnv (..)
  , RuntimeError (..)
  , RuntimeM (..)
  , RuntimeResult (..)
  , RuntimeSuspenseEvent (..)
  , WorkflowProgram
  , emptyRuntime
  )

runNamedWorkflow :: WorkflowName -> WorkflowProgram -> WorkflowProgram
runNamedWorkflow label body =
  RuntimeM $ \environment runtime -> do
    result <- runRuntimeM environment (enterComponent label runtime) (runNamedWorkflowBody label body)
    pure (exitRuntimeResult label result)

runNamedWorkflowBody :: WorkflowName -> WorkflowProgram -> WorkflowProgram
runNamedWorkflowBody label body = do
  environment <- askRuntimeEnv
  let currentCallbacks =
        filter ((== label) . runtimeCallbackTarget) (runtimeEnvCallbacks environment)
  if null currentCallbacks
    then body
    else runWorkflowWithCallbacks label body currentCallbacks

runWorkflowWithCallbacks ::
  WorkflowName ->
  WorkflowProgram ->
  [RuntimeCallback] ->
  WorkflowProgram
runWorkflowWithCallbacks label body callbacks = do
  modifyRuntimeState
    ( \runtime ->
        runtime
          { runtimeCallbackEvents =
              runtimeCallbackEvents runtime <> [RuntimeCallbackTriggered label]
          }
    )
  traceRuntimeM ("callback " ++ show label ++ " fork " ++ show (length callbacks))
  environment <- askRuntimeEnv
  runtime <- getRuntimeState
  let branches = body : map runtimeCallbackBody callbacks
  results <- liftRuntimeIO (runCallbackBranches environment runtime branches)
  mergeCallbackResults label results

runCallbackBranches ::
  RuntimeEnv ->
  Runtime ->
  [WorkflowProgram] ->
  IO [RuntimeResult ()]
runCallbackBranches environment runtime branches = do
  resultBoxes <- mapM (forkCallbackBranch environment runtime) branches
  mapM takeCallbackBranchResult resultBoxes

forkCallbackBranch ::
  RuntimeEnv ->
  Runtime ->
  WorkflowProgram ->
  IO (MVar (Either SomeException (RuntimeResult ())))
forkCallbackBranch environment runtime branch = do
  resultBox <- newEmptyMVar
  _ <- forkIO (try (runRuntimeM environment (branchRuntime runtime) branch) >>= putMVar resultBox)
  pure resultBox

takeCallbackBranchResult ::
  MVar (Either SomeException (RuntimeResult ())) ->
  IO (RuntimeResult ())
takeCallbackBranchResult resultBox = do
  result <- takeMVar resultBox
  case result of
    Right runtimeResult ->
      pure runtimeResult
    Left exception ->
      pure (RuntimeFailed (RuntimeIoException (show exception)) emptyRuntime)

mergeCallbackResults :: WorkflowName -> [RuntimeResult ()] -> WorkflowProgram
mergeCallbackResults label results = do
  let failure = firstFailure results
  mapM_ mergeResultRuntime results
  case failure of
    Nothing -> do
      modifyRuntimeState
        ( \runtime ->
            runtime
              { runtimeCallbackEvents =
                  runtimeCallbackEvents runtime <> [RuntimeCallbackCompleted label]
              }
        )
      traceRuntimeM ("callback " ++ show label ++ " done")
    Just errorReport -> do
      modifyRuntimeState
        ( \runtime ->
            runtime
              { runtimeCallbackEvents =
                  runtimeCallbackEvents runtime <> [RuntimeCallbackFailed label]
              }
        )
      throwRuntimeError errorReport

mergeResultRuntime :: RuntimeResult () -> WorkflowProgram
mergeResultRuntime result =
  case result of
    RuntimeSucceeded _ runtime ->
      modifyRuntimeState (`mergeRuntime` runtime)
    RuntimeFailed _ runtime ->
      modifyRuntimeState (`mergeRuntime` runtime)

firstFailure :: [RuntimeResult ()] -> Maybe RuntimeError
firstFailure [] =
  Nothing
firstFailure (currentResult : rest) =
  case currentResult of
    RuntimeSucceeded _ _ ->
      firstFailure rest
    RuntimeFailed errorReport _ ->
      Just errorReport

requestSuspense :: WorkflowName -> WorkflowProgram
requestSuspense target = do
  runtime <- getRuntimeState
  let status = componentStatus runtime target
  modifyRuntimeState
    ( \currentRuntime ->
        currentRuntime
          { runtimeSuspenseEvents =
              runtimeSuspenseEvents currentRuntime <> [RuntimeSuspenseRequested target status]
          }
    )
  traceRuntimeM ("suspense requested " ++ show target ++ " " ++ renderComponentStatus status)

componentStatus :: Runtime -> WorkflowName -> RuntimeComponentStatus
componentStatus runtime target
  | target `elem` runtimeActiveComponents runtime =
      RuntimeComponentRunning
  | target `elem` runtimeCompletedComponents runtime =
      RuntimeComponentCompleted
  | otherwise =
      RuntimeComponentNotStarted

enterComponent :: WorkflowName -> Runtime -> Runtime
enterComponent label runtime =
  runtime
    { runtimeActiveComponents = label : runtimeActiveComponents runtime
    , runtimeComponentEvents = runtimeComponentEvents runtime <> [RuntimeComponentEntered label]
    }

exitComponent :: WorkflowName -> Runtime -> Runtime
exitComponent label runtime =
  runtime
    { runtimeActiveComponents = removeFirst label (runtimeActiveComponents runtime)
    , runtimeCompletedComponents = addUnique label (runtimeCompletedComponents runtime)
    , runtimeComponentEvents = runtimeComponentEvents runtime <> [RuntimeComponentExited label]
    }

exitRuntimeResult :: WorkflowName -> RuntimeResult a -> RuntimeResult a
exitRuntimeResult label result =
  case result of
    RuntimeSucceeded value runtime ->
      RuntimeSucceeded value (exitComponent label runtime)
    RuntimeFailed errorReport runtime ->
      RuntimeFailed errorReport (exitComponent label runtime)

branchRuntime :: Runtime -> Runtime
branchRuntime runtime =
  runtime
    { runtimeTrace = []
    , runtimeComponentEvents = []
    , runtimeCallbackEvents = []
    , runtimeSuspenseEvents = []
    , runtimeMiddlewareEvents = []
    }

removeFirst :: Eq item => item -> [item] -> [item]
removeFirst _ [] =
  []
removeFirst item (currentItem : rest)
  | item == currentItem =
      rest
  | otherwise =
      currentItem : removeFirst item rest

addUnique :: Eq item => item -> [item] -> [item]
addUnique item items
  | item `elem` items =
      items
  | otherwise =
      item : items

renderComponentStatus :: RuntimeComponentStatus -> String
renderComponentStatus status =
  case status of
    RuntimeComponentNotStarted ->
      "not-started"
    RuntimeComponentRunning ->
      "running"
    RuntimeComponentCompleted ->
      "completed"
