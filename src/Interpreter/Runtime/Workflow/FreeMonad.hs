module Interpreter.Runtime.Workflow.FreeMonad
  ( freeMonadChain
  ) where

import Core.Architecture
  ( Chain (..)
  , WorkflowName
  )
import Core.Architecture.Internal
  ( foldFreeMonadState
  )
import Interpreter.Runtime.Types
  ( Runtime
  , WorkflowProgram
  )
import Interpreter.Runtime.Trace
  ( traceRuntime
  )

freeMonadChain :: WorkflowName -> Chain WorkflowProgram -> WorkflowProgram
freeMonadChain label steps runtime = do
  traceRuntime ("chain " ++ show label)
  foldFreeMonadState runStep runtime (chainSteps steps)

runStep :: Runtime -> WorkflowProgram -> IO Runtime
runStep runtime program =
  program runtime
