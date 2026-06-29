module Interpreter.Runtime.Algebra
  ( algebra
  , runtimeAlgebra
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Workflow.Eff
  ( WorkflowEffAlgebra (..)
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

runtimeAlgebra :: WorkflowEffAlgebra WorkflowFact WorkflowProgram
runtimeAlgebra =
  WorkflowEffAlgebra
    { onPureEff = pureProgram
    , onThenEff = thenProgram
    , onProduceEff = recordFact
    , onAwaitEff = waitForFacts
    , onChainEff = freeMonadChain
    , onParallelEff = freeApplicativeParallel
    , onFallbackEff = freeAlternativeFallback
    , onRaceEff = freeAlternativeRace
    , onChoiceEff = choiceByKey
    }

algebra :: WorkflowEffAlgebra WorkflowFact WorkflowProgram
algebra =
  runtimeAlgebra

thenProgram :: WorkflowProgram -> WorkflowProgram -> WorkflowProgram
thenProgram left right runtime = do
  nextRuntime <- left runtime
  right nextRuntime

pureProgram :: WorkflowProgram
pureProgram runtime =
  pure runtime
