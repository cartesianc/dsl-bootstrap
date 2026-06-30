module Core.Workflow.Semantics
  ( HangingProgram (..)
  , HangingProgramAction (..)
  , WorkflowProgram (..)
  , interpretHangingProgram
  , interpretWorkflowProgram
  , lowerHanging
  , lowerWorkflow
  ) where

import Core.Architecture
import Core.Architecture.Cata.Types
  ( WorkflowAlgebra (..)
  )

data WorkflowProgram fact
  = ProgramFact (Fact fact)
  | ProgramChain WorkflowName (Chain (WorkflowProgram fact))
  | ProgramParallel WorkflowName (Parallel (WorkflowProgram fact))
  | ProgramFallback (Fallback (WorkflowProgram fact))
  | ProgramRace (Race (WorkflowProgram fact))
  | ProgramChoice ChoiceKey (Choice (WorkflowProgram fact))
  | ProgramWait (Wait fact) (WorkflowProgram fact)

newtype HangingProgram fact hook = HangingProgram
  { hangingProgramActions :: Hanging (HangingProgramAction fact hook)
  }

data HangingProgramAction fact hook
  = ProgramCallback (Callback fact (WorkflowProgram fact))
  | ProgramSuspense (Suspense fact (WorkflowProgram fact))
  | ProgramLoop (Loop (WorkflowProgram fact))
  | ProgramMiddleware (Middleware hook) (WorkflowProgram fact)

lowerWorkflow :: Workflow fact hook -> WorkflowProgram fact
lowerWorkflow currentWorkflow =
  case currentWorkflow of
    FactWorkflow currentFact ->
      ProgramFact currentFact
    ChainWorkflow label steps ->
      ProgramChain label (mapChain lowerWorkflow steps)
    ParallelWorkflow label branches ->
      ProgramParallel label (mapParallel lowerWorkflow branches)
    FallbackWorkflow branches ->
      ProgramFallback (mapFallback lowerWorkflow branches)
    RaceWorkflow branches ->
      ProgramRace (mapRace lowerWorkflow branches)
    ChoiceWorkflow selectedKey branches ->
      ProgramChoice selectedKey (mapChoice lowerWorkflow branches)
    WaitWorkflow facts body ->
      ProgramWait facts (lowerWorkflow body)

lowerHanging ::
  Hanging (HangingAction fact hook (Workflow fact hook)) ->
  HangingProgram fact hook
lowerHanging =
  HangingProgram . mapHangingProgram lowerHangingAction

lowerHangingAction ::
  HangingAction fact hook (Workflow fact hook) ->
  HangingProgramAction fact hook
lowerHangingAction currentAction =
  case currentAction of
    HangingCallback currentCallback ->
      ProgramCallback (mapCallback lowerWorkflow currentCallback)
    HangingSuspense currentSuspense ->
      ProgramSuspense (mapSuspense lowerWorkflow currentSuspense)
    HangingLoop currentLoop ->
      ProgramLoop (mapLoop lowerWorkflow currentLoop)
    HangingMiddleware currentMiddleware body ->
      ProgramMiddleware currentMiddleware (lowerWorkflow body)

interpretWorkflowProgram ::
  WorkflowAlgebra fact result ->
  WorkflowProgram fact ->
  result
interpretWorkflowProgram algebra currentProgram =
  case currentProgram of
    ProgramFact currentFact ->
      onFact algebra currentFact
    ProgramChain label steps ->
      onChain algebra label (mapChain (interpretWorkflowProgram algebra) steps)
    ProgramParallel label branches ->
      onParallel algebra label (mapParallel (interpretWorkflowProgram algebra) branches)
    ProgramFallback branches ->
      onFallback algebra (mapFallback (interpretWorkflowProgram algebra) branches)
    ProgramRace branches ->
      onRace algebra (mapRace (interpretWorkflowProgram algebra) branches)
    ProgramChoice selectedKey branches ->
      onChoice algebra selectedKey (mapChoice (interpretWorkflowProgram algebra) branches)
    ProgramWait facts body ->
      onWait algebra facts (interpretWorkflowProgram algebra body)

interpretHangingProgram ::
  WorkflowAlgebra fact result ->
  HangingProgram fact hook ->
  Hanging (HangingAction fact hook result)
interpretHangingProgram algebra =
  mapHangingProgram (interpretHangingActionProgram algebra) . hangingProgramActions

interpretHangingActionProgram ::
  WorkflowAlgebra fact result ->
  HangingProgramAction fact hook ->
  HangingAction fact hook result
interpretHangingActionProgram algebra currentAction =
  case currentAction of
    ProgramCallback currentCallback ->
      HangingCallback (mapCallback (interpretWorkflowProgram algebra) currentCallback)
    ProgramSuspense currentSuspense ->
      HangingSuspense (mapSuspense (interpretWorkflowProgram algebra) currentSuspense)
    ProgramLoop currentLoop ->
      HangingLoop (mapLoop (interpretWorkflowProgram algebra) currentLoop)
    ProgramMiddleware currentMiddleware body ->
      HangingMiddleware currentMiddleware (interpretWorkflowProgram algebra body)

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

mapHangingProgram :: (action -> nextAction) -> Hanging action -> Hanging nextAction
mapHangingProgram transform actions =
  Hanging (fmap transform (hangingActions actions))

mapCallback ::
  (workflow -> nextWorkflow) ->
  Callback fact workflow ->
  Callback fact nextWorkflow
mapCallback transform currentCallback =
  Callback
    { callbackTarget = callbackTarget currentCallback
    , callbackBody = transform (callbackBody currentCallback)
    }

mapSuspense ::
  (workflow -> nextWorkflow) ->
  Suspense fact workflow ->
  Suspense fact nextWorkflow
mapSuspense _ currentSuspense =
  Suspense
    { suspenseTarget = suspenseTarget currentSuspense
    }

mapLoop ::
  (workflow -> nextWorkflow) ->
  Loop workflow ->
  Loop nextWorkflow
mapLoop transform currentLoop =
  Loop
    { loopBody = transform (loopBody currentLoop)
    }
