{-# LANGUAGE GADTs #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE TypeOperators #-}

module Framework.Runtime
  ( ErrorInputValue (..)
  , HandlerBinding (..)
  , HandlerInput (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , NoInputValue (..)
  , Runtime (..)
  , RuntimeCallback (..)
  , RuntimeCallbackEvent (..)
  , RuntimeComponentEvent (..)
  , RuntimeComponentStatus (..)
  , RuntimeEffectEnvironment (..)
  , RuntimeEnv (..)
  , RuntimeError (..)
  , RuntimeFactClaim (..)
  , RuntimeFactFailure (..)
  , RuntimeFactStatus (..)
  , RuntimeFailureDiagnosis (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisNodeKind (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeDiagnosisBlocker (..)
  , RuntimeHandler (..)
  , RuntimeM (..)
  , RuntimeMiddlewareEvent (..)
  , RuntimeResult (..)
  , RuntimeSnapshot (..)
  , RuntimeState
  , RuntimeSuspenseEvent (..)
  , RuntimeTransform (..)
  , RuntimeTypedValue (..)
  , RuntimeValue (..)
  , SomeRuntimeValue (..)
  , TransformBinding (..)
  , TransformRegistry (..)
  , UnitValue (..)
  , ValueTag (..)
  , applyRuntimeTransform
  , buildFailureDiagnosis
  , completeDiagnosisProbe
  , defaultRuntimeEnv
  , diagnosisProbePairs
  , emptyHandlerRegistry
  , emptyRuntime
  , emptyTransformRegistry
  , getRuntimeState
  , handlerFor
  , handlerInputFromTypedValues
  , handlerInputFromValues
  , liftRuntimeIO
  , modifyRuntimeState
  , putRuntimeState
  , renderRuntimeError
  , renderRuntimeFailureDiagnosis
  , renderRuntimeSnapshot
  , recordRuntimeDiagnosis
  , runBlueprintWithEffectEnvironment
  , runBlueprintWithEffectEnvironmentResult
  , runBlueprintWithEffectEnvironmentRuntimeResult
  , runRuntimeM
  , runRuntimeMOrThrow
  , runtimeEffectEnvironment
  , runtimeEffectEnvironmentWithTransforms
  , runtimeEnv
  , runtimeSnapshot
  , runtimeTransformInput
  , runtimeTransformOutput
  , runtimeTypedValueText
  , runtimeTypedValueToRuntimeValue
  , runtimeTypedValueType
  , runtimeValueToSome
  , sameValueTag
  , someRuntimeValueText
  , someRuntimeValueToRuntimeValue
  , someRuntimeValueType
  , throwRuntimeError
  , traceRuntimeM
  , transformFor
  , typedValueFor
  , typedValueFromSome
  , valueTagTypeName
  , withRuntimeCallbacks
  , withRuntimeEnv
  , withRuntimeMiddleware
  ) where

import Control.Concurrent
  ( MVar
  , ThreadId
  , forkIO
  , killThread
  , newEmptyMVar
  , putMVar
  , takeMVar
  )
import Control.Exception
  ( SomeException
  , try
  )
import Data.Type.Equality
  ( (:~:) (Refl) )
import Data.Typeable
  ( Typeable
  , eqT
  )

import Bootstrap.Effect
  ( EffectTheory
  , HandlerName
  , IdempotencyPolicy (..)
  , RetryPolicy (..)
  , SendName
  , SendSignature (..)
  , TransformName
  , TypeName (..)
  , pattern ErrorInput
  , pattern NoInput
  , pattern Unit
  )
import Bootstrap.Runtime
  ( NativeAppPlan (..)
  , NativeFactRule (..)
  , SendContract (..)
  , buildNativeApp
  )
import qualified Bootstrap.Runtime as Native
import Bootstrap.Workflow
  ( AppBlueprint (..)
  , Callback (..)
  , ChoiceKey (..)
  , Fact (..)
  , FactExpr (..)
  , HangingAction (..)
  , Interceptor
  , Loop (..)
  , Middleware (..)
  , Suspense (..)
  , Workflow (..)
  , WorkflowFact
  , WorkflowName
  , chainItems
  , choiceItems
  , fallbackItems
  , hangingItems
  , parallelItems
  , raceItems
  , requirementItems
  )
import qualified Bootstrap.Workflow as Workflow

data Runtime = Runtime
  { availableFacts :: [WorkflowFact]
  , availablePipeTypes :: [TypeName]
  , runtimeValues :: [RuntimeValue]
  , runtimeTypedValues :: [SomeRuntimeValue]
  , runtimeFactClaims :: [RuntimeFactClaim]
  , runtimeTrace :: [String]
  , runtimeActiveComponents :: [WorkflowName]
  , runtimeCompletedComponents :: [WorkflowName]
  , runtimeComponentEvents :: [RuntimeComponentEvent]
  , runtimeCallbackEvents :: [RuntimeCallbackEvent]
  , runtimeSuspenseEvents :: [RuntimeSuspenseEvent]
  , runtimeMiddlewareStack :: [Interceptor]
  , runtimeMiddlewareEvents :: [RuntimeMiddlewareEvent]
  , runtimeFailureDiagnoses :: [RuntimeFailureDiagnosis]
  }
  deriving (Eq, Show)

type RuntimeState = Runtime

data RuntimeSnapshot = RuntimeSnapshot
  { snapshotAvailableFacts :: [WorkflowFact]
  , snapshotAvailablePipeTypes :: [TypeName]
  , snapshotRuntimeValues :: [RuntimeValue]
  , snapshotRuntimeTypedValues :: [SomeRuntimeValue]
  , snapshotRuntimeFactClaims :: [RuntimeFactClaim]
  , snapshotRuntimeActiveComponents :: [WorkflowName]
  , snapshotRuntimeCompletedComponents :: [WorkflowName]
  , snapshotRuntimeTrace :: [String]
  }
  deriving (Eq, Show)

data RuntimeComponentStatus
  = RuntimeComponentNotStarted
  | RuntimeComponentRunning
  | RuntimeComponentCompleted
  deriving (Eq, Show)

data RuntimeFactStatus
  = RuntimeFactPending
  | RuntimeFactRunning
  | RuntimeFactSucceeded
  | RuntimeFactFailed
  deriving (Eq, Show)

data RuntimeFactClaim = RuntimeFactClaim
  { runtimeFactClaimFact :: WorkflowFact
  , runtimeFactClaimStatus :: RuntimeFactStatus
  , runtimeFactClaimFailure :: Maybe RuntimeFactFailure
  }
  deriving (Eq, Show)

data RuntimeFactFailure
  = RuntimeDependencyFailed WorkflowFact
  | RuntimePipeDependencyFailed WorkflowFact TypeName
  | RuntimeExternalMakeFailed SendName String
  | RuntimeErrorHandlerFailed SendName String
  | RuntimeLocalFactFailed String
  deriving (Eq, Show)

data RuntimeFailureDiagnosis = RuntimeFailureDiagnosis
  { diagnosisRootFact :: WorkflowFact
  , diagnosisRootSend :: Maybe SendName
  , diagnosisRootError :: String
  , diagnosisNodes :: [RuntimeDiagnosisNode]
  , diagnosisProbes :: [RuntimeDiagnosisProbe]
  , diagnosisSuspects :: [WorkflowFact]
  , diagnosisPollutedFacts :: [WorkflowFact]
  }
  deriving (Eq, Show)

data RuntimeDiagnosisNode = RuntimeDiagnosisNode
  { diagnosisNodeFact :: WorkflowFact
  , diagnosisNodeKind :: RuntimeDiagnosisNodeKind
  , diagnosisNodeStatus :: Maybe RuntimeFactStatus
  , diagnosisNodeExternalMakes :: [SendName]
  , diagnosisNodeIdempotentSends :: [SendName]
  , diagnosisNodeNonIdempotentSends :: [SendName]
  , diagnosisNodeBlockers :: [RuntimeDiagnosisBlocker]
  }
  deriving (Eq, Show)

data RuntimeDiagnosisNodeKind
  = DiagnosisRoot
  | DiagnosisNeedsUpstream WorkflowFact
  | DiagnosisPipeUpstream WorkflowFact TypeName
  deriving (Eq, Show)

data RuntimeDiagnosisProbe = RuntimeDiagnosisProbe
  { diagnosisProbeFact :: WorkflowFact
  , diagnosisProbeSend :: SendName
  , diagnosisProbeStatus :: RuntimeDiagnosisProbeStatus
  }
  deriving (Eq, Show)

data RuntimeDiagnosisProbeStatus
  = DiagnosisProbePending
  | DiagnosisProbePassed
  | DiagnosisProbeFailed String
  deriving (Eq, Show)

data RuntimeDiagnosisBlocker
  = DiagnosisMissingRule
  | DiagnosisExternalTakeSource
  | DiagnosisNonIdempotentSend SendName
  deriving (Eq, Show)

data RuntimeComponentEvent
  = RuntimeComponentEntered WorkflowName
  | RuntimeComponentExited WorkflowName
  deriving (Eq, Show)

data RuntimeCallbackEvent
  = RuntimeCallbackTriggered WorkflowName
  | RuntimeCallbackCompleted WorkflowName
  | RuntimeCallbackFailed WorkflowName
  deriving (Eq, Show)

data RuntimeSuspenseEvent
  = RuntimeSuspenseRequested WorkflowName RuntimeComponentStatus RuntimeSnapshot
  deriving (Eq, Show)

data RuntimeMiddlewareEvent
  = RuntimeMiddlewareEntered Interceptor
  | RuntimeMiddlewareExited Interceptor
  deriving (Eq, Show)

data RuntimeValue = RuntimeValue
  { runtimeValueType :: TypeName
  , runtimeValueText :: String
  }
  deriving (Eq, Show)

data NoInputValue = NoInputValue
  deriving (Eq, Show)

data UnitValue = UnitValue
  deriving (Eq, Show)

newtype ErrorInputValue = ErrorInputValue String
  deriving (Eq, Show)

data ValueTag value where
  ValueTag :: Typeable value => TypeName -> (value -> String) -> ValueTag value

data RuntimeTypedValue value = RuntimeTypedValue
  { runtimeTypedValueTag :: ValueTag value
  , runtimeTypedValuePayload :: value
  }

data SomeRuntimeValue where
  SomeRuntimeValue :: RuntimeTypedValue value -> SomeRuntimeValue

instance Eq SomeRuntimeValue where
  left == right =
    someRuntimeValueType left == someRuntimeValueType right
      && someRuntimeValueText left == someRuntimeValueText right

instance Show SomeRuntimeValue where
  show currentValue =
    "SomeRuntimeValue "
      ++ show (someRuntimeValueType currentValue)
      ++ " "
      ++ show (someRuntimeValueText currentValue)

data HandlerInput = HandlerInput
  { handlerInputValues :: [RuntimeValue]
  , handlerInputTypedValues :: [SomeRuntimeValue]
  }
  deriving (Eq, Show)

data HandlerResult
  = HandlerSucceeded [RuntimeValue]
  | HandlerSucceededTyped [SomeRuntimeValue]
  | HandlerFailed String
  deriving (Eq, Show)

newtype RuntimeHandler = RuntimeHandler
  { runRuntimeHandler :: SendName -> HandlerInput -> Runtime -> IO HandlerResult
  }

data HandlerBinding = HandlerBinding
  { handlerBindingSend :: SendName
  , handlerBindingName :: HandlerName
  , handlerBindingHandler :: RuntimeHandler
  }

newtype HandlerRegistry = HandlerRegistry
  { handlerRegistryBindings :: [HandlerBinding]
  }

data RuntimeTransform where
  RuntimeTransform :: ValueTag input -> ValueTag output -> (input -> output) -> RuntimeTransform

data TransformBinding = TransformBinding
  { transformBindingName :: TransformName
  , transformBindingTransform :: RuntimeTransform
  }

newtype TransformRegistry = TransformRegistry
  { transformRegistryBindings :: [TransformBinding]
  }

data RuntimeEffectEnvironment = RuntimeEffectEnvironment
  { runtimeEffectHandlers :: HandlerRegistry
  , runtimeEffectTransforms :: TransformRegistry
  }

data RuntimeEnv = RuntimeEnv
  { runtimeEnvEffectEnvironment :: RuntimeEffectEnvironment
  , runtimeEnvPlan :: NativeAppPlan
  , runtimeEnvCallbacks :: [RuntimeCallback]
  }

data RuntimeCallback = RuntimeCallback
  { runtimeCallbackTarget :: WorkflowName
  , runtimeCallbackBody :: Workflow WorkflowFact Interceptor
  }

data RuntimeError
  = RuntimeMissingFactRule WorkflowFact
  | RuntimeMissingSendBoundary SendName
  | RuntimeMissingHandler SendName
  | RuntimeMissingHandlerInput SendName TypeName
  | RuntimeHandlerOutputMismatch SendName TypeName [TypeName]
  | RuntimeHandlerFailed SendName String
  | RuntimeMissingTransform TransformName
  | RuntimeMissingTransformInput TransformName TypeName
  | RuntimeTransformInputMismatch TransformName TypeName TypeName
  | RuntimeTransformSignatureMismatch TransformName TypeName TypeName TypeName TypeName
  | RuntimeWaitBlocked String
  | RuntimeChoiceMissingBranch String
  | RuntimeParallelBranchFailed Int RuntimeError
  | RuntimeParallelMergeConflict String
  | RuntimeFallbackExhausted
  | RuntimeRaceEmpty
  | RuntimeRaceExhausted
  | RuntimeLoopExceeded Int
  | RuntimeIoException String
  deriving (Eq, Show)

data WorkflowBranchResult
  = WorkflowBranchSucceeded Int Runtime
  | WorkflowBranchFailed Int RuntimeError Runtime

data RuntimeTransformUse
  = RuntimeTransformUse TypeName TypeName TransformName RuntimeTransform

data RuntimeResult a
  = RuntimeSucceeded a RuntimeState
  | RuntimeFailed RuntimeError RuntimeState
  deriving (Eq, Show)

newtype RuntimeM a = RuntimeM
  { runRuntimeMInternal :: RuntimeEnv -> RuntimeState -> IO (RuntimeResult a)
  }

instance Functor RuntimeM where
  fmap transform program =
    RuntimeM $ \environment state -> do
      result <- runRuntimeMInternal program environment state
      case result of
        RuntimeSucceeded value nextState ->
          pure (RuntimeSucceeded (transform value) nextState)
        RuntimeFailed errorReport nextState ->
          pure (RuntimeFailed errorReport nextState)

instance Applicative RuntimeM where
  pure value =
    RuntimeM $ \_ state ->
      pure (RuntimeSucceeded value state)

  functionProgram <*> valueProgram =
    RuntimeM $ \environment state -> do
      functionResult <- runRuntimeMInternal functionProgram environment state
      case functionResult of
        RuntimeFailed errorReport nextState ->
          pure (RuntimeFailed errorReport nextState)
        RuntimeSucceeded transform nextState ->
          runRuntimeMInternal (fmap transform valueProgram) environment nextState

instance Monad RuntimeM where
  program >>= next =
    RuntimeM $ \environment state -> do
      result <- runRuntimeMInternal program environment state
      case result of
        RuntimeFailed errorReport nextState ->
          pure (RuntimeFailed errorReport nextState)
        RuntimeSucceeded value nextState ->
          runRuntimeMInternal (next value) environment nextState

emptyRuntime :: Runtime
emptyRuntime =
  Runtime
    { availableFacts = []
    , availablePipeTypes = []
    , runtimeValues = []
    , runtimeTypedValues = []
    , runtimeFactClaims = []
    , runtimeTrace = []
    , runtimeActiveComponents = []
    , runtimeCompletedComponents = []
    , runtimeComponentEvents = []
    , runtimeCallbackEvents = []
    , runtimeSuspenseEvents = []
    , runtimeMiddlewareStack = []
    , runtimeMiddlewareEvents = []
    , runtimeFailureDiagnoses = []
    }

runtimeSnapshot :: Runtime -> RuntimeSnapshot
runtimeSnapshot runtime =
  RuntimeSnapshot
    { snapshotAvailableFacts = availableFacts runtime
    , snapshotAvailablePipeTypes = availablePipeTypes runtime
    , snapshotRuntimeValues = runtimeValues runtime
    , snapshotRuntimeTypedValues = runtimeTypedValues runtime
    , snapshotRuntimeFactClaims = runtimeFactClaims runtime
    , snapshotRuntimeActiveComponents = runtimeActiveComponents runtime
    , snapshotRuntimeCompletedComponents = runtimeCompletedComponents runtime
    , snapshotRuntimeTrace = runtimeTrace runtime
    }

renderRuntimeSnapshot :: RuntimeSnapshot -> [String]
renderRuntimeSnapshot snapshot =
  [ "runtime snapshot"
  , "  facts: " ++ show (snapshotAvailableFacts snapshot)
  , "  pipe types: " ++ show (snapshotAvailablePipeTypes snapshot)
  , "  values: " ++ show (snapshotRuntimeValues snapshot)
  , "  typed values: " ++ show (snapshotRuntimeTypedValues snapshot)
  , "  fact claims: " ++ show (snapshotRuntimeFactClaims snapshot)
  , "  active components: " ++ show (snapshotRuntimeActiveComponents snapshot)
  , "  completed components: " ++ show (snapshotRuntimeCompletedComponents snapshot)
  , "  trace lines: " ++ show (length (snapshotRuntimeTrace snapshot))
  ]

emptyHandlerRegistry :: HandlerRegistry
emptyHandlerRegistry =
  HandlerRegistry []

emptyTransformRegistry :: TransformRegistry
emptyTransformRegistry =
  TransformRegistry []

runtimeEffectEnvironment :: HandlerRegistry -> RuntimeEffectEnvironment
runtimeEffectEnvironment handlers =
  RuntimeEffectEnvironment handlers emptyTransformRegistry

runtimeEffectEnvironmentWithTransforms :: HandlerRegistry -> TransformRegistry -> RuntimeEffectEnvironment
runtimeEffectEnvironmentWithTransforms =
  RuntimeEffectEnvironment

defaultRuntimeEnv :: RuntimeEnv
defaultRuntimeEnv =
  RuntimeEnv
    { runtimeEnvEffectEnvironment = runtimeEffectEnvironment emptyHandlerRegistry
    , runtimeEnvPlan =
        NativeAppPlan
          { nativeAppPlanFacts = []
          , nativeAppPlanRootFacts = []
          , nativeAppPlanSendBoundaries = []
          , nativeAppPlanSendContracts = []
          , nativeAppPlanFactRules = []
          , nativeAppPlanConstraints = []
          }
    , runtimeEnvCallbacks = []
    }

runtimeEnv :: RuntimeEffectEnvironment -> NativeAppPlan -> RuntimeEnv
runtimeEnv environment plan =
  RuntimeEnv
    { runtimeEnvEffectEnvironment = environment
    , runtimeEnvPlan = plan
    , runtimeEnvCallbacks = []
    }

runRuntimeM :: RuntimeEnv -> Runtime -> RuntimeM a -> IO (RuntimeResult a)
runRuntimeM environment runtime program =
  runRuntimeMInternal program environment runtime

runRuntimeMOrThrow :: RuntimeEnv -> Runtime -> RuntimeM a -> IO Runtime
runRuntimeMOrThrow environment runtime program = do
  result <- runRuntimeM environment runtime program
  case result of
    RuntimeSucceeded _ nextRuntime ->
      pure nextRuntime
    RuntimeFailed errorReport nextRuntime ->
      ioError (userError (renderRuntimeError errorReport ++ "\n" ++ unlines (runtimeTrace nextRuntime)))

runBlueprintWithEffectEnvironment :: RuntimeEffectEnvironment -> EffectTheory -> AppBlueprint -> IO ()
runBlueprintWithEffectEnvironment environment effects blueprint = do
  result <- runBlueprintWithEffectEnvironmentResult environment effects blueprint
  case result of
    Left errorReport ->
      ioError (userError (renderRuntimeError errorReport))
    Right runtime ->
      mapM_ putStrLn (runtimeTrace runtime)

runBlueprintWithEffectEnvironmentResult ::
  RuntimeEffectEnvironment ->
  EffectTheory ->
  AppBlueprint ->
  IO (Either RuntimeError Runtime)
runBlueprintWithEffectEnvironmentResult environment effects blueprint = do
  result <- runBlueprintWithEffectEnvironmentRuntimeResult environment effects blueprint
  pure
    ( case result of
        RuntimeFailed errorReport _ ->
          Left errorReport
        RuntimeSucceeded runtime _ ->
          Right runtime
    )

runBlueprintWithEffectEnvironmentRuntimeResult ::
  RuntimeEffectEnvironment ->
  EffectTheory ->
  AppBlueprint ->
  IO (RuntimeResult Runtime)
runBlueprintWithEffectEnvironmentRuntimeResult environment effects blueprint =
  case buildNativeApp blueprint effects of
    Left message ->
      pure (RuntimeFailed (RuntimeWaitBlocked message) emptyRuntime)
    Right plan ->
      if not (nativePlanPassed plan)
        then pure (RuntimeFailed (RuntimeWaitBlocked (renderNativePlanErrors plan)) emptyRuntime)
        else do
          let callbacks = runtimeCallbacksFromHanging (blueprintHanging blueprint)
              currentEnv =
                withRuntimeCallbacks callbacks (runtimeEnv environment plan)
          appResult <- runRuntimeM currentEnv emptyRuntime (runWorkflow (blueprintApp blueprint))
          case appResult of
            RuntimeFailed errorReport runtime ->
              pure (RuntimeFailed (traceFailure errorReport runtime) runtime)
            RuntimeSucceeded _ appRuntime -> do
              hangingResult <- runRuntimeM currentEnv appRuntime (runHanging (blueprintHanging blueprint))
              case hangingResult of
                RuntimeFailed errorReport runtime ->
                  pure (RuntimeFailed (traceFailure errorReport runtime) runtime)
                RuntimeSucceeded _ finalRuntime ->
                  pure (RuntimeSucceeded finalRuntime finalRuntime)

getRuntimeState :: RuntimeM RuntimeState
getRuntimeState =
  RuntimeM $ \_ state ->
    pure (RuntimeSucceeded state state)

putRuntimeState :: RuntimeState -> RuntimeM ()
putRuntimeState state =
  RuntimeM $ \_ _ ->
    pure (RuntimeSucceeded () state)

modifyRuntimeState :: (RuntimeState -> RuntimeState) -> RuntimeM ()
modifyRuntimeState transform =
  RuntimeM $ \_ state ->
    pure (RuntimeSucceeded () (transform state))

liftRuntimeIO :: IO a -> RuntimeM a
liftRuntimeIO action =
  RuntimeM $ \_ state -> do
    result <- try action
    case result of
      Right value ->
        pure (RuntimeSucceeded value state)
      Left exception ->
        pure (RuntimeFailed (RuntimeIoException (show (exception :: SomeException))) state)

throwRuntimeError :: RuntimeError -> RuntimeM a
throwRuntimeError errorReport =
  RuntimeM $ \_ state ->
    pure (RuntimeFailed errorReport state)

traceRuntimeM :: String -> RuntimeM ()
traceRuntimeM message =
  modifyRuntimeState
    ( \runtime ->
        runtime {runtimeTrace = runtimeTrace runtime ++ ["[runtime] " ++ message]}
    )

withRuntimeEnv :: RuntimeEnv -> RuntimeM a -> RuntimeM a
withRuntimeEnv environment program =
  RuntimeM $ \_ state ->
    runRuntimeMInternal program environment state

withRuntimeCallbacks :: [RuntimeCallback] -> RuntimeEnv -> RuntimeEnv
withRuntimeCallbacks callbacks environment =
  environment
    { runtimeEnvCallbacks = callbacks ++ runtimeEnvCallbacks environment
    }

withRuntimeMiddleware :: Interceptor -> RuntimeM a -> RuntimeM a
withRuntimeMiddleware currentMiddleware body =
  RuntimeM $ \environment state -> do
    result <- runRuntimeMInternal body environment (pushRuntimeMiddleware currentMiddleware state)
    pure (exitResult result)
  where
    exitResult result =
      case result of
        RuntimeSucceeded value nextState ->
          RuntimeSucceeded value (popRuntimeMiddleware currentMiddleware nextState)
        RuntimeFailed errorReport nextState ->
          RuntimeFailed errorReport (popRuntimeMiddleware currentMiddleware nextState)

runWorkflow :: Workflow WorkflowFact Interceptor -> RuntimeM ()
runWorkflow workflow =
  case workflow of
    FactWorkflow currentFact ->
      runFactExpr (factExpression currentFact)
    ChainWorkflow name steps ->
      runNamedWorkflow "chain" name (mapM_ runWorkflow (chainItems steps))
    ParallelWorkflow name branches ->
      runNamedWorkflow "parallel" name (runParallel (parallelItems branches))
    FallbackWorkflow branches ->
      runFallback (fallbackItems branches)
    RaceWorkflow branches ->
      runRace (raceItems branches)
    ChoiceWorkflow selectedKey branches ->
      runChoice selectedKey (choiceItems branches)
    WaitWorkflow wait body -> do
      runFactExpr (Workflow.waitFacts wait)
      runWorkflow body

runNamedWorkflow :: String -> WorkflowName -> RuntimeM () -> RuntimeM ()
runNamedWorkflow label name body = do
  enterComponent name
  traceRuntimeM (label ++ " " ++ show name)
  runWorkflowCallbacks name
  result <- catchRuntime body
  exitComponent name
  case result of
    Right _ ->
      pure ()
    Left errorReport ->
      throwRuntimeError errorReport

runWorkflowCallbacks :: WorkflowName -> RuntimeM ()
runWorkflowCallbacks name = do
  environment <- askRuntimeEnv
  let callbacks =
        [ callback
        | callback <- runtimeEnvCallbacks environment
        , runtimeCallbackTarget callback == name
        ]
  mapM_ runWorkflowCallback callbacks

runWorkflowCallback :: RuntimeCallback -> RuntimeM ()
runWorkflowCallback callback = do
  recordCallbackEvent (RuntimeCallbackTriggered (runtimeCallbackTarget callback))
  traceRuntimeM ("callback " ++ show (runtimeCallbackTarget callback) ++ " trigger")
  result <- catchRuntime (runWorkflow (runtimeCallbackBody callback))
  case result of
    Left _ -> do
      recordCallbackEvent (RuntimeCallbackFailed (runtimeCallbackTarget callback))
      traceRuntimeM ("callback " ++ show (runtimeCallbackTarget callback) ++ " failed")
    Right _ -> do
      recordCallbackEvent (RuntimeCallbackCompleted (runtimeCallbackTarget callback))
      traceRuntimeM ("callback " ++ show (runtimeCallbackTarget callback) ++ " completed")

runFallback :: [Workflow WorkflowFact Interceptor] -> RuntimeM ()
runFallback branches = do
  runtime <- getRuntimeState
  runFallbackFrom runtime branches

runFallbackFrom :: Runtime -> [Workflow WorkflowFact Interceptor] -> RuntimeM ()
runFallbackFrom runtime [] = do
  putRuntimeState runtime
  throwRuntimeError RuntimeFallbackExhausted
runFallbackFrom runtime (branch : rest) = do
  putRuntimeState runtime
  result <- catchRuntime (runWorkflow branch)
  case result of
    Right _ ->
      pure ()
    Left _ ->
      runFallbackFrom runtime rest

runRace :: [Workflow WorkflowFact Interceptor] -> RuntimeM ()
runRace [] =
  throwRuntimeError RuntimeRaceEmpty
runRace branches = do
  environment <- askRuntimeEnv
  runtime <- getRuntimeState
  result <- liftRuntimeIO (runRaceBranches environment runtime (zip [0 ..] branches))
  case result of
    Nothing -> do
      putRuntimeState runtime
      throwRuntimeError RuntimeRaceExhausted
    Just winnerRuntime ->
      putRuntimeState winnerRuntime

runChoice :: ChoiceKey -> [(ChoiceKey, Workflow WorkflowFact Interceptor)] -> RuntimeM ()
runChoice selectedKey branches =
  case firstJust (map selectedBranch branches) of
    Just branch ->
      runWorkflow branch
    Nothing ->
      throwRuntimeError (RuntimeChoiceMissingBranch ("missing choice branch " ++ choiceKeyText selectedKey))
  where
    selectedBranch (currentKey, branch)
      | currentKey == selectedKey =
          Just branch
      | otherwise =
          Nothing

runParallel :: [Workflow WorkflowFact Interceptor] -> RuntimeM ()
runParallel branches = do
  environment <- askRuntimeEnv
  runtime <- getRuntimeState
  results <- liftRuntimeIO (runParallelBranches environment runtime (zip [0 ..] branches))
  case firstBranchFailure results of
    Just (index, errorReport, failedRuntime) -> do
      putRuntimeState failedRuntime
      throwRuntimeError (RuntimeParallelBranchFailed index errorReport)
    Nothing ->
      case mergeParallelRuntimes runtime (branchSuccessRuntimesInOrder (length branches) results) of
        Left message ->
          throwRuntimeError (RuntimeParallelMergeConflict message)
        Right mergedRuntime ->
          putRuntimeState mergedRuntime

runFactExpr :: FactExpr WorkflowFact -> RuntimeM ()
runFactExpr expression =
  case expression of
    FactItems requirements ->
      mapM_ (ensureFact []) (requirementItems requirements)
    FactAll expressions ->
      mapM_ runFactExpr expressions
    FactAny [] ->
      throwRuntimeError (RuntimeWaitBlocked "empty anyOf")
    FactAny expressions -> do
      runtime <- getRuntimeState
      runFactAnyFrom runtime expressions

runFactAnyFrom :: Runtime -> [FactExpr WorkflowFact] -> RuntimeM ()
runFactAnyFrom runtime [] = do
  putRuntimeState runtime
  throwRuntimeError (RuntimeWaitBlocked "anyOf could not be satisfied")
runFactAnyFrom runtime (expression : rest) = do
  putRuntimeState runtime
  result <- catchRuntime (runFactExpr expression)
  case result of
    Right _ ->
      pure ()
    Left _ ->
      runFactAnyFrom runtime rest

runParallelBranches ::
  RuntimeEnv ->
  Runtime ->
  [(Int, Workflow WorkflowFact Interceptor)] ->
  IO [WorkflowBranchResult]
runParallelBranches environment runtime branches = do
  resultVars <- mapM (forkWorkflowBranch environment runtime) branches
  mapM takeMVar resultVars

runRaceBranches ::
  RuntimeEnv ->
  Runtime ->
  [(Int, Workflow WorkflowFact Interceptor)] ->
  IO (Maybe Runtime)
runRaceBranches environment runtime branches = do
  resultVar <- newEmptyMVar
  threadIds <- mapM (forkRaceWorkflowBranch environment runtime resultVar) branches
  waitForRaceWinner (length branches) 0 threadIds resultVar

forkWorkflowBranch ::
  RuntimeEnv ->
  Runtime ->
  (Int, Workflow WorkflowFact Interceptor) ->
  IO (MVar WorkflowBranchResult)
forkWorkflowBranch environment runtime branch = do
  resultVar <- newEmptyMVar
  _ <- forkWorkflowBranchInto environment runtime resultVar branch
  pure resultVar

forkRaceWorkflowBranch ::
  RuntimeEnv ->
  Runtime ->
  MVar WorkflowBranchResult ->
  (Int, Workflow WorkflowFact Interceptor) ->
  IO (Int, ThreadId)
forkRaceWorkflowBranch environment runtime resultVar branch@(index, _) = do
  threadId <- forkWorkflowBranchInto environment runtime resultVar branch
  pure (index, threadId)

forkWorkflowBranchInto ::
  RuntimeEnv ->
  Runtime ->
  MVar WorkflowBranchResult ->
  (Int, Workflow WorkflowFact Interceptor) ->
  IO ThreadId
forkWorkflowBranchInto environment runtime resultVar (index, branch) =
  forkIO $ do
    result <- tryRuntimeBranch (runRuntimeM environment runtime (runWorkflow branch))
    putMVar resultVar (branchResultFromRuntimeResult index runtime result)

tryRuntimeBranch :: IO (RuntimeResult ()) -> IO (Either SomeException (RuntimeResult ()))
tryRuntimeBranch =
  try

branchResultFromRuntimeResult ::
  Int ->
  Runtime ->
  Either SomeException (RuntimeResult ()) ->
  WorkflowBranchResult
branchResultFromRuntimeResult index runtime result =
  case result of
    Left exception ->
      WorkflowBranchFailed index (RuntimeIoException (show exception)) runtime
    Right (RuntimeSucceeded _ nextRuntime) ->
      WorkflowBranchSucceeded index nextRuntime
    Right (RuntimeFailed errorReport failedRuntime) ->
      WorkflowBranchFailed index errorReport failedRuntime

waitForRaceWinner ::
  Int ->
  Int ->
  [(Int, ThreadId)] ->
  MVar WorkflowBranchResult ->
  IO (Maybe Runtime)
waitForRaceWinner totalFailures failedCount threadIds resultVar = do
  result <- takeMVar resultVar
  case result of
    WorkflowBranchSucceeded winnerIndex winnerRuntime -> do
      killRaceLosers winnerIndex threadIds
      pure (Just winnerRuntime)
    WorkflowBranchFailed _ _ _ ->
      if failedCount + 1 >= totalFailures
        then pure Nothing
        else waitForRaceWinner totalFailures (failedCount + 1) threadIds resultVar

killRaceLosers :: Int -> [(Int, ThreadId)] -> IO ()
killRaceLosers winnerIndex threadIds =
  mapM_ killThread
    [ threadId
    | (index, threadId) <- threadIds
    , index /= winnerIndex
    ]

firstBranchFailure :: [WorkflowBranchResult] -> Maybe (Int, RuntimeError, Runtime)
firstBranchFailure results =
  firstJust
    [ branchFailureFor index results
    | index <- [0 .. length results - 1]
    ]

branchFailureFor :: Int -> [WorkflowBranchResult] -> Maybe (Int, RuntimeError, Runtime)
branchFailureFor _ [] =
  Nothing
branchFailureFor expectedIndex (result : rest) =
  case result of
    WorkflowBranchFailed index errorReport runtime
      | index == expectedIndex ->
          Just (index, errorReport, runtime)
    _ ->
      branchFailureFor expectedIndex rest

branchSuccessRuntimesInOrder :: Int -> [WorkflowBranchResult] -> [Runtime]
branchSuccessRuntimesInOrder branchCount results =
  [ runtime
  | index <- [0 .. branchCount - 1]
  , Just runtime <- [branchSuccessFor index results]
  ]

branchSuccessFor :: Int -> [WorkflowBranchResult] -> Maybe Runtime
branchSuccessFor _ [] =
  Nothing
branchSuccessFor expectedIndex (result : rest) =
  case result of
    WorkflowBranchSucceeded index runtime
      | index == expectedIndex ->
          Just runtime
    _ ->
      branchSuccessFor expectedIndex rest

mergeParallelRuntimes :: Runtime -> [Runtime] -> Either String Runtime
mergeParallelRuntimes baseRuntime =
  mergeParallelRuntimesFrom baseRuntime baseRuntime

mergeParallelRuntimesFrom :: Runtime -> Runtime -> [Runtime] -> Either String Runtime
mergeParallelRuntimesFrom _ mergedRuntime [] =
  Right mergedRuntime
mergeParallelRuntimesFrom baseRuntime mergedRuntime (branchRuntime : rest) =
  case mergeParallelRuntime baseRuntime mergedRuntime branchRuntime of
    Left message ->
      Left message
    Right nextRuntime ->
      mergeParallelRuntimesFrom baseRuntime nextRuntime rest

mergeParallelRuntime :: Runtime -> Runtime -> Runtime -> Either String Runtime
mergeParallelRuntime baseRuntime mergedRuntime branchRuntime
  | runtimeActiveComponents branchRuntime /= runtimeActiveComponents baseRuntime =
      Left "branch left active components behind"
  | runtimeMiddlewareStack branchRuntime /= runtimeMiddlewareStack baseRuntime =
      Left "branch left middleware stack behind"
  | otherwise = do
      mergedValues <- mergeRuntimeValuesChecked (runtimeValues mergedRuntime) (runtimeValues branchRuntime)
      mergedTypedValues <- mergeRuntimeTypedValuesChecked (runtimeTypedValues mergedRuntime) (runtimeTypedValues branchRuntime)
      mergedClaims <- mergeRuntimeFactClaimsChecked (runtimeFactClaims mergedRuntime) (runtimeFactClaims branchRuntime)
      pure
        mergedRuntime
          { availableFacts = unique (availableFacts mergedRuntime ++ availableFacts branchRuntime)
          , availablePipeTypes = unique (availablePipeTypes mergedRuntime ++ availablePipeTypes branchRuntime)
          , runtimeValues = mergedValues
          , runtimeTypedValues = mergedTypedValues
          , runtimeFactClaims = mergedClaims
          , runtimeTrace = runtimeTrace mergedRuntime ++ listDelta (runtimeTrace baseRuntime) (runtimeTrace branchRuntime)
          , runtimeCompletedComponents = unique (runtimeCompletedComponents mergedRuntime ++ runtimeCompletedComponents branchRuntime)
          , runtimeComponentEvents =
              runtimeComponentEvents mergedRuntime
                ++ listDelta (runtimeComponentEvents baseRuntime) (runtimeComponentEvents branchRuntime)
          , runtimeCallbackEvents =
              runtimeCallbackEvents mergedRuntime
                ++ listDelta (runtimeCallbackEvents baseRuntime) (runtimeCallbackEvents branchRuntime)
          , runtimeSuspenseEvents =
              runtimeSuspenseEvents mergedRuntime
                ++ listDelta (runtimeSuspenseEvents baseRuntime) (runtimeSuspenseEvents branchRuntime)
          , runtimeMiddlewareEvents =
              runtimeMiddlewareEvents mergedRuntime
                ++ listDelta (runtimeMiddlewareEvents baseRuntime) (runtimeMiddlewareEvents branchRuntime)
          , runtimeFailureDiagnoses =
              runtimeFailureDiagnoses mergedRuntime
                ++ listDelta (runtimeFailureDiagnoses baseRuntime) (runtimeFailureDiagnoses branchRuntime)
          }

mergeRuntimeValuesChecked :: [RuntimeValue] -> [RuntimeValue] -> Either String [RuntimeValue]
mergeRuntimeValuesChecked =
  foldlEither mergeRuntimeValueChecked

mergeRuntimeValueChecked :: [RuntimeValue] -> RuntimeValue -> Either String [RuntimeValue]
mergeRuntimeValueChecked [] currentValue =
  Right [currentValue]
mergeRuntimeValueChecked (existingValue : rest) currentValue
  | runtimeValueType existingValue == runtimeValueType currentValue =
      if existingValue == currentValue
        then Right (existingValue : rest)
        else Left ("runtime value conflict for " ++ show (runtimeValueType currentValue))
  | otherwise =
      case mergeRuntimeValueChecked rest currentValue of
        Left message ->
          Left message
        Right mergedRest ->
          Right (existingValue : mergedRest)

mergeRuntimeTypedValuesChecked :: [SomeRuntimeValue] -> [SomeRuntimeValue] -> Either String [SomeRuntimeValue]
mergeRuntimeTypedValuesChecked =
  foldlEither mergeRuntimeTypedValueChecked

mergeRuntimeTypedValueChecked :: [SomeRuntimeValue] -> SomeRuntimeValue -> Either String [SomeRuntimeValue]
mergeRuntimeTypedValueChecked [] currentValue =
  Right [currentValue]
mergeRuntimeTypedValueChecked (existingValue : rest) currentValue
  | someRuntimeValueType existingValue == someRuntimeValueType currentValue =
      if existingValue == currentValue
        then Right (existingValue : rest)
        else Left ("runtime typed value conflict for " ++ show (someRuntimeValueType currentValue))
  | otherwise =
      case mergeRuntimeTypedValueChecked rest currentValue of
        Left message ->
          Left message
        Right mergedRest ->
          Right (existingValue : mergedRest)

mergeRuntimeFactClaimsChecked :: [RuntimeFactClaim] -> [RuntimeFactClaim] -> Either String [RuntimeFactClaim]
mergeRuntimeFactClaimsChecked =
  foldlEither mergeRuntimeFactClaimChecked

mergeRuntimeFactClaimChecked :: [RuntimeFactClaim] -> RuntimeFactClaim -> Either String [RuntimeFactClaim]
mergeRuntimeFactClaimChecked [] currentClaim =
  Right [currentClaim]
mergeRuntimeFactClaimChecked (existingClaim : rest) currentClaim
  | runtimeFactClaimFact existingClaim == runtimeFactClaimFact currentClaim =
      if existingClaim == currentClaim
        then Right (existingClaim : rest)
        else Left ("runtime fact claim conflict for " ++ show (runtimeFactClaimFact currentClaim))
  | otherwise =
      case mergeRuntimeFactClaimChecked rest currentClaim of
        Left message ->
          Left message
        Right mergedRest ->
          Right (existingClaim : mergedRest)

foldlEither :: (accumulator -> item -> Either error accumulator) -> accumulator -> [item] -> Either error accumulator
foldlEither _ accumulator [] =
  Right accumulator
foldlEither step accumulator (item : rest) =
  case step accumulator item of
    Left errorReport ->
      Left errorReport
    Right nextAccumulator ->
      foldlEither step nextAccumulator rest

listDelta :: Eq item => [item] -> [item] -> [item]
listDelta prefix items =
  case stripListPrefix prefix items of
    Just rest ->
      rest
    Nothing ->
      items

stripListPrefix :: Eq item => [item] -> [item] -> Maybe [item]
stripListPrefix [] items =
  Just items
stripListPrefix (_ : _) [] =
  Nothing
stripListPrefix (prefixItem : prefixRest) (item : rest)
  | prefixItem == item =
      stripListPrefix prefixRest rest
  | otherwise =
      Nothing

choiceKeyText :: ChoiceKey -> String
choiceKeyText (ChoiceKey text) =
  text

ensureFact :: [WorkflowFact] -> WorkflowFact -> RuntimeM ()
ensureFact stack currentFact = do
  runtime <- getRuntimeState
  if currentFact `elem` availableFacts runtime
    then pure ()
    else
      if currentFact `elem` stack
        then throwRuntimeError (RuntimeWaitBlocked ("fact dependency cycle: " ++ show (reverse (currentFact : stack))))
        else do
          plan <- currentPlan
          case nativeRuleFor plan currentFact of
            Nothing ->
              throwRuntimeError (RuntimeMissingFactRule currentFact)
            Just rule -> do
              recordFactClaim currentFact RuntimeFactRunning Nothing
              dependencyResult <-
                catchRuntime
                  ( do
                      ensureRuleNeeds stack rule
                      ensureRuleTakes stack rule
                  )
              case dependencyResult of
                Left errorReport -> do
                  recordFactFailedIfAbsent currentFact (RuntimeLocalFactFailed (renderRuntimeError errorReport))
                  _ <- diagnoseRuntimeFailure currentFact Nothing errorReport
                  throwRuntimeError errorReport
                Right _ -> do
                  directResult <-
                    catchRuntime
                      (runRulePipeline rule)
                  case directResult of
                    Left errorReport ->
                      handleRuleDirectFailure rule errorReport
                    Right _ -> do
                      markRuleSucceeded rule
                      recordFactClaim currentFact RuntimeFactSucceeded Nothing

ensureRuleNeeds :: [WorkflowFact] -> NativeFactRule -> RuntimeM ()
ensureRuleNeeds stack rule =
  mapM_ ensureNeed (nativeRuleNeeds rule)
  where
    ensureNeed neededFact = do
      result <- catchRuntime (ensureFact (nativeRuleFact rule : stack) neededFact)
      case result of
        Right _ ->
          pure ()
        Left errorReport -> do
          recordFactFailedIfAbsent (nativeRuleFact rule) (RuntimeDependencyFailed neededFact)
          throwRuntimeError errorReport

ensureRuleTakes :: [WorkflowFact] -> NativeFactRule -> RuntimeM ()
ensureRuleTakes stack rule =
  mapM_ ensureTake (filter runtimePipeDependencyType (nativeRuleTakes rule))
  where
    ensureTake currentType = do
      runtime <- getRuntimeState
      if artifactAvailable currentType runtime
        then pure ()
        else do
          plan <- currentPlan
          case sourceFactsForType plan currentType of
            [sourceFact] -> do
              result <- catchRuntime (ensureFact stack sourceFact)
              case result of
                Right _ ->
                  pure ()
                Left errorReport -> do
                  recordFactFailedIfAbsent (nativeRuleFact rule) (RuntimePipeDependencyFailed sourceFact currentType)
                  throwRuntimeError errorReport
            [] ->
              throwRuntimeError (RuntimeWaitBlocked ("missing producer for pipe type " ++ show currentType))
            sources ->
              throwRuntimeError (RuntimeWaitBlocked ("duplicate producers for pipe type " ++ show currentType ++ ": " ++ show sources))

runRulePipeline :: NativeFactRule -> RuntimeM ()
runRulePipeline rule = do
  transforms <- resolveRuleTransforms rule
  pendingBeforeSends <- runAvailableTransforms transforms
  pendingAfterSends <- runPipelineSends pendingBeforeSends (nativeRuleUses rule)
  unresolved <- runAvailableTransforms pendingAfterSends
  case unresolved of
    [] ->
      pure ()
    RuntimeTransformUse expectedInput _ transformName _ : _ ->
      throwRuntimeError (RuntimeMissingTransformInput transformName expectedInput)

resolveRuleTransforms :: NativeFactRule -> RuntimeM [RuntimeTransformUse]
resolveRuleTransforms rule =
  mapM resolveTransform (nativeRuleTransforms rule)

resolveTransform :: (TypeName, TypeName, TransformName) -> RuntimeM RuntimeTransformUse
resolveTransform (expectedInput, expectedOutput, transformName) = do
  environment <- currentEffectEnvironment
  case transformFor (runtimeEffectTransforms environment) transformName of
    Nothing ->
      throwRuntimeError (RuntimeMissingTransform transformName)
    Just currentTransform ->
      if runtimeTransformInput currentTransform /= expectedInput
        || runtimeTransformOutput currentTransform /= expectedOutput
        then
          throwRuntimeError
            ( RuntimeTransformSignatureMismatch
                transformName
                expectedInput
                expectedOutput
                (runtimeTransformInput currentTransform)
                (runtimeTransformOutput currentTransform)
            )
        else
          pure (RuntimeTransformUse expectedInput expectedOutput transformName currentTransform)

runPipelineSends :: [RuntimeTransformUse] -> [SendName] -> RuntimeM [RuntimeTransformUse]
runPipelineSends pending [] =
  pure pending
runPipelineSends pending (currentSend : rest) = do
  readyBeforeSend <- runAvailableTransforms pending
  runSendWithPolicyOrThrow currentSend
  readyAfterSend <- runAvailableTransforms readyBeforeSend
  runPipelineSends readyAfterSend rest

runAvailableTransforms :: [RuntimeTransformUse] -> RuntimeM [RuntimeTransformUse]
runAvailableTransforms transforms = do
  (remaining, changed) <- runAvailableTransformPass transforms
  if changed
    then runAvailableTransforms remaining
    else pure remaining

runAvailableTransformPass :: [RuntimeTransformUse] -> RuntimeM ([RuntimeTransformUse], Bool)
runAvailableTransformPass [] =
  pure ([], False)
runAvailableTransformPass (currentTransform : rest) = do
  currentResult <- runTransformIfAvailable currentTransform
  (remainingRest, restChanged) <- runAvailableTransformPass rest
  case currentResult of
    TransformApplied ->
      pure (remainingRest, True)
    TransformAlreadySatisfied ->
      pure (remainingRest, restChanged)
    TransformWaiting ->
      pure (currentTransform : remainingRest, restChanged)

data RuntimeTransformProgress
  = TransformApplied
  | TransformAlreadySatisfied
  | TransformWaiting

runTransformIfAvailable :: RuntimeTransformUse -> RuntimeM RuntimeTransformProgress
runTransformIfAvailable (RuntimeTransformUse expectedInput expectedOutput transformName currentTransform) = do
  runtime <- getRuntimeState
  if artifactAvailable expectedOutput runtime
    then pure TransformAlreadySatisfied
    else
      case typedValueByType expectedInput runtime of
        Nothing ->
          pure TransformWaiting
        Just currentInput ->
          case applyRuntimeTransform transformName currentTransform currentInput of
            Left errorReport ->
              throwRuntimeError errorReport
            Right currentOutput -> do
              modifyRuntimeState (recordRuntimeTypedValues [currentOutput])
              traceRuntimeM ("transform " ++ show transformName)
              pure TransformApplied

runSendWithPolicyOrThrow :: SendName -> RuntimeM ()
runSendWithPolicyOrThrow currentSend = do
  result <- runSendWithPolicy currentSend
  case result of
    Nothing ->
      pure ()
    Just errorReport ->
      throwRuntimeError errorReport

runSendWithPolicy :: SendName -> RuntimeM (Maybe RuntimeError)
runSendWithPolicy currentSend = do
  firstResult <- runSendOnce currentSend
  case firstResult of
    Nothing ->
      pure Nothing
    Just errorReport -> do
      retryAllowed <- sendRetryAllowed currentSend
      if retryAllowed
        then do
          traceRuntimeM ("retry externalMake " ++ show currentSend)
          runSendOnce currentSend
        else
          pure (Just errorReport)

runSendOnce :: SendName -> RuntimeM (Maybe RuntimeError)
runSendOnce currentSend = do
  plan <- currentPlan
  environment <- currentEffectEnvironment
  case sendContractFor plan currentSend of
    Nothing ->
      pure (Just (RuntimeMissingSendBoundary currentSend))
    Just contract ->
      case handlerFor (runtimeEffectHandlers environment) currentSend of
        Nothing ->
          pure (Just (RuntimeMissingHandler currentSend))
        Just binding -> do
          runtime <- getRuntimeState
          traceRuntimeM ("externalMake " ++ show currentSend ++ " using " ++ show (handlerBindingName binding))
          inputResult <- catchRuntime (handlerInputFor runtime contract)
          case inputResult of
            Left errorReport ->
              pure (Just errorReport)
            Right input -> do
              result <- liftRuntimeIO (runRuntimeHandler (handlerBindingHandler binding) currentSend input runtime)
              case result of
                HandlerFailed message ->
                  pure (Just (RuntimeHandlerFailed currentSend message))
                HandlerSucceeded outputs -> do
                  validationResult <-
                    catchRuntime
                      ( do
                          validateRuntimeValueOutputs currentSend (sendOutput (sendContractSignature contract)) outputs
                          modifyRuntimeState (recordRuntimeValues outputs)
                      )
                  case validationResult of
                    Left errorReport ->
                      pure (Just errorReport)
                    Right _ ->
                      pure Nothing
                HandlerSucceededTyped outputs -> do
                  validationResult <-
                    catchRuntime
                      ( do
                          validateRuntimeTypedValueOutputs currentSend (sendOutput (sendContractSignature contract)) outputs
                          modifyRuntimeState (recordRuntimeTypedValues outputs)
                      )
                  case validationResult of
                    Left errorReport ->
                      pure (Just errorReport)
                    Right _ ->
                      pure Nothing

handlerInputFor :: Runtime -> SendContract -> RuntimeM HandlerInput
handlerInputFor runtime contract =
  case inputType of
    NoInput ->
      pure (handlerInputFromValues [])
    Unit ->
      pure (handlerInputFromValues [])
    _ ->
      case typedValuesByType inputType runtime of
        typedValues@(_ : _) ->
          pure (handlerInputFromTypedValues typedValues)
        [] ->
          case runtimeValuesByType inputType runtime of
            values@(_ : _) ->
              pure (handlerInputFromValues values)
            [] ->
              throwRuntimeError (RuntimeMissingHandlerInput (sendContractName contract) inputType)
  where
    inputType =
      sendInput (sendContractSignature contract)

validateRuntimeValueOutputs :: SendName -> TypeName -> [RuntimeValue] -> RuntimeM ()
validateRuntimeValueOutputs currentSend outputType outputs
  | not (isPipeType outputType) =
      pure ()
  | outputType `elem` map runtimeValueType outputs =
      pure ()
  | otherwise =
      throwRuntimeError
        ( RuntimeHandlerOutputMismatch
            currentSend
            outputType
            (map runtimeValueType outputs)
        )

validateRuntimeTypedValueOutputs :: SendName -> TypeName -> [SomeRuntimeValue] -> RuntimeM ()
validateRuntimeTypedValueOutputs currentSend outputType outputs
  | not (isPipeType outputType) =
      pure ()
  | outputType `elem` map someRuntimeValueType outputs =
      pure ()
  | otherwise =
      throwRuntimeError
        ( RuntimeHandlerOutputMismatch
            currentSend
            outputType
            (map someRuntimeValueType outputs)
        )

handleRuleDirectFailure :: NativeFactRule -> RuntimeError -> RuntimeM ()
handleRuleDirectFailure rule errorReport = do
  let currentFact =
        nativeRuleFact rule
      rootSend =
        runtimeErrorSend errorReport
  recordFactFailedIfAbsent currentFact (runtimeFactFailureForError rootSend errorReport)
  modifyRuntimeState (recordRuntimeValues [RuntimeValue ErrorInput (renderRuntimeError errorReport)])
  _ <- diagnoseRuntimeFailure currentFact rootSend errorReport
  runErrorHandlers rule
  throwRuntimeError errorReport

diagnoseRuntimeFailure :: WorkflowFact -> Maybe SendName -> RuntimeError -> RuntimeM RuntimeFailureDiagnosis
diagnoseRuntimeFailure currentFact currentSend errorReport = do
  plan <- currentPlan
  runtime <- getRuntimeState
  let diagnosis =
        buildFailureDiagnosis
          plan
          runtime
          currentFact
          currentSend
          (renderRuntimeError errorReport)
  probedDiagnosis <- runDiagnosisProbes diagnosis
  traceRuntimeM (renderRuntimeFailureDiagnosis probedDiagnosis)
  modifyRuntimeState (recordRuntimeDiagnosis probedDiagnosis)
  pure probedDiagnosis

runDiagnosisProbes :: RuntimeFailureDiagnosis -> RuntimeM RuntimeFailureDiagnosis
runDiagnosisProbes diagnosis =
  runDiagnosisProbePairs diagnosis (diagnosisProbePairs diagnosis)

runDiagnosisProbePairs ::
  RuntimeFailureDiagnosis ->
  [(WorkflowFact, SendName)] ->
  RuntimeM RuntimeFailureDiagnosis
runDiagnosisProbePairs diagnosis [] =
  pure diagnosis
runDiagnosisProbePairs diagnosis (currentProbe : rest) = do
  nextDiagnosis <- runDiagnosisProbe diagnosis currentProbe
  runDiagnosisProbePairs nextDiagnosis rest

runDiagnosisProbe ::
  RuntimeFailureDiagnosis ->
  (WorkflowFact, SendName) ->
  RuntimeM RuntimeFailureDiagnosis
runDiagnosisProbe diagnosis (currentFact, currentSend) = do
  traceRuntimeM ("diagnosis probe " ++ show currentFact ++ " externalMake " ++ show currentSend)
  result <- runSendOnce currentSend
  case result of
    Nothing -> do
      traceRuntimeM ("diagnosis probe ok " ++ show currentFact ++ " externalMake " ++ show currentSend)
      pure (completeDiagnosisProbe currentFact currentSend DiagnosisProbePassed diagnosis)
    Just errorReport -> do
      traceRuntimeM
        ( "diagnosis probe failed "
            ++ show currentFact
            ++ " externalMake "
            ++ show currentSend
            ++ " "
            ++ show errorReport
        )
      pure
        ( completeDiagnosisProbe
            currentFact
            currentSend
            (DiagnosisProbeFailed (show errorReport))
            diagnosis
        )

runErrorHandlers :: NativeFactRule -> RuntimeM ()
runErrorHandlers rule =
  case nativeRuleErrors rule of
    [] ->
      pure ()
    handlers -> do
      traceRuntimeM ("error handlers " ++ show (nativeRuleFact rule) ++ " " ++ show handlers)
      mapM_ runErrorHandler handlers
  where
    runErrorHandler currentHandler = do
      result <- runSendWithPolicy currentHandler
      case result of
        Nothing ->
          pure ()
        Just errorReport -> do
          traceRuntimeM ("error handler " ++ show currentHandler ++ " failed " ++ show errorReport)
          recordFactFailedIfAbsent
            (nativeRuleFact rule)
            (RuntimeErrorHandlerFailed currentHandler (show errorReport))

recordFactFailedIfAbsent :: WorkflowFact -> RuntimeFactFailure -> RuntimeM ()
recordFactFailedIfAbsent currentFact failure =
  modifyRuntimeState
    ( \runtime ->
        if factAlreadyFailedWithReason runtime currentFact
          then runtime
          else
            runtime
              { runtimeFactClaims =
                  upsertRuntimeFactClaim
                    (RuntimeFactClaim currentFact RuntimeFactFailed (Just failure))
                    (runtimeFactClaims runtime)
              }
    )

factAlreadyFailedWithReason :: Runtime -> WorkflowFact -> Bool
factAlreadyFailedWithReason runtime currentFact =
  case factClaimFor runtime currentFact of
    Just claim ->
      runtimeFactClaimStatus claim == RuntimeFactFailed
        && runtimeFactClaimFailure claim /= Nothing
    Nothing ->
      False

factClaimFor :: Runtime -> WorkflowFact -> Maybe RuntimeFactClaim
factClaimFor runtime currentFact =
  firstJust
    [ Just claim
    | claim <- runtimeFactClaims runtime
    , runtimeFactClaimFact claim == currentFact
    ]

runtimeFactFailureForError :: Maybe SendName -> RuntimeError -> RuntimeFactFailure
runtimeFactFailureForError (Just currentSend) errorReport =
  RuntimeExternalMakeFailed currentSend (renderRuntimeError errorReport)
runtimeFactFailureForError Nothing errorReport =
  RuntimeLocalFactFailed (renderRuntimeError errorReport)

runtimeErrorSend :: RuntimeError -> Maybe SendName
runtimeErrorSend errorReport =
  case errorReport of
    RuntimeMissingSendBoundary currentSend ->
      Just currentSend
    RuntimeMissingHandler currentSend ->
      Just currentSend
    RuntimeMissingHandlerInput currentSend _ ->
      Just currentSend
    RuntimeHandlerOutputMismatch currentSend _ _ ->
      Just currentSend
    RuntimeHandlerFailed currentSend _ ->
      Just currentSend
    _ ->
      Nothing

sendRetryAllowed :: SendName -> RuntimeM Bool
sendRetryAllowed currentSend = do
  plan <- currentPlan
  case sendContractFor plan currentSend of
    Just contract ->
      pure
        ( sendContractRetry contract == RetryOnce
            && sendContractIdempotency contract == Idempotent
        )
    Nothing ->
      pure False

markRuleSucceeded :: NativeFactRule -> RuntimeM ()
markRuleSucceeded rule =
  modifyRuntimeState
    ( \runtime ->
        markFact
          (nativeRuleFact rule)
          ( recordRuntimeValues
              [ RuntimeValue currentType ("produced by " ++ show (nativeRuleFact rule))
              | currentType <- nativeRuleMakes rule
              , isPipeType currentType
              , currentType `notElem` availablePipeTypes runtime
              ]
              runtime
          )
    )

runHanging :: Workflow.AppHanging -> RuntimeM ()
runHanging hanging =
  mapM_ runHangingAction (filter runtimeHangingAction (hangingItems hanging))

runHangingAction :: HangingAction WorkflowFact Interceptor (Workflow WorkflowFact Interceptor) -> RuntimeM ()
runHangingAction action =
  case action of
    HangingCallback callback ->
      traceRuntimeM ("callback registered " ++ show (callbackTarget callback))
    HangingSuspense suspense ->
      requestSuspense (suspenseTarget suspense)
    HangingLoop loop ->
      runLoop loop
    HangingMiddleware middleware body ->
      runMiddleware middleware body

runtimeCallbacksFromHanging :: Workflow.AppHanging -> [RuntimeCallback]
runtimeCallbacksFromHanging hanging =
  [ RuntimeCallback
      { runtimeCallbackTarget = callbackTarget callback
      , runtimeCallbackBody = callbackBody callback
      }
  | HangingCallback callback <- hangingItems hanging
  ]

runtimeHangingAction :: HangingAction fact hook workflow -> Bool
runtimeHangingAction action =
  case action of
    HangingCallback _ ->
      False
    _ ->
      True

requestSuspense :: WorkflowName -> RuntimeM ()
requestSuspense target = do
  runtime <- getRuntimeState
  let status = componentStatus target runtime
      snapshot = runtimeSnapshot runtime
  modifyRuntimeState
    ( \currentRuntime ->
        currentRuntime
          { runtimeSuspenseEvents =
              runtimeSuspenseEvents currentRuntime ++ [RuntimeSuspenseRequested target status snapshot]
          }
    )
  traceRuntimeM ("suspense requested " ++ show target ++ " " ++ show status)

runLoop :: Loop (Workflow WorkflowFact Interceptor) -> RuntimeM ()
runLoop (Loop body) =
  runLoopUntilFixedPoint 0 body

runLoopUntilFixedPoint :: Int -> Workflow WorkflowFact Interceptor -> RuntimeM ()
runLoopUntilFixedPoint iteration body
  | iteration >= maxLoopIterations =
      throwRuntimeError (RuntimeLoopExceeded maxLoopIterations)
  | otherwise = do
      before <- getRuntimeState
      runWorkflow body
      after <- getRuntimeState
      if runtimeFixedPointSignature before == runtimeFixedPointSignature after
        then traceRuntimeM ("loop fixed point " ++ show (iteration + 1))
        else runLoopUntilFixedPoint (iteration + 1) body

maxLoopIterations :: Int
maxLoopIterations =
  16

runtimeFixedPointSignature :: Runtime -> ([WorkflowFact], [RuntimeValue], [String])
runtimeFixedPointSignature runtime =
  (availableFacts runtime, runtimeValues runtime, map someRuntimeValueSignature (runtimeTypedValues runtime))

someRuntimeValueSignature :: SomeRuntimeValue -> String
someRuntimeValueSignature value =
  show (someRuntimeValueType value) ++ ":" ++ someRuntimeValueText value

runMiddleware :: Middleware Interceptor -> Workflow WorkflowFact Interceptor -> RuntimeM ()
runMiddleware middleware body =
  withRuntimeMiddleware (middlewareHook middleware) $ do
    traceRuntimeM ("middleware " ++ show (middlewareHook middleware) ++ " begin")
    result <- catchRuntime (runWorkflow body)
    traceRuntimeM ("middleware " ++ show (middlewareHook middleware) ++ " end")
    case result of
      Right _ ->
        pure ()
      Left errorReport ->
        throwRuntimeError errorReport

enterComponent :: WorkflowName -> RuntimeM ()
enterComponent name =
  modifyRuntimeState
    ( \runtime ->
        runtime
          { runtimeActiveComponents = name : runtimeActiveComponents runtime
          , runtimeComponentEvents = runtimeComponentEvents runtime ++ [RuntimeComponentEntered name]
          }
    )

exitComponent :: WorkflowName -> RuntimeM ()
exitComponent name =
  modifyRuntimeState
    ( \runtime ->
        runtime
          { runtimeActiveComponents = removeFirst name (runtimeActiveComponents runtime)
          , runtimeCompletedComponents = unique (runtimeCompletedComponents runtime ++ [name])
          , runtimeComponentEvents = runtimeComponentEvents runtime ++ [RuntimeComponentExited name]
          }
    )

recordCallbackEvent :: RuntimeCallbackEvent -> RuntimeM ()
recordCallbackEvent event =
  modifyRuntimeState
    ( \runtime ->
        runtime {runtimeCallbackEvents = runtimeCallbackEvents runtime ++ [event]}
    )

pushRuntimeMiddleware :: Interceptor -> Runtime -> Runtime
pushRuntimeMiddleware currentMiddleware runtime =
  runtime
    { runtimeMiddlewareStack = currentMiddleware : runtimeMiddlewareStack runtime
    , runtimeMiddlewareEvents = runtimeMiddlewareEvents runtime ++ [RuntimeMiddlewareEntered currentMiddleware]
    }

popRuntimeMiddleware :: Interceptor -> Runtime -> Runtime
popRuntimeMiddleware currentMiddleware runtime =
  runtime
    { runtimeMiddlewareStack = removeFirst currentMiddleware (runtimeMiddlewareStack runtime)
    , runtimeMiddlewareEvents = runtimeMiddlewareEvents runtime ++ [RuntimeMiddlewareExited currentMiddleware]
    }

markFact :: WorkflowFact -> Runtime -> Runtime
markFact currentFact runtime =
  runtime
    { availableFacts = unique (availableFacts runtime ++ [currentFact])
    , runtimeTrace = runtimeTrace runtime ++ ["[runtime] fact [" ++ show currentFact ++ "]"]
    }

recordRuntimeValues :: [RuntimeValue] -> Runtime -> Runtime
recordRuntimeValues values runtime =
  runtime
    { runtimeValues = mergeRuntimeValues (runtimeValues runtime) values
    , runtimeTypedValues =
        mergeRuntimeTypedValues
          (runtimeTypedValues runtime)
          [ currentTypedValue
          | currentValue <- values
          , Just currentTypedValue <- [runtimeValueToSome currentValue]
          ]
    , availablePipeTypes =
        unique (availablePipeTypes runtime ++ map runtimeValueType values)
    }

recordRuntimeTypedValues :: [SomeRuntimeValue] -> Runtime -> Runtime
recordRuntimeTypedValues values runtime =
  runtime
    { runtimeTypedValues = mergeRuntimeTypedValues (runtimeTypedValues runtime) values
    , runtimeValues = mergeRuntimeValues (runtimeValues runtime) (map someRuntimeValueToRuntimeValue values)
    , availablePipeTypes = unique (availablePipeTypes runtime ++ map someRuntimeValueType values)
    }

recordFactClaim :: WorkflowFact -> RuntimeFactStatus -> Maybe RuntimeFactFailure -> RuntimeM ()
recordFactClaim currentFact status failure =
  modifyRuntimeState
    ( \runtime ->
        runtime {runtimeFactClaims = upsertRuntimeFactClaim (RuntimeFactClaim currentFact status failure) (runtimeFactClaims runtime)}
    )

handlerInputFromValues :: [RuntimeValue] -> HandlerInput
handlerInputFromValues values =
  HandlerInput
    { handlerInputValues = values
    , handlerInputTypedValues =
        [ currentTypedValue
        | currentValue <- values
        , Just currentTypedValue <- [runtimeValueToSome currentValue]
        ]
    }

handlerInputFromTypedValues :: [SomeRuntimeValue] -> HandlerInput
handlerInputFromTypedValues values =
  HandlerInput
    { handlerInputValues = map someRuntimeValueToRuntimeValue values
    , handlerInputTypedValues = values
    }

runtimeValueToSome :: RuntimeValue -> Maybe SomeRuntimeValue
runtimeValueToSome currentValue =
  case runtimeValueType currentValue of
    NoInput ->
      Just (SomeRuntimeValue (RuntimeTypedValue noInputTag NoInputValue))
    Unit ->
      Just (SomeRuntimeValue (RuntimeTypedValue unitTag UnitValue))
    ErrorInput ->
      Just (SomeRuntimeValue (RuntimeTypedValue errorInputTag (ErrorInputValue (runtimeValueText currentValue))))
    _ ->
      Nothing

someRuntimeValueToRuntimeValue :: SomeRuntimeValue -> RuntimeValue
someRuntimeValueToRuntimeValue (SomeRuntimeValue currentValue) =
  runtimeTypedValueToRuntimeValue currentValue

runtimeTypedValueToRuntimeValue :: RuntimeTypedValue value -> RuntimeValue
runtimeTypedValueToRuntimeValue currentValue =
  RuntimeValue
    { runtimeValueType = runtimeTypedValueType currentValue
    , runtimeValueText = runtimeTypedValueText currentValue
    }

typedValueFor :: ValueTag value -> Runtime -> Maybe (RuntimeTypedValue value)
typedValueFor currentTag runtime =
  firstJust
    [ typedValueFromSome currentTag currentValue
    | currentValue <- runtimeTypedValues runtime
    ]

typedValueFromSome :: ValueTag value -> SomeRuntimeValue -> Maybe (RuntimeTypedValue value)
typedValueFromSome expectedTag (SomeRuntimeValue currentValue) =
  case sameValueTag expectedTag (runtimeTypedValueTag currentValue) of
    Just Refl ->
      Just currentValue
    Nothing ->
      Nothing

sameValueTag :: ValueTag left -> ValueTag right -> Maybe (left :~: right)
sameValueTag (ValueTag leftType _) (ValueTag rightType _)
  | leftType == rightType =
      eqT
  | otherwise =
      Nothing

someRuntimeValueType :: SomeRuntimeValue -> TypeName
someRuntimeValueType (SomeRuntimeValue currentValue) =
  runtimeTypedValueType currentValue

someRuntimeValueText :: SomeRuntimeValue -> String
someRuntimeValueText (SomeRuntimeValue currentValue) =
  runtimeTypedValueText currentValue

runtimeTypedValueType :: RuntimeTypedValue value -> TypeName
runtimeTypedValueType currentValue =
  valueTagTypeName (runtimeTypedValueTag currentValue)

runtimeTypedValueText :: RuntimeTypedValue value -> String
runtimeTypedValueText currentValue =
  valueTagPayloadText (runtimeTypedValueTag currentValue) (runtimeTypedValuePayload currentValue)

applyRuntimeTransform ::
  TransformName ->
  RuntimeTransform ->
  SomeRuntimeValue ->
  Either RuntimeError SomeRuntimeValue
applyRuntimeTransform currentTransform (RuntimeTransform inputTag outputTag transform) currentInput =
  case typedValueFromSome inputTag currentInput of
    Just typedInput ->
      Right
        ( SomeRuntimeValue
            ( RuntimeTypedValue
                outputTag
                (transform (runtimeTypedValuePayload typedInput))
            )
        )
    Nothing ->
      Left
        ( RuntimeTransformInputMismatch
            currentTransform
            (valueTagTypeName inputTag)
            (someRuntimeValueType currentInput)
        )

runtimeTransformInput :: RuntimeTransform -> TypeName
runtimeTransformInput (RuntimeTransform inputTag _ _) =
  valueTagTypeName inputTag

runtimeTransformOutput :: RuntimeTransform -> TypeName
runtimeTransformOutput (RuntimeTransform _ outputTag _) =
  valueTagTypeName outputTag

valueTagTypeName :: ValueTag value -> TypeName
valueTagTypeName (ValueTag currentType _) =
  currentType

valueTagPayloadText :: ValueTag value -> value -> String
valueTagPayloadText (ValueTag _ renderValue) =
  renderValue

handlerFor :: HandlerRegistry -> SendName -> Maybe HandlerBinding
handlerFor registry currentSend =
  firstJust
    [ Just binding
    | binding <- handlerRegistryBindings registry
    , handlerBindingSend binding == currentSend
    ]

transformFor :: TransformRegistry -> TransformName -> Maybe RuntimeTransform
transformFor registry currentTransform =
  firstJust
    [ Just (transformBindingTransform binding)
    | binding <- transformRegistryBindings registry
    , transformBindingName binding == currentTransform
    ]

buildFailureDiagnosis ::
  NativeAppPlan ->
  Runtime ->
  WorkflowFact ->
  Maybe SendName ->
  String ->
  RuntimeFailureDiagnosis
buildFailureDiagnosis plan runtime rootFact rootSend rootError =
  RuntimeFailureDiagnosis
    { diagnosisRootFact = rootFact
    , diagnosisRootSend = rootSend
    , diagnosisRootError = rootError
    , diagnosisNodes = nodes
    , diagnosisProbes =
        [ RuntimeDiagnosisProbe currentFact currentSend DiagnosisProbePending
        | currentNode <- nodes
        , currentSend <- diagnosisNodeIdempotentSends currentNode
        , let currentFact = diagnosisNodeFact currentNode
        ]
    , diagnosisSuspects = diagnosisSuspectFacts nodes rootFact
    , diagnosisPollutedFacts = downstreamFacts plan runtime rootFact
    }
  where
    nodes =
      diagnosisNodesFrom plan runtime [] [SearchItem rootFact DiagnosisRoot]

data SearchItem = SearchItem WorkflowFact RuntimeDiagnosisNodeKind

diagnosisNodesFrom ::
  NativeAppPlan ->
  Runtime ->
  [WorkflowFact] ->
  [SearchItem] ->
  [RuntimeDiagnosisNode]
diagnosisNodesFrom _ _ _ [] =
  []
diagnosisNodesFrom plan runtime seen (SearchItem currentFact currentKind : rest)
  | currentFact `elem` seen =
      diagnosisNodesFrom plan runtime seen rest
  | otherwise =
      currentNode : diagnosisNodesFrom plan runtime (currentFact : seen) (rest ++ upstreamItems)
  where
    currentNode =
      diagnosisNodeFor plan runtime currentFact currentKind
    upstreamItems =
      case nativeRuleFor plan currentFact of
        Nothing ->
          []
        Just currentRule ->
          [ SearchItem neededFact (DiagnosisNeedsUpstream currentFact)
          | neededFact <- nativeRuleNeeds currentRule
          ]
            ++ [ SearchItem sourceFact (DiagnosisPipeUpstream currentFact currentType)
               | currentType <- filter runtimePipeDependencyType (nativeRuleTakes currentRule)
               , sourceFact <- sourceFactsForType plan currentType
               ]

diagnosisNodeFor ::
  NativeAppPlan ->
  Runtime ->
  WorkflowFact ->
  RuntimeDiagnosisNodeKind ->
  RuntimeDiagnosisNode
diagnosisNodeFor plan runtime currentFact currentKind =
  RuntimeDiagnosisNode
    { diagnosisNodeFact = currentFact
    , diagnosisNodeKind = currentKind
    , diagnosisNodeStatus = factStatus runtime currentFact
    , diagnosisNodeExternalMakes = sends
    , diagnosisNodeIdempotentSends = idempotentSends
    , diagnosisNodeNonIdempotentSends = nonIdempotentSends
    , diagnosisNodeBlockers = blockers
    }
  where
    currentRule =
      nativeRuleFor plan currentFact
    sends =
      maybe [] nativeRuleUses currentRule
    idempotentSends =
      [ currentSend
      | currentSend <- sends
      , sendIsIdempotent plan currentSend
      ]
    nonIdempotentSends =
      [ currentSend
      | currentSend <- sends
      , not (sendIsIdempotent plan currentSend)
      ]
    blockers =
      missingRuleBlocker currentRule
        ++ externalTakeBlocker currentRule
        ++ map DiagnosisNonIdempotentSend nonIdempotentSends

missingRuleBlocker :: Maybe NativeFactRule -> [RuntimeDiagnosisBlocker]
missingRuleBlocker Nothing =
  [DiagnosisMissingRule]
missingRuleBlocker (Just _) =
  []

externalTakeBlocker :: Maybe NativeFactRule -> [RuntimeDiagnosisBlocker]
externalTakeBlocker (Just currentRule)
  | nativeRuleExternal currentRule =
      [DiagnosisExternalTakeSource]
externalTakeBlocker _ =
  []

sendIsIdempotent :: NativeAppPlan -> SendName -> Bool
sendIsIdempotent plan currentSend =
  case sendContractFor plan currentSend of
    Just currentContract ->
      sendContractIdempotency currentContract == Idempotent
    Nothing ->
      False

diagnosisSuspectFacts :: [RuntimeDiagnosisNode] -> WorkflowFact -> [WorkflowFact]
diagnosisSuspectFacts nodes rootFact =
  unique
    ( rootFact
        : [ diagnosisNodeFact currentNode
          | currentNode <- nodes
          , nodeIsSuspect currentNode
          ]
    )

nodeIsSuspect :: RuntimeDiagnosisNode -> Bool
nodeIsSuspect currentNode =
  not (null (diagnosisNodeIdempotentSends currentNode))
    || any isNonIdempotentBlocker (diagnosisNodeBlockers currentNode)
    || DiagnosisMissingRule `elem` diagnosisNodeBlockers currentNode
    || DiagnosisExternalTakeSource `elem` diagnosisNodeBlockers currentNode
    || ( null (diagnosisNodeExternalMakes currentNode)
          && null (diagnosisNodeBlockers currentNode)
       )

isNonIdempotentBlocker :: RuntimeDiagnosisBlocker -> Bool
isNonIdempotentBlocker (DiagnosisNonIdempotentSend _) =
  True
isNonIdempotentBlocker _ =
  False

downstreamFacts :: NativeAppPlan -> Runtime -> WorkflowFact -> [WorkflowFact]
downstreamFacts plan runtime rootFact =
  downstreamFactsFrom plan runtime [] [rootFact]

downstreamFactsFrom ::
  NativeAppPlan ->
  Runtime ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  [WorkflowFact]
downstreamFactsFrom _ _ seen [] =
  seen
downstreamFactsFrom plan runtime seen (currentFact : rest) =
  downstreamFactsFrom plan runtime nextSeen (rest ++ nextFacts)
  where
    nextFacts =
      [ dependentFact
      | currentRule <- nativeAppPlanFactRules plan
      , currentFact `ruleDependsOnFact` (plan, currentRule)
      , let dependentFact = nativeRuleFact currentRule
      , dependentFact `elem` claimedFacts runtime
      , dependentFact `notElem` seen
      ]
    nextSeen =
      unique (seen ++ nextFacts)

ruleDependsOnFact :: WorkflowFact -> (NativeAppPlan, NativeFactRule) -> Bool
ruleDependsOnFact currentFact (plan, currentRule) =
  currentFact `elem` nativeRuleNeeds currentRule
    || any factMakesTakenType (nativeRuleTakes currentRule)
  where
    factMakesTakenType currentType =
      currentFact `elem` sourceFactsForType plan currentType

claimedFacts :: Runtime -> [WorkflowFact]
claimedFacts runtime =
  [ runtimeFactClaimFact currentClaim
  | currentClaim <- runtimeFactClaims runtime
  ]

factStatus :: Runtime -> WorkflowFact -> Maybe RuntimeFactStatus
factStatus runtime currentFact =
  runtimeFactClaimStatus <$> factClaimFor runtime currentFact

diagnosisProbePairs :: RuntimeFailureDiagnosis -> [(WorkflowFact, SendName)]
diagnosisProbePairs diagnosis =
  [ (diagnosisProbeFact currentProbe, diagnosisProbeSend currentProbe)
  | currentProbe <- diagnosisProbes diagnosis
  , diagnosisProbeStatus currentProbe == DiagnosisProbePending
  ]

completeDiagnosisProbe ::
  WorkflowFact ->
  SendName ->
  RuntimeDiagnosisProbeStatus ->
  RuntimeFailureDiagnosis ->
  RuntimeFailureDiagnosis
completeDiagnosisProbe currentFact currentSend currentStatus diagnosis =
  diagnosis
    { diagnosisProbes =
        map completeProbe (diagnosisProbes diagnosis)
    }
  where
    completeProbe currentProbe
      | diagnosisProbeFact currentProbe == currentFact
          && diagnosisProbeSend currentProbe == currentSend =
          currentProbe {diagnosisProbeStatus = currentStatus}
      | otherwise =
          currentProbe

recordRuntimeDiagnosis :: RuntimeFailureDiagnosis -> Runtime -> Runtime
recordRuntimeDiagnosis diagnosis runtime =
  runtime
    { runtimeFailureDiagnoses =
        runtimeFailureDiagnoses runtime ++ [diagnosis]
    }

renderRuntimeFailureDiagnosis :: RuntimeFailureDiagnosis -> String
renderRuntimeFailureDiagnosis diagnosis =
  unwords
    [ "diagnosis root"
    , show (diagnosisRootFact diagnosis)
    , renderRootSend (diagnosisRootSend diagnosis)
    , "error"
    , show (diagnosisRootError diagnosis)
    , "suspects"
    , show (diagnosisSuspects diagnosis)
    , "probes"
    , show (diagnosisProbes diagnosis)
    , "blocked"
    , show (blockedNodes (diagnosisNodes diagnosis))
    , "polluted"
    , show (diagnosisPollutedFacts diagnosis)
    ]

renderRootSend :: Maybe SendName -> String
renderRootSend Nothing =
  "local"
renderRootSend (Just currentSend) =
  "send " ++ show currentSend

blockedNodes :: [RuntimeDiagnosisNode] -> [(WorkflowFact, [RuntimeDiagnosisBlocker])]
blockedNodes nodes =
  [ (diagnosisNodeFact currentNode, diagnosisNodeBlockers currentNode)
  | currentNode <- nodes
  , not (null (diagnosisNodeBlockers currentNode))
  ]

renderRuntimeError :: RuntimeError -> String
renderRuntimeError =
  show

askRuntimeEnv :: RuntimeM RuntimeEnv
askRuntimeEnv =
  RuntimeM $ \environment state ->
    pure (RuntimeSucceeded environment state)

currentPlan :: RuntimeM NativeAppPlan
currentPlan =
  runtimeEnvPlan <$> askRuntimeEnv

currentEffectEnvironment :: RuntimeM RuntimeEffectEnvironment
currentEffectEnvironment =
  runtimeEnvEffectEnvironment <$> askRuntimeEnv

catchRuntime :: RuntimeM a -> RuntimeM (Either RuntimeError a)
catchRuntime program =
  RuntimeM $ \environment state -> do
    result <- runRuntimeMInternal program environment state
    case result of
      RuntimeSucceeded value nextState ->
        pure (RuntimeSucceeded (Right value) nextState)
      RuntimeFailed errorReport nextState ->
        pure (RuntimeSucceeded (Left errorReport) nextState)

traceFailure :: RuntimeError -> Runtime -> RuntimeError
traceFailure =
  const

nativeRuleFor :: NativeAppPlan -> WorkflowFact -> Maybe NativeFactRule
nativeRuleFor plan currentFact =
  firstJust
    [ Just rule
    | rule <- nativeAppPlanFactRules plan
    , nativeRuleFact rule == currentFact
    ]

sendContractFor :: NativeAppPlan -> SendName -> Maybe SendContract
sendContractFor plan currentSend =
  firstJust
    [ Just contract
    | contract <- nativeAppPlanSendContracts plan
    , sendContractName contract == currentSend
    ]

sourceFactsForType :: NativeAppPlan -> TypeName -> [WorkflowFact]
sourceFactsForType plan currentType =
  [ nativeRuleFact rule
  | rule <- nativeAppPlanFactRules plan
  , currentType `elem` nativeRuleMakes rule
  ]

artifactAvailable :: TypeName -> Runtime -> Bool
artifactAvailable currentType runtime =
  currentType `elem` availablePipeTypes runtime

typedValueByType :: TypeName -> Runtime -> Maybe SomeRuntimeValue
typedValueByType currentType runtime =
  firstJust (map matchValue (runtimeTypedValues runtime))
  where
    matchValue value
      | someRuntimeValueType value == currentType =
          Just value
      | otherwise =
          Nothing

typedValuesByType :: TypeName -> Runtime -> [SomeRuntimeValue]
typedValuesByType currentType runtime =
  [ value
  | value <- runtimeTypedValues runtime
  , someRuntimeValueType value == currentType
  ]

runtimeValuesByType :: TypeName -> Runtime -> [RuntimeValue]
runtimeValuesByType currentType runtime =
  [ value
  | value <- runtimeValues runtime
  , runtimeValueType value == currentType
  ]

componentStatus :: WorkflowName -> Runtime -> RuntimeComponentStatus
componentStatus name runtime
  | name `elem` runtimeCompletedComponents runtime =
      RuntimeComponentCompleted
  | name `elem` runtimeActiveComponents runtime =
      RuntimeComponentRunning
  | otherwise =
      RuntimeComponentNotStarted

isPipeType :: TypeName -> Bool
isPipeType NoInput =
  False
isPipeType Unit =
  False
isPipeType ErrorInput =
  False
isPipeType _ =
  True

runtimePipeDependencyType :: TypeName -> Bool
runtimePipeDependencyType NoInput =
  False
runtimePipeDependencyType Unit =
  False
runtimePipeDependencyType _ =
  True

mergeRuntimeValues :: [RuntimeValue] -> [RuntimeValue] -> [RuntimeValue]
mergeRuntimeValues =
  foldl upsertRuntimeValue

upsertRuntimeValue :: [RuntimeValue] -> RuntimeValue -> [RuntimeValue]
upsertRuntimeValue [] currentValue =
  [currentValue]
upsertRuntimeValue (existingValue : rest) currentValue
  | runtimeValueType existingValue == runtimeValueType currentValue =
      currentValue : rest
  | otherwise =
      existingValue : upsertRuntimeValue rest currentValue

mergeRuntimeTypedValues :: [SomeRuntimeValue] -> [SomeRuntimeValue] -> [SomeRuntimeValue]
mergeRuntimeTypedValues =
  foldl upsertRuntimeTypedValue

upsertRuntimeTypedValue :: [SomeRuntimeValue] -> SomeRuntimeValue -> [SomeRuntimeValue]
upsertRuntimeTypedValue [] currentValue =
  [currentValue]
upsertRuntimeTypedValue (existingValue : rest) currentValue
  | someRuntimeValueType existingValue == someRuntimeValueType currentValue =
      currentValue : rest
  | otherwise =
      existingValue : upsertRuntimeTypedValue rest currentValue

upsertRuntimeFactClaim :: RuntimeFactClaim -> [RuntimeFactClaim] -> [RuntimeFactClaim]
upsertRuntimeFactClaim claim [] =
  [claim]
upsertRuntimeFactClaim claim (existingClaim : rest)
  | runtimeFactClaimFact existingClaim == runtimeFactClaimFact claim =
      claim : rest
  | otherwise =
      existingClaim : upsertRuntimeFactClaim claim rest

removeFirst :: Eq item => item -> [item] -> [item]
removeFirst _ [] =
  []
removeFirst item (candidate : rest)
  | item == candidate =
      rest
  | otherwise =
      candidate : removeFirst item rest

unique :: Eq item => [item] -> [item]
unique =
  foldl appendUnique []

appendUnique :: Eq item => [item] -> item -> [item]
appendUnique items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest

nativePlanPassed :: NativeAppPlan -> Bool
nativePlanPassed =
  all Native.nativeConstraintPassed . nativeAppPlanConstraints

renderNativePlanErrors :: NativeAppPlan -> String
renderNativePlanErrors plan =
  joinLines
    [ Native.nativeConstraintMessage constraint
    | constraint <- nativeAppPlanConstraints plan
    , not (Native.nativeConstraintPassed constraint)
    ]

joinLines :: [String] -> String
joinLines [] =
  ""
joinLines [line] =
  line
joinLines (line : rest) =
  line ++ "\n" ++ joinLines rest

noInputTag :: ValueTag NoInputValue
noInputTag =
  ValueTag NoInput (\_ -> "")

unitTag :: ValueTag UnitValue
unitTag =
  ValueTag Unit (\_ -> "")

errorInputTag :: ValueTag ErrorInputValue
errorInputTag =
  ValueTag ErrorInput (\(ErrorInputValue text) -> text)
