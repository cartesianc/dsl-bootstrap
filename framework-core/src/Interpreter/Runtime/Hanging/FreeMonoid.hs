module Interpreter.Runtime.Hanging.FreeMonoid
  ( runHanging
  , runtimeCallbacksFromHanging
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
  ( mergeRuntime
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
  ( runtimeSleep
  , traceRuntime
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , RuntimeCallback (..)
  , RuntimeEnv
  , RuntimeError (..)
  , RuntimeResult (..)
  , WorkflowProgram
  )
import Interpreter.Runtime.Workflow.Node
  ( requestSuspense
  )

runHanging ::
  Hanging (HangingAction WorkflowFact Interceptor WorkflowProgram) ->
  WorkflowProgram
runHanging actions = do
  let currentActions = runtimeHangingActions (freeMonoidItems (hangingActions actions))
  environment <- askRuntimeEnv
  runtime <- getRuntimeState
  traceRuntimeM ("hanging fork " ++ show (length currentActions))
  resultBoxes <- liftRuntimeIO (mapM (forkHangingAction environment runtime) currentActions)
  results <- liftRuntimeIO (mapM takeHangingResult resultBoxes)
  mergeHangingResults results
  traceRuntimeM "hanging done"

runtimeCallbacksFromHanging ::
  Hanging (HangingAction WorkflowFact Interceptor WorkflowProgram) ->
  [RuntimeCallback]
runtimeCallbacksFromHanging actions =
  [ RuntimeCallback
      { runtimeCallbackTarget = callbackTarget currentCallback
      , runtimeCallbackBody = callbackBody currentCallback
      }
  | HangingCallback currentCallback <- currentActions
  ]
  where
    currentActions =
      freeMonoidItems (hangingActions actions)

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

runtimeHangingActions ::
  [HangingAction fact hook workflow] ->
  [HangingAction fact hook workflow]
runtimeHangingActions =
  filter runtimeHangingAction

runtimeHangingAction :: HangingAction fact hook workflow -> Bool
runtimeHangingAction action =
  case action of
    HangingCallback _ ->
      False
    _ ->
      True

runCallback ::
  Callback WorkflowFact WorkflowProgram ->
  WorkflowProgram
runCallback currentCallback =
  traceRuntimeM ("callback registered " ++ show (callbackTarget currentCallback))

runSuspense ::
  Suspense WorkflowFact WorkflowProgram ->
  WorkflowProgram
runSuspense currentSuspense =
  requestSuspense (suspenseTarget currentSuspense)

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

branchRuntime :: Runtime -> Runtime
branchRuntime runtime =
  runtime
    { runtimeTrace = []
    , runtimeComponentEvents = []
    , runtimeCallbackEvents = []
    , runtimeSuspenseEvents = []
    , runtimeMiddlewareEvents = []
    }

emptyBranchRuntime :: Runtime
emptyBranchRuntime =
  Runtime
    { availableFacts = []
    , availablePipeTypes = []
    , runtimeValues = []
    , runtimeTypedValues = []
    , runtimeFactClaims = []
    , runtimeTrace = []
    , runtimeActiveComponents = []
    , runtimeCompletedComponents = []
    , runtimeComponentEvents = []
    , runtimeCallbackEvents = []
    , runtimeSuspenseEvents = []
    , runtimeMiddlewareStack = []
    , runtimeMiddlewareEvents = []
    , runtimeFailureDiagnoses = []
    }
