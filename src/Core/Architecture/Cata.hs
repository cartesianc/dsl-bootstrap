module Core.Architecture.Cata
  ( WorkflowAlgebra (..)
  , cataWorkflow
  , cataHanging
  ) where

import Core.Architecture
import Core.Architecture.Internal
  ( fmapFreeAlternative
  , fmapFreeApplicative
  , fmapFreeChoice
  , fmapFreeMonad
  , fmapFreeMonoid
  )

data WorkflowAlgebra fact hook result = WorkflowAlgebra
  { onFact :: Fact fact -> result
  , onChain :: WorkflowName -> Chain result -> result
  , onParallel :: WorkflowName -> Parallel result -> result
  , onFallback :: Fallback result -> result
  , onRace :: Race result -> result
  , onChoice :: ChoiceKey -> Choice result -> result
  , onWait :: Wait fact -> result -> result
  , onMiddleware :: Middleware hook -> result -> result
  }

cataWorkflow ::
  WorkflowAlgebra fact hook result ->
  Workflow fact hook ->
  result
cataWorkflow algebra (FactWorkflow currentFact) =
  onFact algebra currentFact
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
cataWorkflow algebra (WaitWorkflow facts body) =
  onWait algebra facts (cataWorkflow algebra body)
cataWorkflow algebra (MiddlewareWorkflow currentMiddleware body) =
  onMiddleware algebra currentMiddleware (cataWorkflow algebra body)

cataHanging ::
  WorkflowAlgebra fact hook result ->
  Hanging (HangingAction fact (Workflow fact hook)) ->
  Hanging (HangingAction fact result)
cataHanging algebra =
  mapHanging (cataWorkflow algebra)

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

mapHanging ::
  (workflow -> nextWorkflow) ->
  Hanging (HangingAction fact workflow) ->
  Hanging (HangingAction fact nextWorkflow)
mapHanging transform actions =
  Hanging (fmapFreeMonoid (mapHangingAction transform) (hangingActions actions))

mapHangingAction ::
  (workflow -> nextWorkflow) ->
  HangingAction fact workflow ->
  HangingAction fact nextWorkflow
mapHangingAction transform (HangingCallback currentCallback) =
  HangingCallback (mapCallback transform currentCallback)
mapHangingAction transform (HangingSuspense currentSuspense) =
  HangingSuspense (mapSuspense transform currentSuspense)

mapCallback ::
  (workflow -> nextWorkflow) ->
  Callback fact workflow ->
  Callback fact nextWorkflow
mapCallback transform currentCallback =
  Callback
    { callbackFacts = callbackFacts currentCallback
    , callbackBody = transform (callbackBody currentCallback)
    }

mapSuspense ::
  (workflow -> nextWorkflow) ->
  Suspense fact workflow ->
  Suspense fact nextWorkflow
mapSuspense transform currentSuspense =
  Suspense
    { suspenseFacts = suspenseFacts currentSuspense
    , suspenseTarget = transform (suspenseTarget currentSuspense)
    }
