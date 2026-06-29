module Interpreter.Runtime.Workflow.FreeAlternative
  ( freeAlternativeFallback
  , freeAlternativeRace
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
  ( Fallback (..)
  , Race (..)
  )
import Core.Architecture.Internal
  ( FreeAlternative (..)
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
import Interpreter.Runtime.Types
  ( Runtime (..)
  , RuntimeEnv
  , RuntimeError (..)
  , RuntimeResult (..)
  , WorkflowProgram
  )

freeAlternativeFallback :: Fallback WorkflowProgram -> WorkflowProgram
freeAlternativeFallback branches = do
  traceRuntimeM "fallback start"
  runFallback (freeAlternativeBranches (fallbackBranches branches))

freeAlternativeRace :: Race WorkflowProgram -> WorkflowProgram
freeAlternativeRace branches = do
  traceRuntimeM "race start"
  runRace (freeAlternativeBranches (raceBranches branches))

runFallback ::
  [WorkflowProgram] ->
  WorkflowProgram
runFallback [] =
  throwRuntimeError RuntimeFallbackExhausted
runFallback (branch : rest) = do
  environment <- askRuntimeEnv
  runtime <- getRuntimeState
  branchResult <- liftRuntimeIO (runRuntimeM environment runtime branch)
  case branchResult of
    RuntimeSucceeded _ nextRuntime -> do
      putRuntimeState nextRuntime
      traceRuntimeM "fallback branch ok"
    RuntimeFailed _ _ -> do
      traceRuntimeM "fallback branch failed"
      runFallback rest

runRace ::
  [WorkflowProgram] ->
  WorkflowProgram
runRace [] =
  throwRuntimeError RuntimeRaceEmpty
runRace branches = do
  environment <- askRuntimeEnv
  runtime <- getRuntimeState
  resultBox <- liftRuntimeIO newEmptyMVar
  liftRuntimeIO (mapM_ (forkRaceBranch resultBox environment runtime) branches)
  takeFirstSuccessfulBranch (length branches) resultBox

forkRaceBranch ::
  MVar (Either SomeException (RuntimeResult ())) ->
  RuntimeEnv ->
  Runtime ->
  WorkflowProgram ->
  IO ()
forkRaceBranch resultBox environment runtime branch = do
  _ <- forkIO (try (runRuntimeM environment (branchRuntime runtime) branch) >>= putMVar resultBox)
  pure ()

takeFirstSuccessfulBranch ::
  Int ->
  MVar (Either SomeException (RuntimeResult ())) ->
  WorkflowProgram
takeFirstSuccessfulBranch 0 _ =
  throwRuntimeError RuntimeRaceExhausted
takeFirstSuccessfulBranch remaining resultBox = do
  result <- liftRuntimeIO (takeMVar resultBox)
  case result of
    Right (RuntimeSucceeded _ runtime) -> do
      putRuntimeState runtime
      traceRuntimeM "race branch won"
    Right (RuntimeFailed _ _) -> do
      traceRuntimeM "race branch failed"
      takeFirstSuccessfulBranch (remaining - 1) resultBox
    Left exception -> do
      traceRuntimeM ("race branch failed with " ++ show (exception :: SomeException))
      takeFirstSuccessfulBranch (remaining - 1) resultBox

branchRuntime :: Runtime -> Runtime
branchRuntime runtime =
  runtime
    { runtimeTrace = []
    , runtimeMiddlewareEvents = []
    }
