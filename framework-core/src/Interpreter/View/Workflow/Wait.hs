module Interpreter.View.Workflow.Wait
  ( waitForFacts
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Architecture
  ( Wait (..)
  )
import Interpreter.View.Program
  ( Program
  , childIndent
  , printFactExpr
  , printNode
  )

waitForFacts :: Wait WorkflowFact -> Program -> Program
waitForFacts currentWait body indent = do
  printNode indent "wait"
  printFactExpr (childIndent indent) (waitFacts currentWait)
  printNode (childIndent indent) "continue"
  body (childIndent indent)
