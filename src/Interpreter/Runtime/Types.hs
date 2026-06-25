module Interpreter.Runtime.Types
  ( Registry
  , Runtime (..)
  , WorkflowProgram
  , emptyRuntime
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )

data Runtime = Runtime
  { availableFacts :: [WorkflowFact]
  }

type Registry = [WorkflowFact]

type WorkflowProgram = Runtime -> IO Runtime

emptyRuntime :: Runtime
emptyRuntime =
  Runtime
    { availableFacts = []
    }
