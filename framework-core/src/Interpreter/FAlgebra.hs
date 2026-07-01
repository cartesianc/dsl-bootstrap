module Interpreter.FAlgebra
  ( FAlgebra
  , fAlgebra
  , fAlgebraFrom
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )
import qualified Core.Architecture.Cata as Cata
import Interpreter.EffectAlgebra
  ( EffectAlgebra (..)
  , effectAlgebra
  )
import Interpreter.View.Algebra
  ( Program
  )
import Interpreter.WorkflowAlgebra
  ( WorkflowAlgebra (..)
  , workflowAlgebra
  )

type FAlgebra = Cata.WorkflowAlgebra WorkflowFact Program

fAlgebra :: FAlgebra
fAlgebra =
  fAlgebraFrom workflowAlgebra effectAlgebra

fAlgebraFrom ::
  WorkflowAlgebra fact result ->
  EffectAlgebra fact result ->
  Cata.WorkflowAlgebra fact result
fAlgebraFrom workflow effect =
  Cata.WorkflowAlgebra
    (effectFact effect)
    (workflowChain workflow)
    (workflowParallel workflow)
    (workflowFallback workflow)
    (workflowRace workflow)
    (workflowChoice workflow)
    (workflowWait workflow)
