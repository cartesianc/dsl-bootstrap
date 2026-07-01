module Interpreter.View.Workflow.FreeMonad
  ( freeMonadChain
  ) where

import Core.Architecture
  ( Chain (..)
  , WorkflowName
  )
import Core.Architecture.Internal
  ( FreeMonad (..)
  )
import Interpreter.View.Program
  ( Program
  , childIndent
  , printNode
  , renderWorkflowName
  , runChildren
  )

freeMonadChain :: WorkflowName -> Chain Program -> Program
freeMonadChain label steps indent = do
  printNode indent ("chain " ++ renderWorkflowName label)
  runChildren (childIndent indent) (freeMonadSteps (chainSteps steps))
