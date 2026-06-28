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
import Interpreter.Runtime.Types
  ( Runtime
  , WorkflowProgram
  )
import Interpreter.Runtime.Trace
  ( traceRuntime
  )

freeAlternativeFallback :: Fallback WorkflowProgram -> WorkflowProgram
freeAlternativeFallback branches runtime = do
  traceRuntime "fallback start"
  runFallback runtime (freeAlternativeBranches (fallbackBranches branches))

freeAlternativeRace :: Race WorkflowProgram -> WorkflowProgram
freeAlternativeRace branches runtime = do
  traceRuntime "race start"
  runRace runtime (freeAlternativeBranches (raceBranches branches))

runFallback ::
  Runtime ->
  [WorkflowProgram] ->
  IO Runtime
runFallback _ [] =
  ioError (userError "Fallback workflow has no successful branch")
runFallback runtime (branch : rest) = do
  branchResult <- try (branch runtime)
  case (branchResult :: Either SomeException Runtime) of
    Right nextRuntime -> do
      traceRuntime "fallback branch ok"
      pure nextRuntime
    Left _ -> do
      traceRuntime "fallback branch failed"
      runFallback runtime rest

runRace ::
  Runtime ->
  [WorkflowProgram] ->
  IO Runtime
runRace _ [] =
  ioError (userError "Race workflow has no branches")
runRace runtime branches = do
  resultBox <- newEmptyMVar
  mapM_ (forkRaceBranch resultBox runtime) branches
  takeFirstSuccessfulBranch (length branches) resultBox

forkRaceBranch ::
  MVar (Either SomeException Runtime) ->
  Runtime ->
  WorkflowProgram ->
  IO ()
forkRaceBranch resultBox runtime branch = do
  _ <- forkIO (try (branch runtime) >>= putMVar resultBox)
  pure ()

takeFirstSuccessfulBranch ::
  Int ->
  MVar (Either SomeException Runtime) ->
  IO Runtime
takeFirstSuccessfulBranch 0 _ =
  ioError (userError "Race workflow has no successful branch")
takeFirstSuccessfulBranch remaining resultBox = do
  result <- takeMVar resultBox
  case result of
    Right runtime -> do
      traceRuntime "race branch won"
      pure runtime
    Left _ -> do
      traceRuntime "race branch failed"
      takeFirstSuccessfulBranch (remaining - 1) resultBox
