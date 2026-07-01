module Interpreter.WorkflowAlgebra
  ( WorkflowAlgebra (..)
  , workflowAlgebra
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Architecture
  ( Chain
  , Choice
  , ChoiceKey
  , Fallback
  , Parallel
  , Race
  , Wait
  , WorkflowName
  )
import Interpreter.View.Algebra
  ( Program
  )
import Interpreter.View.Workflow.Choice
  ( choiceByKey
  )
import Interpreter.View.Workflow.FreeAlternative
  ( freeAlternativeFallback
  , freeAlternativeRace
  )
import Interpreter.View.Workflow.FreeApplicative
  ( freeApplicativeParallel
  )
import Interpreter.View.Workflow.FreeMonad
  ( freeMonadChain
  )
import Interpreter.View.Workflow.Wait
  ( waitForFacts
  )

data WorkflowAlgebra fact result = WorkflowAlgebra
  { workflowChain :: WorkflowName -> Chain result -> result
  , workflowParallel :: WorkflowName -> Parallel result -> result
  , workflowFallback :: Fallback result -> result
  , workflowRace :: Race result -> result
  , workflowChoice :: ChoiceKey -> Choice result -> result
  , workflowWait :: Wait fact -> result -> result
  }

workflowAlgebra :: WorkflowAlgebra WorkflowFact Program
workflowAlgebra =
  WorkflowAlgebra
    { workflowChain = freeMonadChain
    , workflowParallel = freeApplicativeParallel
    , workflowFallback = freeAlternativeFallback
    , workflowRace = freeAlternativeRace
    , workflowChoice = choiceByKey
    , workflowWait = waitForFacts
    }
