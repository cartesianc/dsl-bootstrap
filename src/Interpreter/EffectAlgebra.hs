module Interpreter.EffectAlgebra
  ( EffectAlgebra (..)
  , effectAlgebra
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Architecture
  ( Fact
  )
import Interpreter.View.Algebra
  ( Program
  , factProgram
  )

newtype EffectAlgebra fact result = EffectAlgebra
  { effectFact :: Fact fact -> result
  }

effectAlgebra :: EffectAlgebra WorkflowFact Program
effectAlgebra =
  EffectAlgebra
    { effectFact = factProgram
    }
