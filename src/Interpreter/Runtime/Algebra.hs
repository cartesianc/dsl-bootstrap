module Interpreter.Runtime.Algebra
  ( algebra
  , runtimeAlgebra
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Architecture.Cata
  ( WorkflowAlgebra (..)
  )
import Interpreter.Runtime.Facts
  ( recordFact
  )
import Interpreter.Runtime.Types
  ( WorkflowProgram
  )
import Interpreter.Runtime.Workflow.Choice
  ( choiceByKey
  )
import Interpreter.Runtime.Workflow.FreeAlternative
  ( freeAlternativeFallback
  , freeAlternativeRace
  )
import Interpreter.Runtime.Workflow.FreeApplicative
  ( freeApplicativeParallel
  )
import Interpreter.Runtime.Workflow.FreeMonad
  ( freeMonadChain
  )
import Interpreter.Runtime.Workflow.Wait
  ( waitForFacts
  )

runtimeAlgebra :: WorkflowAlgebra WorkflowFact WorkflowProgram
runtimeAlgebra =
  WorkflowAlgebra
    { onFact = recordFact
    , onChain = freeMonadChain
    , onParallel = freeApplicativeParallel
    , onFallback = freeAlternativeFallback
    , onRace = freeAlternativeRace
    , onChoice = choiceByKey
    , onWait = waitForFacts
    }

algebra :: WorkflowAlgebra WorkflowFact WorkflowProgram
algebra =
  runtimeAlgebra
