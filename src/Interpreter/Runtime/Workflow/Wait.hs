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
import Interpreter.Runtime.Trace
  ( renderFactExpr
  , traceRuntime
  )
import Interpreter.Runtime.Types
  ( WorkflowProgram
  )

waitForFacts :: Wait WorkflowFact -> WorkflowProgram -> WorkflowProgram
waitForFacts currentWait body runtime
  | factExprAvailable runtime (waitFacts currentWait) = do
      traceRuntime ("wait ok " ++ renderFactExpr (waitFacts currentWait))
      body runtime
  | otherwise = do
      traceRuntime ("wait blocked " ++ renderFactExpr (waitFacts currentWait))
      ioError (userError "Wait workflow is missing required facts")
