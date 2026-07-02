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
  , RuntimeHandler (..)
  , RuntimeM (..)
  , RuntimeMiddlewareEvent (..)
  , RuntimeResult (..)
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
  , defaultRuntimeEnv
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
  , runBlueprintWithEffectEnvironment
  , runBlueprintWithEffectEnvironmentResult
  , runRuntimeM
  , runRuntimeMOrThrow
  , runtimeEffectEnvironment
  , runtimeEffectEnvironmentWithTransforms
  , runtimeEnv
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
  }
  deriving (Eq, Show)

type RuntimeState = Runtime

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
  | RuntimeLocalFactFailed String
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
  = RuntimeSuspenseRequested WorkflowName RuntimeComponentStatus
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
  | RuntimeFallbackExhausted
  | RuntimeRaceEmpty
  | RuntimeRaceExhausted
  | RuntimeIoException String
  deriving (Eq, Show)

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
    }

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
runBlueprintWithEffectEnvironmentResult environment effects blueprint =
  case buildNativeApp blueprint effects of
    Left message ->
      pure (Left (RuntimeWaitBlocked message))
    Right plan ->
      if not (nativePlanPassed plan)
        then pure (Left (RuntimeWaitBlocked (renderNativePlanErrors plan)))
        else do
          let callbacks = runtimeCallbacksFromHanging (blueprintHanging blueprint)
              currentEnv =
                withRuntimeCallbacks callbacks (runtimeEnv environment plan)
          appResult <- runRuntimeM currentEnv emptyRuntime (runWorkflow (blueprintApp blueprint))
          case appResult of
            RuntimeFailed errorReport runtime ->
              pure (Left (traceFailure errorReport runtime))
            RuntimeSucceeded _ appRuntime -> do
              hangingResult <- runRuntimeM currentEnv appRuntime (runHanging (blueprintHanging blueprint))
              case hangingResult of
                RuntimeFailed errorReport runtime ->
                  pure (Left (traceFailure errorReport runtime))
                RuntimeSucceeded _ finalRuntime ->
                  pure (Right finalRuntime)

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
      runNamedWorkflow "parallel" name (mapM_ runWorkflow (parallelItems branches))
    FallbackWorkflow branches ->
      runFallback (fallbackItems branches)
    RaceWorkflow branches ->
      runRace (raceItems branches)
    ChoiceWorkflow _ branches ->
      case choiceItems branches of
        [] ->
          throwRuntimeError (RuntimeChoiceMissingBranch "empty choice")
        ((_, branch) : _) ->
          runWorkflow branch
    WaitWorkflow wait body -> do
      runFactExpr (Workflow.waitFacts wait)
      runWorkflow body

runNamedWorkflow :: String -> WorkflowName -> RuntimeM () -> RuntimeM ()
runNamedWorkflow label name body = do
  enterComponent name
  traceRuntimeM (label ++ " " ++ show name)
  runWorkflowCallbacks name
  body
  exitComponent name

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
runFallback [] =
  throwRuntimeError RuntimeFallbackExhausted
runFallback (branch : rest) = do
  result <- catchRuntime (runWorkflow branch)
  case result of
    Right _ ->
      pure ()
    Left _ ->
      runFallback rest

runRace :: [Workflow WorkflowFact Interceptor] -> RuntimeM ()
runRace [] =
  throwRuntimeError RuntimeRaceEmpty
runRace branches =
  runFallback branches

runFactExpr :: FactExpr WorkflowFact -> RuntimeM ()
runFactExpr expression =
  case expression of
    FactItems requirements ->
      mapM_ (ensureFact []) (requirementItems requirements)
    FactAll expressions ->
      mapM_ runFactExpr expressions
    FactAny [] ->
      throwRuntimeError (RuntimeWaitBlocked "empty anyOf")
    FactAny (firstExpression : _) ->
      runFactExpr firstExpression

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
              mapM_ (ensureFact (currentFact : stack)) (nativeRuleNeeds rule)
              ensureRuleTakes stack rule
              runRuleTransforms rule
              runRuleSends rule
              markRuleSucceeded rule
              recordFactClaim currentFact RuntimeFactSucceeded Nothing

ensureRuleTakes :: [WorkflowFact] -> NativeFactRule -> RuntimeM ()
ensureRuleTakes stack rule =
  mapM_ ensureTake (filter isPipeType (nativeRuleTakes rule))
  where
    ensureTake currentType = do
      runtime <- getRuntimeState
      if artifactAvailable currentType runtime
        then pure ()
        else do
          plan <- currentPlan
          case sourceFactsForType plan currentType of
            [sourceFact] ->
              ensureFact stack sourceFact
            [] ->
              throwRuntimeError (RuntimeWaitBlocked ("missing producer for pipe type " ++ show currentType))
            sources ->
              throwRuntimeError (RuntimeWaitBlocked ("duplicate producers for pipe type " ++ show currentType ++ ": " ++ show sources))

runRuleTransforms :: NativeFactRule -> RuntimeM ()
runRuleTransforms rule =
  mapM_ runTransform (nativeRuleTransforms rule)

runTransform :: (TypeName, TypeName, TransformName) -> RuntimeM ()
runTransform (expectedInput, expectedOutput, transformName) = do
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
        else do
          runtime <- getRuntimeState
          case typedValueByType expectedInput runtime of
            Nothing ->
              throwRuntimeError (RuntimeMissingTransformInput transformName expectedInput)
            Just currentInput ->
              case applyRuntimeTransform transformName currentTransform currentInput of
                Left errorReport ->
                  throwRuntimeError errorReport
                Right currentOutput -> do
                  modifyRuntimeState (recordRuntimeTypedValues [currentOutput])
                  traceRuntimeM ("transform " ++ show transformName)

runRuleSends :: NativeFactRule -> RuntimeM ()
runRuleSends rule =
  mapM_ runSend (nativeRuleUses rule)

runSend :: SendName -> RuntimeM ()
runSend currentSend = do
  plan <- currentPlan
  environment <- currentEffectEnvironment
  case sendContractFor plan currentSend of
    Nothing ->
      throwRuntimeError (RuntimeMissingSendBoundary currentSend)
    Just contract ->
      case handlerFor (runtimeEffectHandlers environment) currentSend of
        Nothing ->
          throwRuntimeError (RuntimeMissingHandler currentSend)
        Just binding -> do
          runtime <- getRuntimeState
          input <- handlerInputFor runtime contract
          result <- liftRuntimeIO (runRuntimeHandler (handlerBindingHandler binding) currentSend input runtime)
          case result of
            HandlerFailed message ->
              throwRuntimeError (RuntimeHandlerFailed currentSend message)
            HandlerSucceeded outputs -> do
              validateRuntimeValueOutputs currentSend (sendOutput (sendContractSignature contract)) outputs
              modifyRuntimeState (recordRuntimeValues outputs)
              traceRuntimeM ("externalMake " ++ show currentSend ++ " using " ++ show (handlerBindingName binding))
            HandlerSucceededTyped outputs -> do
              validateRuntimeTypedValueOutputs currentSend (sendOutput (sendContractSignature contract)) outputs
              modifyRuntimeState (recordRuntimeTypedValues outputs)
              traceRuntimeM ("externalMake " ++ show currentSend ++ " using " ++ show (handlerBindingName binding) ++ " typed")

handlerInputFor :: Runtime -> SendContract -> RuntimeM HandlerInput
handlerInputFor runtime contract =
  if not (isPipeType inputType)
    then pure (handlerInputFromValues [])
    else
      case typedValuesByType inputType runtime of
        [] ->
          throwRuntimeError (RuntimeMissingHandlerInput (sendContractName contract) inputType)
        values ->
          pure (handlerInputFromTypedValues values)
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

markRuleSucceeded :: NativeFactRule -> RuntimeM ()
markRuleSucceeded rule =
  modifyRuntimeState
    ( markFact (nativeRuleFact rule)
        . recordRuntimeValues
          [ RuntimeValue currentType ("produced by " ++ show (nativeRuleFact rule))
          | currentType <- nativeRuleMakes rule
          , isPipeType currentType
          ]
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
  modifyRuntimeState
    ( \currentRuntime ->
        currentRuntime
          { runtimeSuspenseEvents =
              runtimeSuspenseEvents currentRuntime ++ [RuntimeSuspenseRequested target status]
          }
    )
  traceRuntimeM ("suspense requested " ++ show target ++ " " ++ show status)

runLoop :: Loop (Workflow WorkflowFact Interceptor) -> RuntimeM ()
runLoop _ =
  traceRuntimeM "loop forever start"

runMiddleware :: Middleware Interceptor -> Workflow WorkflowFact Interceptor -> RuntimeM ()
runMiddleware middleware body =
  withRuntimeMiddleware (middlewareHook middleware) $ do
    traceRuntimeM ("middleware " ++ show (middlewareHook middleware) ++ " begin")
    runWorkflow body
    traceRuntimeM ("middleware " ++ show (middlewareHook middleware) ++ " end")

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
