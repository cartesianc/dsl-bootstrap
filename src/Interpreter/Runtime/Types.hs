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
import Core.Architecture.Cata
  ( WorkflowAlgebra
  )
import Effects.EffectTheory
  ( EffectTheory
  )

data Runtime = Runtime
  { availableFacts :: [WorkflowFact]
  }

type Registry = [WorkflowFact]

type WorkflowProgram = Runtime -> IO Runtime

type RuntimeFAlgebra = WorkflowAlgebra WorkflowFact WorkflowProgram

type RuntimeRecursionModel = RuntimeFAlgebra -> AppBlueprint -> IO ()

type RuntimeContextware = EffectTheory -> RuntimeFAlgebra -> RuntimeFAlgebra

emptyRuntime :: Runtime
emptyRuntime =
  Runtime
    { availableFacts = []
    }
