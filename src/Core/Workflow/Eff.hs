module Core.Workflow.Eff
  ( WorkflowEff (..)
  , WorkflowEffAlgebra (..)
  , WorkflowOp (..)
  , appendWorkflowEff
  , compileHangingEff
  , compileWorkflowEff
  , interpretHangingEff
  , interpretWorkflowEff
  ) where

import Core.Architecture

data WorkflowEff fact
  = WorkflowPure
  | WorkflowImpure (WorkflowOp fact (WorkflowEff fact))

data WorkflowOp fact next
  = ProduceFact (Fact fact) next
  | AwaitFacts (Wait fact) next
  | RunChain WorkflowName (Chain (WorkflowEff fact)) next
  | RunParallel WorkflowName (Parallel (WorkflowEff fact)) next
  | RunFallback (Fallback (WorkflowEff fact)) next
  | RunRace (Race (WorkflowEff fact)) next
  | RunChoice ChoiceKey (Choice (WorkflowEff fact)) next

instance Functor (WorkflowOp fact) where
  fmap transform operation =
    case operation of
      ProduceFact currentFact next ->
        ProduceFact currentFact (transform next)
      AwaitFacts currentWait next ->
        AwaitFacts currentWait (transform next)
      RunChain label steps next ->
        RunChain label steps (transform next)
      RunParallel label branches next ->
        RunParallel label branches (transform next)
      RunFallback branches next ->
        RunFallback branches (transform next)
      RunRace branches next ->
        RunRace branches (transform next)
      RunChoice selectedKey branches next ->
        RunChoice selectedKey branches (transform next)

data WorkflowEffAlgebra fact result = WorkflowEffAlgebra
  { onPureEff :: result
  , onThenEff :: result -> result -> result
  , onProduceEff :: Fact fact -> result
  , onAwaitEff :: Wait fact -> result -> result
  , onChainEff :: WorkflowName -> Chain result -> result
  , onParallelEff :: WorkflowName -> Parallel result -> result
  , onFallbackEff :: Fallback result -> result
  , onRaceEff :: Race result -> result
  , onChoiceEff :: ChoiceKey -> Choice result -> result
  }

appendWorkflowEff :: WorkflowEff fact -> WorkflowEff fact -> WorkflowEff fact
appendWorkflowEff left right =
  case left of
    WorkflowPure ->
      right
    WorkflowImpure operation ->
      WorkflowImpure (fmap (`appendWorkflowEff` right) operation)

compileWorkflowEff :: Workflow fact hook -> WorkflowEff fact
compileWorkflowEff currentWorkflow =
  case currentWorkflow of
    FactWorkflow currentFact ->
      WorkflowImpure (ProduceFact currentFact WorkflowPure)
    ChainWorkflow label steps ->
      WorkflowImpure (RunChain label (mapChain compileWorkflowEff steps) WorkflowPure)
    ParallelWorkflow label branches ->
      WorkflowImpure (RunParallel label (mapParallel compileWorkflowEff branches) WorkflowPure)
    FallbackWorkflow branches ->
      WorkflowImpure (RunFallback (mapFallback compileWorkflowEff branches) WorkflowPure)
    RaceWorkflow branches ->
      WorkflowImpure (RunRace (mapRace compileWorkflowEff branches) WorkflowPure)
    ChoiceWorkflow selectedKey branches ->
      WorkflowImpure (RunChoice selectedKey (mapChoice compileWorkflowEff branches) WorkflowPure)
    WaitWorkflow currentWait body ->
      WorkflowImpure (AwaitFacts currentWait (compileWorkflowEff body))

compileHangingEff ::
  Hanging (HangingAction fact hook (Workflow fact hook)) ->
  Hanging (HangingAction fact hook (WorkflowEff fact))
compileHangingEff =
  mapHanging compileHangingActionEff

compileHangingActionEff ::
  HangingAction fact hook (Workflow fact hook) ->
  HangingAction fact hook (WorkflowEff fact)
compileHangingActionEff currentAction =
  case currentAction of
    HangingCallback currentCallback ->
      HangingCallback (mapCallback compileWorkflowEff currentCallback)
    HangingSuspense currentSuspense ->
      HangingSuspense (mapSuspense compileWorkflowEff currentSuspense)
    HangingLoop currentLoop ->
      HangingLoop (mapLoop compileWorkflowEff currentLoop)
    HangingMiddleware currentMiddleware body ->
      HangingMiddleware currentMiddleware (compileWorkflowEff body)

interpretWorkflowEff ::
  WorkflowEffAlgebra fact result ->
  WorkflowEff fact ->
  result
interpretWorkflowEff algebra currentEff =
  case currentEff of
    WorkflowPure ->
      onPureEff algebra
    WorkflowImpure operation ->
      interpretWorkflowOp algebra operation

interpretWorkflowOp ::
  WorkflowEffAlgebra fact result ->
  WorkflowOp fact (WorkflowEff fact) ->
  result
interpretWorkflowOp algebra operation =
  case operation of
    ProduceFact currentFact next ->
      onThenEff algebra
        (onProduceEff algebra currentFact)
        (interpretWorkflowEff algebra next)
    AwaitFacts currentWait next ->
      onAwaitEff algebra currentWait (interpretWorkflowEff algebra next)
    RunChain label steps next ->
      onThenEff algebra
        (onChainEff algebra label (mapChain (interpretWorkflowEff algebra) steps))
        (interpretWorkflowEff algebra next)
    RunParallel label branches next ->
      onThenEff algebra
        (onParallelEff algebra label (mapParallel (interpretWorkflowEff algebra) branches))
        (interpretWorkflowEff algebra next)
    RunFallback branches next ->
      onThenEff algebra
        (onFallbackEff algebra (mapFallback (interpretWorkflowEff algebra) branches))
        (interpretWorkflowEff algebra next)
    RunRace branches next ->
      onThenEff algebra
        (onRaceEff algebra (mapRace (interpretWorkflowEff algebra) branches))
        (interpretWorkflowEff algebra next)
    RunChoice selectedKey branches next ->
      onThenEff algebra
        (onChoiceEff algebra selectedKey (mapChoice (interpretWorkflowEff algebra) branches))
        (interpretWorkflowEff algebra next)

interpretHangingEff ::
  WorkflowEffAlgebra fact result ->
  Hanging (HangingAction fact hook (WorkflowEff fact)) ->
  Hanging (HangingAction fact hook result)
interpretHangingEff algebra =
  mapHanging (interpretHangingActionEff algebra)

interpretHangingActionEff ::
  WorkflowEffAlgebra fact result ->
  HangingAction fact hook (WorkflowEff fact) ->
  HangingAction fact hook result
interpretHangingActionEff algebra currentAction =
  case currentAction of
    HangingCallback currentCallback ->
      HangingCallback (mapCallback (interpretWorkflowEff algebra) currentCallback)
    HangingSuspense currentSuspense ->
      HangingSuspense (mapSuspense (interpretWorkflowEff algebra) currentSuspense)
    HangingLoop currentLoop ->
      HangingLoop (mapLoop (interpretWorkflowEff algebra) currentLoop)
    HangingMiddleware currentMiddleware body ->
      HangingMiddleware currentMiddleware (interpretWorkflowEff algebra body)

mapChain :: (step -> nextStep) -> Chain step -> Chain nextStep
mapChain transform steps =
  Chain (fmap transform (chainSteps steps))

mapParallel :: (branch -> nextBranch) -> Parallel branch -> Parallel nextBranch
mapParallel transform branches =
  Parallel (fmap transform (parallelBranches branches))

mapFallback :: (branch -> nextBranch) -> Fallback branch -> Fallback nextBranch
mapFallback transform branches =
  Fallback (fmap transform (fallbackBranches branches))

mapRace :: (branch -> nextBranch) -> Race branch -> Race nextBranch
mapRace transform branches =
  Race (fmap transform (raceBranches branches))

mapChoice :: (branch -> nextBranch) -> Choice branch -> Choice nextBranch
mapChoice transform branches =
  Choice (fmap transform (choiceBranches branches))

mapHanging :: (action -> nextAction) -> Hanging action -> Hanging nextAction
mapHanging transform actions =
  Hanging (fmap transform (hangingActions actions))

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

mapLoop ::
  (workflow -> nextWorkflow) ->
  Loop workflow ->
  Loop nextWorkflow
mapLoop transform currentLoop =
  Loop
    { loopBody = transform (loopBody currentLoop)
    }
