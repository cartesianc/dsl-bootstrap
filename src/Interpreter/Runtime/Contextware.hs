module Interpreter.Runtime.Contextware
  ( contextware
  ) where

import Core.Effect.Semantics
  ( effectSemantics
  )
import Core.Workflow.Eff
  ( WorkflowEffAlgebra (..)
  )
import Interpreter.Runtime.Ensure
  ( ensureFact
  )
import Interpreter.Runtime.Types
  ( RuntimeContextware
  )

contextware :: RuntimeContextware
contextware effects algebra =
  algebra
    { onProduceEff =
        ensureFact (effectSemantics effects) (onProduceEff algebra)
    }
