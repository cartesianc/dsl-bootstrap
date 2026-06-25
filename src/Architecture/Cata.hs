module Architecture.Cata
  ( WorkflowAlgebra (..)
  , cataWorkflow
  ) where

import Architecture
import Architecture.Internal
  ( fmapFreeAlternative
  , fmapFreeApplicative
  , fmapFreeChoice
  , fmapFreeMonad
  )

data WorkflowAlgebra fact hook result = WorkflowAlgebra
  { onEffect :: Effect fact -> result
  , onChain :: WorkflowName -> Chain result -> result
  , onParallel :: WorkflowName -> Parallel result -> result
  , onFallback :: Fallback result -> result
  , onRace :: Race result -> result
  , onChoice :: ChoiceKey -> Choice result -> result
  , onCallback :: Callback fact -> result -> result
  , onMiddleware :: Middleware hook -> result -> result
  }

cataWorkflow ::
  WorkflowAlgebra fact hook result ->
  Workflow fact hook ->
  result
cataWorkflow algebra (EffectWorkflow currentEffect) =
  onEffect algebra currentEffect
cataWorkflow algebra (ChainWorkflow label steps) =
  onChain algebra label (mapChain (cataWorkflow algebra) steps)
cataWorkflow algebra (ParallelWorkflow label branches) =
  onParallel algebra label (mapParallel (cataWorkflow algebra) branches)
cataWorkflow algebra (FallbackWorkflow branches) =
  onFallback algebra (mapFallback (cataWorkflow algebra) branches)
cataWorkflow algebra (RaceWorkflow branches) =
  onRace algebra (mapRace (cataWorkflow algebra) branches)
cataWorkflow algebra (ChoiceWorkflow selectedKey branches) =
  onChoice algebra selectedKey (mapChoice (cataWorkflow algebra) branches)
cataWorkflow algebra (CallbackWorkflow facts body) =
  onCallback algebra facts (cataWorkflow algebra body)
cataWorkflow algebra (MiddlewareWorkflow currentMiddleware body) =
  onMiddleware algebra currentMiddleware (cataWorkflow algebra body)

mapChain :: (step -> nextStep) -> Chain step -> Chain nextStep
mapChain transform steps =
  Chain (fmapFreeMonad transform (chainSteps steps))

mapParallel :: (branch -> nextBranch) -> Parallel branch -> Parallel nextBranch
mapParallel transform branches =
  Parallel (fmapFreeApplicative transform (parallelBranches branches))

mapFallback :: (branch -> nextBranch) -> Fallback branch -> Fallback nextBranch
mapFallback transform branches =
  Fallback (fmapFreeAlternative transform (fallbackBranches branches))

mapRace :: (branch -> nextBranch) -> Race branch -> Race nextBranch
mapRace transform branches =
  Race (fmapFreeAlternative transform (raceBranches branches))

mapChoice :: (branch -> nextBranch) -> Choice branch -> Choice nextBranch
mapChoice transform branches =
  Choice (fmapFreeChoice transform (choiceBranches branches))
