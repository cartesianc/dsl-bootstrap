module Interpreter.Runtime.Hanging.FreeMonoid
  ( runHanging
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

import AST.Vocabulary
  ( Interceptor
  , WorkflowFact
  )
import Core.Architecture
  ( Callback (..)
  , Hanging (..)
  , HangingAction (..)
  , Loop (..)
  , Middleware (..)
  , Suspense (..)
  )
import Core.Architecture.Internal
  ( FreeMonoid (..)
  )
import Interpreter.Runtime.Facts
  ( factExprAvailable
  , mergeRuntime
  )
import Interpreter.Runtime.Monad
  ( askRuntimeEnv
  , getRuntimeState
  , liftRuntimeIO
  , putRuntimeState
  , runRuntimeM
  , throwRuntimeError
  , traceRuntimeM
  )
import Interpreter.Runtime.Middleware
  ( withRuntimeMiddleware
  )
import Interpreter.Runtime.Trace
  ( renderFactExpr
  , runtimeSleep
  , traceRuntime
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , RuntimeEnv
  , RuntimeError (..)
  , RuntimeResult (..)
  , WorkflowProgram
  )

runHanging ::
  Hanging (HangingAction WorkflowFact Interceptor WorkflowProgram) ->
  WorkflowProgram
runHanging actions = do
  let currentActions = freeMonoidItems (hangingActions actions)
  environment <- askRuntimeEnv
  runtime <- getRuntimeState
  traceRuntimeM ("hanging fork " ++ show (length currentActions))
  resultBoxes <- liftRuntimeIO (mapM (forkHangingAction environment runtime) currentActions)
  results <- liftRuntimeIO (mapM takeHangingResult resultBoxes)
  mergeHangingResults results
  traceRuntimeM "hanging done"

forkHangingAction ::
  RuntimeEnv ->
  Runtime ->
  HangingAction WorkflowFact Interceptor WorkflowProgram ->
  IO (MVar (Either SomeException (RuntimeResult ())))
forkHangingAction environment runtime action = do
  resultBox <- newEmptyMVar
  _ <- forkIO (try (runRuntimeM environment (branchRuntime runtime) (runHangingAction action)) >>= putMVar resultBox)
  pure resultBox

takeHangingResult ::
  MVar (Either SomeException (RuntimeResult ())) ->
  IO (RuntimeResult ())
takeHangingResult resultBox = do
  result <- takeMVar resultBox
  case result of
    Right runtimeResult ->
      pure runtimeResult
    Left exception ->
      pure (RuntimeFailed (RuntimeIoException (show exception)) emptyBranchRuntime)

mergeHangingResults :: [RuntimeResult ()] -> WorkflowProgram
mergeHangingResults [] =
  pure ()
mergeHangingResults (currentResult : rest) =
  case currentResult of
    RuntimeSucceeded _ runtime -> do
      currentRuntime <- getRuntimeState
      putRuntimeState (mergeRuntime currentRuntime runtime)
      mergeHangingResults rest
    RuntimeFailed errorReport runtime -> do
      currentRuntime <- getRuntimeState
      putRuntimeState (mergeRuntime currentRuntime runtime)
      throwRuntimeError errorReport

runHangingAction ::
  HangingAction WorkflowFact Interceptor WorkflowProgram ->
  WorkflowProgram
runHangingAction (HangingCallback currentCallback) =
  runCallback currentCallback
runHangingAction (HangingSuspense currentSuspense) =
  runSuspense currentSuspense
runHangingAction (HangingLoop currentLoop) =
  runLoop currentLoop
runHangingAction (HangingMiddleware currentMiddleware body) =
  runMiddleware currentMiddleware body

runCallback ::
  Callback WorkflowFact WorkflowProgram ->
  WorkflowProgram
runCallback currentCallback = do
  runtime <- getRuntimeState
  if factExprAvailable runtime (callbackFacts currentCallback)
    then do
      environment <- askRuntimeEnv
      traceRuntimeM ("callback triggered " ++ renderFactExpr (callbackFacts currentCallback))
      resultBox <- liftRuntimeIO (forkWorkflowProgram environment runtime (callbackBody currentCallback))
      result <- liftRuntimeIO (takeHangingResult resultBox)
      case result of
        RuntimeSucceeded _ nextRuntime -> do
          putRuntimeState (mergeRuntime runtime nextRuntime)
          traceRuntimeM "callback done"
        RuntimeFailed errorReport _ ->
          throwRuntimeError errorReport
    else
      traceRuntimeM ("callback skipped " ++ renderFactExpr (callbackFacts currentCallback))

runSuspense ::
  Suspense WorkflowFact WorkflowProgram ->
  WorkflowProgram
runSuspense currentSuspense = do
  runtime <- getRuntimeState
  if factExprAvailable runtime (suspenseFacts currentSuspense)
    then do
      traceRuntimeM ("suspense requested " ++ renderFactExpr (suspenseFacts currentSuspense))
      traceRuntimeM "suspense pending component registry"
    else
      traceRuntimeM ("suspense skipped " ++ renderFactExpr (suspenseFacts currentSuspense))

runLoop ::
  Loop WorkflowProgram ->
  WorkflowProgram
runLoop currentLoop = do
  environment <- askRuntimeEnv
  runtime <- getRuntimeState
  traceRuntimeM "loop forever start"
  _ <- liftRuntimeIO (forkIO (runForever environment (loopBody currentLoop) runtime))
  pure ()

runForever ::
  RuntimeEnv ->
  WorkflowProgram ->
  Runtime ->
  IO ()
runForever environment body runtime = do
  result <- try (runRuntimeM environment (branchRuntime runtime) body)
  case result of
    Right (RuntimeSucceeded _ nextRuntime) -> do
      runtimeSleep
      runForever environment body nextRuntime
    Right (RuntimeFailed errorReport _) ->
      traceRuntime ("loop stopped " ++ show errorReport)
    Left exception ->
      traceRuntime ("loop stopped " ++ show (exception :: SomeException))

runMiddleware ::
  Middleware Interceptor ->
  WorkflowProgram ->
  WorkflowProgram
runMiddleware currentMiddleware body = do
  withRuntimeMiddleware (middlewareHook currentMiddleware) $ do
    traceRuntimeM ("middleware " ++ show (middlewareHook currentMiddleware) ++ " begin")
    body
    traceRuntimeM ("middleware " ++ show (middlewareHook currentMiddleware) ++ " end")

forkWorkflowProgram ::
  RuntimeEnv ->
  Runtime ->
  WorkflowProgram ->
  IO (MVar (Either SomeException (RuntimeResult ())))
forkWorkflowProgram environment runtime program = do
  resultBox <- newEmptyMVar
  _ <- forkIO (try (runRuntimeM environment (branchRuntime runtime) program) >>= putMVar resultBox)
  pure resultBox

branchRuntime :: Runtime -> Runtime
branchRuntime runtime =
  runtime
    { runtimeTrace = []
    , runtimeMiddlewareEvents = []
    }

emptyBranchRuntime :: Runtime
emptyBranchRuntime =
  Runtime
    { availableFacts = []
    , runtimeTrace = []
    , runtimeMiddlewareStack = []
    , runtimeMiddlewareEvents = []
    }
