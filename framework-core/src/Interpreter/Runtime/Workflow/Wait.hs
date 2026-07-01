module Interpreter.Runtime.Workflow.Wait
  ( waitForFacts
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Architecture
  ( Wait (..)
  )
import Interpreter.Runtime.Facts
  ( factExprAvailable
  )
import Interpreter.Runtime.Monad
  ( getRuntimeState
  , throwRuntimeError
  , traceRuntimeM
  )
import Interpreter.Runtime.Trace
  ( renderFactExpr
  )
import Interpreter.Runtime.Types
  ( RuntimeError (..)
  , WorkflowProgram
  )

waitForFacts :: Wait WorkflowFact -> WorkflowProgram -> WorkflowProgram
waitForFacts currentWait body = do
  runtime <- getRuntimeState
  if factExprAvailable runtime (waitFacts currentWait)
    then do
      traceRuntimeM ("wait ok " ++ renderFactExpr (waitFacts currentWait))
      body
    else do
      let facts = renderFactExpr (waitFacts currentWait)
      traceRuntimeM ("wait blocked " ++ facts)
      throwRuntimeError (RuntimeWaitBlocked facts)
