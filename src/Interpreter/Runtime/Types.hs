module Interpreter.Runtime.Types
  ( Registry
  , Runtime (..)
  , RuntimeContextware
  , RuntimeFAlgebra
  , RuntimeRecursionModel
  , WorkflowProgram
  , emptyRuntime
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )
import AST.AppBlueprint
  ( AppBlueprint
  )
import Core.Workflow.Eff
  ( WorkflowEffAlgebra
  )
import Effects.EffectTheory
  ( EffectTheory
  )

data Runtime = Runtime
  { availableFacts :: [WorkflowFact]
  }

type Registry = [WorkflowFact]

type WorkflowProgram = Runtime -> IO Runtime

type RuntimeFAlgebra = WorkflowEffAlgebra WorkflowFact WorkflowProgram

type RuntimeRecursionModel = RuntimeFAlgebra -> AppBlueprint -> IO ()

type RuntimeContextware = EffectTheory -> RuntimeFAlgebra -> RuntimeFAlgebra

emptyRuntime :: Runtime
emptyRuntime =
  Runtime
    { availableFacts = []
    }
