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
  , RuntimeEnv
  , RuntimeError (..)
  , WorkflowProgram
  , RuntimeResult (..)
  )
import Interpreter.Runtime.Workflow.Node
  ( runNamedWorkflow
  )

freeApplicativeParallel :: WorkflowName -> Parallel WorkflowProgram -> WorkflowProgram
freeApplicativeParallel label branches =
  runNamedWorkflow label $ do
    let branchPrograms = freeApplicativeBranches (parallelBranches branches)
    environment <- askRuntimeEnv
    runtime <- getRuntimeState
    traceRuntimeM ("parallel " ++ show label ++ " fork " ++ show (length branchPrograms))
    results <- liftRuntimeIO (runParallelBranches environment runtime branchPrograms)
    mergeParallelResults results
    traceRuntimeM ("parallel " ++ show label ++ " done")

runParallelBranches :: RuntimeEnv -> Runtime -> [WorkflowProgram] -> IO [RuntimeResult ()]
runParallelBranches environment runtime branches = do
  resultBoxes <- mapM (forkBranch environment runtime) branches
  mapM takeBranchResult resultBoxes

forkBranch ::
  RuntimeEnv ->
  Runtime ->
  WorkflowProgram ->
  IO (MVar (Either SomeException (RuntimeResult ())))
forkBranch environment runtime branch = do
  resultBox <- newEmptyMVar
  _ <- forkIO (try (runRuntimeM environment (branchRuntime runtime) branch) >>= putMVar resultBox)
  pure resultBox

takeBranchResult ::
  MVar (Either SomeException (RuntimeResult ())) ->
  IO (RuntimeResult ())
takeBranchResult resultBox = do
  result <- takeMVar resultBox
  case result of
    Right runtimeResult ->
      pure runtimeResult
    Left exception ->
      pure (RuntimeFailed (RuntimeIoException (show exception)) emptyBranchRuntime)

mergeParallelResults :: [RuntimeResult ()] -> WorkflowProgram
mergeParallelResults [] =
  pure ()
mergeParallelResults (currentResult : rest) =
  case currentResult of
    RuntimeSucceeded _ runtime -> do
      modifyRuntimeState (`mergeRuntime` runtime)
      mergeParallelResults rest
    RuntimeFailed errorReport runtime -> do
      modifyRuntimeState (`mergeRuntime` runtime)
      throwRuntimeError errorReport

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
