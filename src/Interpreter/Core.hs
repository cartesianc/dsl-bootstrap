module Interpreter.Core
  ( interpret
  ) where

import Architecture
  ( Workflow
  )
import Architecture.Cata
  ( WorkflowAlgebra
  , cataWorkflow
  )

interpret :: WorkflowAlgebra fact hook result -> Workflow fact hook -> result
interpret =
  cataWorkflow
