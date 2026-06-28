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
  , throwIO
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
import Interpreter.Runtime.Trace
  ( renderFactExpr
  , runtimeSleep
  , traceRuntime
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , WorkflowProgram
  )

runHanging ::
  Hanging (HangingAction WorkflowFact Interceptor WorkflowProgram) ->
  WorkflowProgram
runHanging actions runtime = do
  let currentActions = freeMonoidItems (hangingActions actions)
  traceRuntime ("hanging fork " ++ show (length currentActions))
  resultBoxes <- mapM (forkHangingAction runtime) currentActions
  results <- mapM takeHangingResult resultBoxes
  traceRuntime "hanging done"
  pure (foldl mergeRuntime runtime results)

forkHangingAction ::
  Runtime ->
  HangingAction WorkflowFact Interceptor WorkflowProgram ->
  IO (MVar (Either SomeException Runtime))
forkHangingAction runtime action = do
  resultBox <- newEmptyMVar
  _ <- forkIO (try (runHangingAction action runtime) >>= putMVar resultBox)
  pure resultBox

takeHangingResult ::
  MVar (Either SomeException Runtime) ->
  IO Runtime
takeHangingResult resultBox = do
  result <- takeMVar resultBox
  case result of
    Right runtime ->
      pure runtime
    Left exception ->
      throwIO exception

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
runCallback currentCallback runtime
  | factExprAvailable runtime (callbackFacts currentCallback) = do
      traceRuntime ("callback triggered " ++ renderFactExpr (callbackFacts currentCallback))
      resultBox <- newEmptyMVar
      _ <- forkIO (try (callbackBody currentCallback runtime) >>= putMVar resultBox)
      result <- takeHangingResult resultBox
      traceRuntime "callback done"
      pure result
  | otherwise = do
      traceRuntime ("callback skipped " ++ renderFactExpr (callbackFacts currentCallback))
      pure runtime

runSuspense ::
  Suspense WorkflowFact WorkflowProgram ->
  WorkflowProgram
runSuspense currentSuspense runtime
  | factExprAvailable runtime (suspenseFacts currentSuspense) = do
      traceRuntime ("suspense requested " ++ renderFactExpr (suspenseFacts currentSuspense))
      traceRuntime "suspense pending component registry"
      pure runtime
  | otherwise = do
      traceRuntime ("suspense skipped " ++ renderFactExpr (suspenseFacts currentSuspense))
      pure runtime

runLoop ::
  Loop WorkflowProgram ->
  WorkflowProgram
runLoop currentLoop runtime = do
  traceRuntime "loop forever start"
  _ <- forkIO (runForever (loopBody currentLoop) runtime)
  pure runtime

runForever ::
  WorkflowProgram ->
  Runtime ->
  IO ()
runForever body runtime = do
  result <- try (body runtime)
  case result of
    Right nextRuntime -> do
      runtimeSleep
      runForever body nextRuntime
    Left exception ->
      traceRuntime ("loop stopped " ++ show (exception :: SomeException))

runMiddleware ::
  Middleware Interceptor ->
  WorkflowProgram ->
  WorkflowProgram
runMiddleware currentMiddleware body runtime = do
  traceRuntime ("middleware " ++ show (middlewareHook currentMiddleware) ++ " begin")
  nextRuntime <- body runtime
  traceRuntime ("middleware " ++ show (middlewareHook currentMiddleware) ++ " end")
  pure nextRuntime
