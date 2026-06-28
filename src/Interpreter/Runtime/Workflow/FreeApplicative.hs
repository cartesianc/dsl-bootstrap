module Interpreter.Runtime.Workflow.FreeApplicative
  ( freeApplicativeParallel
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

import Core.Architecture
  ( Parallel (..)
  , WorkflowName
  )
import Core.Architecture.Internal
  ( FreeApplicative (..)
  )
import Interpreter.Runtime.Facts
  ( mergeRuntime
  )
import Interpreter.Runtime.Types
  ( Runtime
  , WorkflowProgram
  )
import Interpreter.Runtime.Trace
  ( traceRuntime
  )

freeApplicativeParallel :: WorkflowName -> Parallel WorkflowProgram -> WorkflowProgram
freeApplicativeParallel label branches runtime = do
  let branchPrograms = freeApplicativeBranches (parallelBranches branches)
  traceRuntime ("parallel " ++ show label ++ " fork " ++ show (length branchPrograms))
  results <- runParallelBranches runtime branchPrograms
  traceRuntime ("parallel " ++ show label ++ " done")
  pure (foldl mergeRuntime runtime results)

runParallelBranches :: Runtime -> [WorkflowProgram] -> IO [Runtime]
runParallelBranches runtime branches = do
  resultBoxes <- mapM (forkBranch runtime) branches
  mapM takeBranchResult resultBoxes

forkBranch ::
  Runtime ->
  WorkflowProgram ->
  IO (MVar (Either SomeException Runtime))
forkBranch runtime branch = do
  resultBox <- newEmptyMVar
  _ <- forkIO (try (branch runtime) >>= putMVar resultBox)
  pure resultBox

takeBranchResult ::
  MVar (Either SomeException Runtime) ->
  IO Runtime
takeBranchResult resultBox = do
  result <- takeMVar resultBox
  case result of
    Right runtime ->
      pure runtime
    Left exception ->
      throwIO exception
