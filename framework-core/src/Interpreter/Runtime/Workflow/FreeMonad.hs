module Interpreter.Runtime.Workflow.FreeMonad
  ( freeMonadChain
  ) where

import Core.Architecture
  ( Chain (..)
  , WorkflowName
  )
import Core.Architecture.Internal
  ( FreeMonad (..)
  )
import Interpreter.Runtime.Monad
  ( traceRuntimeM
  )
import Interpreter.Runtime.Types
  ( WorkflowProgram
  )
import Interpreter.Runtime.Workflow.Node
  ( runNamedWorkflow
  )

freeMonadChain :: WorkflowName -> Chain WorkflowProgram -> WorkflowProgram
freeMonadChain label steps =
  runNamedWorkflow label $ do
    traceRuntimeM ("chain " ++ show label)
    mapM_ id (freeMonadSteps (chainSteps steps))
