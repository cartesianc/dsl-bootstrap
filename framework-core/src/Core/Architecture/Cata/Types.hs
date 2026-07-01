module Core.Architecture.Cata.Types
  ( WorkflowAlgebra (..)
  ) where

import Core.Architecture
  ( Chain
  , Choice
  , ChoiceKey
  , Fact
  , Fallback
  , Parallel
  , Race
  , Wait
  , WorkflowName
  )

data WorkflowAlgebra fact result = WorkflowAlgebra
  { onFact :: Fact fact -> result
  , onChain :: WorkflowName -> Chain result -> result
  , onParallel :: WorkflowName -> Parallel result -> result
  , onFallback :: Fallback result -> result
  , onRace :: Race result -> result
  , onChoice :: ChoiceKey -> Choice result -> result
  , onWait :: Wait fact -> result -> result
  }
