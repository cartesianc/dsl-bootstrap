module Core.App.Ana
  ( AppMaterialized (..)
  , AppModel (..)
  , AppSeed (..)
  , AppFoldAlgebra
  , AppFoldAlgebraM
  , AppUnfoldAlgebra
  , AppUnfoldAlgebraM
  , EffectTheoryUnfoldAlgebra
  , EffectTheoryUnfoldAlgebraM
  , EffectSectionSeed (..)
  , EffectTheorySeed (..)
  , EffectUnitSeed (..)
  , FactExprSeed (..)
  , HangingCoalgebra
  , HangingCoalgebraM
  , HangingLayer (..)
  , HangingSeed (..)
  , ImplementationSeed (..)
  , ProducerStepSeed (..)
  , WorkflowCoalgebra
  , WorkflowCoalgebraM
  , WorkflowLayer (..)
  , WorkflowSeed (..)
  , anaAppBlueprint
  , anaAppBlueprintWith
  , anaAppBlueprintWithM
  , anaEffectTheory
  , anaHangingWith
  , anaHangingWithM
  , anaWorkflowWith
  , anaWorkflowWithM
  , hyloAppBlueprint
  , hyloAppModelM
  , hyloAppModel
  , hyloAppWith
  , hyloAppWithM
  , hyloEffectTheory
  , hangingSeedCoalgebra
  , materializeAppModel
  , workflowSeedCoalgebra
  ) where

import AST.AppBlueprint
  ( AppBlueprint (..)
  )
import AST.Interceptors
  ( Interceptor
  )
import AST.Vocabulary
  ( WorkflowFact
  , WorkflowName
  )
import Core.Architecture
  ( ChoiceKey
  , FactExpr
  , Hanging
  , HangingAction
  , Workflow
  )
import qualified Core.Architecture as Architecture
import Effects.EffectTheory
  ( EffectSection
  , EffectTheory
  , EffectUnit
  , ImplementationBinding
  , ProducerStep
  )
import qualified Effects.EffectTheory as EffectTheory
import Effects.Names
  ( EffectName
  , ImplementationName
  , ProfileName
  , SendName
  , TypeName
  )

data AppModel
  = CataModel AppBlueprint EffectTheory
  | HyloModel AppSeed EffectTheorySeed

data AppMaterialized = AppMaterialized
  { materializedBlueprint :: AppBlueprint
  , materializedEffects :: EffectTheory
  }

data AppSeed = AppSeed
  { appSeedWorkflow :: WorkflowSeed
  , appSeedHanging :: [HangingSeed]
  }

data WorkflowSeed
  = FactNode FactExprSeed
  | ChainNode WorkflowName [WorkflowSeed]
  | ParallelNode WorkflowName [WorkflowSeed]
  | FallbackNode [WorkflowSeed]
  | RaceNode [WorkflowSeed]
  | ChoiceNode ChoiceKey [(ChoiceKey, WorkflowSeed)]
  | WaitNode FactExprSeed WorkflowSeed

data WorkflowLayer seed
  = FactLayer FactExprSeed
  | ChainLayer WorkflowName [seed]
  | ParallelLayer WorkflowName [seed]
  | FallbackLayer [seed]
  | RaceLayer [seed]
  | ChoiceLayer ChoiceKey [(ChoiceKey, seed)]
  | WaitLayer FactExprSeed seed

data FactExprSeed
  = FactItemsSeed [WorkflowFact]
  | FactAllSeed [FactExprSeed]
  | FactAnySeed [FactExprSeed]

data HangingSeed
  = CallbackSeed WorkflowName WorkflowSeed
  | SuspenseSeed WorkflowName
  | LoopSeed WorkflowSeed
  | MiddlewareSeed Interceptor WorkflowSeed

data HangingLayer workflowSeed
  = CallbackLayer WorkflowName workflowSeed
  | SuspenseLayer WorkflowName
  | LoopLayer workflowSeed
  | MiddlewareLayer Interceptor workflowSeed

data EffectTheorySeed = EffectTheorySeed
  { effectTheorySeedUnits :: [EffectUnitSeed]
  }

data EffectUnitSeed = EffectUnitSeed
  { effectUnitSeedName :: EffectName
  , effectUnitSeedSections :: [EffectSectionSeed]
  }

data EffectSectionSeed
  = FactProducerSeed WorkflowFact [ProducerStepSeed]
  | ExternalMakeSeed SendName TypeName TypeName
  | ExternalTakeSeed WorkflowFact
  | ProfileSeed ProfileName [ImplementationSeed]

data ProducerStepSeed
  = NeedsSeed WorkflowFact
  | UsesSeed SendName
  | OnFailureSeed WorkflowFact

data ImplementationSeed = ImplementationSeed
  { implementationSeedSend :: SendName
  , implementationSeedName :: ImplementationName
  }

type WorkflowComponent = Workflow WorkflowFact Interceptor

type HangingComponent = HangingAction WorkflowFact Interceptor WorkflowComponent

type AppUnfoldAlgebra seed = seed -> AppBlueprint

type EffectTheoryUnfoldAlgebra seed = seed -> EffectTheory

type AppFoldAlgebra result = AppBlueprint -> EffectTheory -> result

type AppUnfoldAlgebraM effect seed = seed -> effect AppBlueprint

type EffectTheoryUnfoldAlgebraM effect seed = seed -> effect EffectTheory

type AppFoldAlgebraM effect result = AppBlueprint -> EffectTheory -> effect result

type WorkflowCoalgebra seed = seed -> WorkflowLayer seed

type WorkflowCoalgebraM effect seed = seed -> effect (WorkflowLayer seed)

type HangingCoalgebra hangingSeed workflowSeed = hangingSeed -> HangingLayer workflowSeed

type HangingCoalgebraM effect hangingSeed workflowSeed = hangingSeed -> effect (HangingLayer workflowSeed)

materializeAppModel :: AppModel -> AppMaterialized
materializeAppModel currentModel =
  hyloAppModel AppMaterialized currentModel

hyloAppModel :: AppFoldAlgebra result -> AppModel -> result
hyloAppModel interpret currentModel =
  case currentModel of
    CataModel currentBlueprint currentEffects ->
      interpret currentBlueprint currentEffects
    HyloModel currentAppSeed currentEffectSeed ->
      hyloAppWith anaAppBlueprint anaEffectTheory interpret currentAppSeed currentEffectSeed

hyloAppModelM :: Monad effect => AppFoldAlgebraM effect result -> AppModel -> effect result
hyloAppModelM interpret currentModel =
  case currentModel of
    CataModel currentBlueprint currentEffects ->
      interpret currentBlueprint currentEffects
    HyloModel currentAppSeed currentEffectSeed ->
      hyloAppWithM
        (pure . anaAppBlueprint)
        (pure . anaEffectTheory)
        interpret
        currentAppSeed
        currentEffectSeed

hyloAppWith ::
  AppUnfoldAlgebra appSeed ->
  EffectTheoryUnfoldAlgebra effectSeed ->
  AppFoldAlgebra result ->
  appSeed ->
  effectSeed ->
  result
hyloAppWith unfoldApp unfoldEffects foldApp currentAppSeed currentEffectSeed =
  foldApp (unfoldApp currentAppSeed) (unfoldEffects currentEffectSeed)

hyloAppWithM ::
  Monad effect =>
  AppUnfoldAlgebraM effect appSeed ->
  EffectTheoryUnfoldAlgebraM effect effectSeed ->
  AppFoldAlgebraM effect result ->
  appSeed ->
  effectSeed ->
  effect result
hyloAppWithM unfoldApp unfoldEffects foldApp currentAppSeed currentEffectSeed = do
  currentBlueprint <- unfoldApp currentAppSeed
  currentEffects <- unfoldEffects currentEffectSeed
  foldApp currentBlueprint currentEffects

hyloAppBlueprint :: (AppBlueprint -> result) -> AppSeed -> result
hyloAppBlueprint interpret =
  interpret . anaAppBlueprint

hyloEffectTheory :: (EffectTheory -> result) -> EffectTheorySeed -> result
hyloEffectTheory interpret =
  interpret . anaEffectTheory

anaAppBlueprint :: AppSeed -> AppBlueprint
anaAppBlueprint currentSeed =
  anaAppBlueprintWith
    workflowSeedCoalgebra
    hangingSeedCoalgebra
    (appSeedWorkflow currentSeed)
    (appSeedHanging currentSeed)

anaAppBlueprintWith ::
  WorkflowCoalgebra workflowSeed ->
  HangingCoalgebra hangingSeed workflowSeed ->
  workflowSeed ->
  [hangingSeed] ->
  AppBlueprint
anaAppBlueprintWith unfoldWorkflow unfoldHanging workflowSeed hangingSeeds =
  AppBlueprint
    { blueprintApp = anaWorkflowWith unfoldWorkflow workflowSeed
    , blueprintHanging = anaHangingWith unfoldWorkflow unfoldHanging hangingSeeds
    }

anaAppBlueprintWithM ::
  Monad effect =>
  WorkflowCoalgebraM effect workflowSeed ->
  HangingCoalgebraM effect hangingSeed workflowSeed ->
  workflowSeed ->
  [hangingSeed] ->
  effect AppBlueprint
anaAppBlueprintWithM unfoldWorkflow unfoldHanging workflowSeed hangingSeeds = do
  currentWorkflow <- anaWorkflowWithM unfoldWorkflow workflowSeed
  currentHanging <- anaHangingWithM unfoldWorkflow unfoldHanging hangingSeeds
  pure
    AppBlueprint
      { blueprintApp = currentWorkflow
      , blueprintHanging = currentHanging
      }

workflowSeedCoalgebra :: WorkflowSeed -> WorkflowLayer WorkflowSeed
workflowSeedCoalgebra currentSeed =
  case currentSeed of
    FactNode currentFacts ->
      FactLayer currentFacts
    ChainNode currentName steps ->
      ChainLayer currentName steps
    ParallelNode currentName branches ->
      ParallelLayer currentName branches
    FallbackNode branches ->
      FallbackLayer branches
    RaceNode branches ->
      RaceLayer branches
    ChoiceNode selectedKey branches ->
      ChoiceLayer selectedKey branches
    WaitNode currentFacts body ->
      WaitLayer currentFacts body

anaWorkflowWith :: WorkflowCoalgebra seed -> seed -> WorkflowComponent
anaWorkflowWith unfoldWorkflow currentSeed =
  case unfoldWorkflow currentSeed of
    FactLayer currentFacts ->
      Architecture.fact (anaFactExpr currentFacts)
    ChainLayer currentName steps ->
      Architecture.chain currentName (map (anaWorkflowWith unfoldWorkflow) steps)
    ParallelLayer currentName branches ->
      Architecture.parallel currentName (map (anaWorkflowWith unfoldWorkflow) branches)
    FallbackLayer branches ->
      Architecture.fallback (map (anaWorkflowWith unfoldWorkflow) branches)
    RaceLayer branches ->
      Architecture.race (map (anaWorkflowWith unfoldWorkflow) branches)
    ChoiceLayer selectedKey branches ->
      Architecture.choice selectedKey (map (anaChoiceBranchWith unfoldWorkflow) branches)
    WaitLayer currentFacts body ->
      Architecture.wait (anaFactExpr currentFacts) (anaWorkflowWith unfoldWorkflow body)

anaWorkflowWithM :: Monad effect => WorkflowCoalgebraM effect seed -> seed -> effect WorkflowComponent
anaWorkflowWithM unfoldWorkflow currentSeed = do
  currentLayer <- unfoldWorkflow currentSeed
  case currentLayer of
    FactLayer currentFacts ->
      pure (Architecture.fact (anaFactExpr currentFacts))
    ChainLayer currentName steps ->
      Architecture.chain currentName <$> mapM (anaWorkflowWithM unfoldWorkflow) steps
    ParallelLayer currentName branches ->
      Architecture.parallel currentName <$> mapM (anaWorkflowWithM unfoldWorkflow) branches
    FallbackLayer branches ->
      Architecture.fallback <$> mapM (anaWorkflowWithM unfoldWorkflow) branches
    RaceLayer branches ->
      Architecture.race <$> mapM (anaWorkflowWithM unfoldWorkflow) branches
    ChoiceLayer selectedKey branches ->
      Architecture.choice selectedKey <$> mapM (anaChoiceBranchWithM unfoldWorkflow) branches
    WaitLayer currentFacts body ->
      Architecture.wait (anaFactExpr currentFacts) <$> anaWorkflowWithM unfoldWorkflow body

anaChoiceBranchWith :: WorkflowCoalgebra seed -> (ChoiceKey, seed) -> (ChoiceKey, WorkflowComponent)
anaChoiceBranchWith unfoldWorkflow (currentKey, currentWorkflow) =
  (currentKey, anaWorkflowWith unfoldWorkflow currentWorkflow)

anaChoiceBranchWithM ::
  Monad effect =>
  WorkflowCoalgebraM effect seed ->
  (ChoiceKey, seed) ->
  effect (ChoiceKey, WorkflowComponent)
anaChoiceBranchWithM unfoldWorkflow (currentKey, currentWorkflow) = do
  nextWorkflow <- anaWorkflowWithM unfoldWorkflow currentWorkflow
  pure (currentKey, nextWorkflow)

anaFactExpr :: FactExprSeed -> FactExpr WorkflowFact
anaFactExpr currentSeed =
  case currentSeed of
    FactItemsSeed currentFacts ->
      Architecture.factItems currentFacts
    FactAllSeed currentFacts ->
      Architecture.factAll (map anaFactExpr currentFacts)
    FactAnySeed currentFacts ->
      Architecture.factAny (map anaFactExpr currentFacts)

hangingSeedCoalgebra :: HangingSeed -> HangingLayer WorkflowSeed
hangingSeedCoalgebra currentSeed =
  case currentSeed of
    CallbackSeed currentTarget body ->
      CallbackLayer currentTarget body
    SuspenseSeed currentTarget ->
      SuspenseLayer currentTarget
    LoopSeed body ->
      LoopLayer body
    MiddlewareSeed currentMiddleware body ->
      MiddlewareLayer currentMiddleware body

anaHangingWith ::
  WorkflowCoalgebra workflowSeed ->
  HangingCoalgebra hangingSeed workflowSeed ->
  [hangingSeed] ->
  Hanging HangingComponent
anaHangingWith unfoldWorkflow unfoldHanging =
  Architecture.hanging . map (anaHangingActionWith unfoldWorkflow unfoldHanging)

anaHangingWithM ::
  Monad effect =>
  WorkflowCoalgebraM effect workflowSeed ->
  HangingCoalgebraM effect hangingSeed workflowSeed ->
  [hangingSeed] ->
  effect (Hanging HangingComponent)
anaHangingWithM unfoldWorkflow unfoldHanging currentSeeds =
  Architecture.hanging <$> mapM (anaHangingActionWithM unfoldWorkflow unfoldHanging) currentSeeds

anaHangingActionWith ::
  WorkflowCoalgebra workflowSeed ->
  HangingCoalgebra hangingSeed workflowSeed ->
  hangingSeed ->
  HangingComponent
anaHangingActionWith unfoldWorkflow unfoldHanging currentSeed =
  case unfoldHanging currentSeed of
    CallbackLayer currentTarget body ->
      Architecture.callback currentTarget (anaWorkflowWith unfoldWorkflow body)
    SuspenseLayer currentTarget ->
      Architecture.suspense currentTarget
    LoopLayer body ->
      Architecture.loop (anaWorkflowWith unfoldWorkflow body)
    MiddlewareLayer currentMiddleware body ->
      Architecture.middleware currentMiddleware (anaWorkflowWith unfoldWorkflow body)

anaHangingActionWithM ::
  Monad effect =>
  WorkflowCoalgebraM effect workflowSeed ->
  HangingCoalgebraM effect hangingSeed workflowSeed ->
  hangingSeed ->
  effect HangingComponent
anaHangingActionWithM unfoldWorkflow unfoldHanging currentSeed = do
  currentLayer <- unfoldHanging currentSeed
  case currentLayer of
    CallbackLayer currentTarget body ->
      Architecture.callback currentTarget <$> anaWorkflowWithM unfoldWorkflow body
    SuspenseLayer currentTarget ->
      pure (Architecture.suspense currentTarget)
    LoopLayer body ->
      Architecture.loop <$> anaWorkflowWithM unfoldWorkflow body
    MiddlewareLayer currentMiddleware body ->
      Architecture.middleware currentMiddleware <$> anaWorkflowWithM unfoldWorkflow body

anaEffectTheory :: EffectTheorySeed -> EffectTheory
anaEffectTheory currentSeed =
  EffectTheory.theory (map anaEffectUnit (effectTheorySeedUnits currentSeed))

anaEffectUnit :: EffectUnitSeed -> EffectUnit
anaEffectUnit currentSeed =
  EffectTheory.effect
    (effectUnitSeedName currentSeed)
    (map anaEffectSection (effectUnitSeedSections currentSeed))

anaEffectSection :: EffectSectionSeed -> EffectSection
anaEffectSection currentSeed =
  case currentSeed of
    FactProducerSeed currentFact [] ->
      EffectTheory.fact currentFact
    FactProducerSeed currentFact steps ->
      EffectTheory.fact currentFact (map anaProducerStep steps)
    ExternalMakeSeed currentSend input output ->
      EffectTheory.externalMake currentSend input output
    ExternalTakeSeed currentFact ->
      EffectTheory.externalTake currentFact
    ProfileSeed currentProfile implementations ->
      EffectTheory.profile currentProfile (map anaImplementation implementations)

anaProducerStep :: ProducerStepSeed -> ProducerStep
anaProducerStep currentSeed =
  case currentSeed of
    NeedsSeed currentFact ->
      EffectTheory.needs currentFact
    UsesSeed currentSend ->
      EffectTheory.uses currentSend
    OnFailureSeed currentFact ->
      EffectTheory.onFailure currentFact

anaImplementation :: ImplementationSeed -> ImplementationBinding
anaImplementation currentSeed =
  EffectTheory.implement
    (implementationSeedSend currentSeed)
    (implementationSeedName currentSeed)
