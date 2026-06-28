module Interpreter.View.Workflow.FreeApplicative
  ( freeApplicativeParallel
  ) where

import Core.Architecture
  ( Parallel (..)
  , WorkflowName
  )
import Core.Architecture.Internal
  ( FreeApplicative (..)
  )
import Interpreter.View.Program
  ( Program
  , childIndent
  , printNode
  , renderWorkflowName
  , runChildren
  )

freeApplicativeParallel :: WorkflowName -> Parallel Program -> Program
freeApplicativeParallel label branches indent = do
  printNode indent ("parallel " ++ renderWorkflowName label)
  runChildren (childIndent indent) (freeApplicativeBranches (parallelBranches branches))
