{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeOperators #-}

module Interpreter.Runtime.Types
  ( HandlerBinding (..)
  , HandlerInput (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , ErrorInputValue (..)
  , LogMessageValue (..)
  , NoInputValue (..)
  , Registry
  , ReportInputValue (..)
  , ReportOutputValue (..)
  , Runtime (..)
  , RuntimeCallback (..)
  , RuntimeCallbackEvent (..)
  , RuntimeComponentEvent (..)
  , RuntimeComponentStatus (..)
  , RuntimeContextware
  , RuntimeEnv (..)
  , RuntimeError (..)
  , RuntimeEffectEnvironment (..)
  , RuntimeFactClaim (..)
  , RuntimeFactFailure (..)
  , RuntimeFactStatus (..)
  , RuntimeFailureDiagnosis (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisNodeKind (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeDiagnosisBlocker (..)
  , RuntimeFAlgebra
  , RuntimeHandler (..)
  , RuntimeM (..)
  , RuntimeMiddlewareEvent (..)
  , RuntimeRecursionModel
  , RuntimeResult (..)
  , RuntimeSuspenseEvent (..)
  , RuntimeState
  , RuntimeTypedValue (..)
  , RuntimeTransform (..)
  , RuntimeValue (..)
  , SomeRuntimeValue (..)
  , TransformBinding (..)
  , TransformRegistry (..)
  , UnitValue (..)
  , UserNameValue (..)
  , UserRecordValue (..)
  , ValueTag (..)
  , WorkflowProgram
  , applyRuntimeTransform
  , emptyRuntime
  , handlerInputFromTypedValues
  , handlerInputFromValues
  , runtimeTypedValueText
  , runtimeTypedValueToRuntimeValue
  , runtimeTypedValueType
  , runtimeTransformInput
  , runtimeTransformOutput
  , runtimeValueToSome
  , sameValueTag
  , someRuntimeValueText
  , someRuntimeValueToRuntimeValue
  , someRuntimeValueType
  , typedValueFor
  , typedValueFromSome
  , valueTagTypeName
  ) where

import Data.Type.Equality
  ( (:~:) (Refl)
  )

import AST.Vocabulary
  ( Interceptor
  , WorkflowFact
  )
import Core.Architecture
  ( WorkflowName
  )
import AST.AppBlueprint
  ( AppBlueprint
  )
import Core.Effect.Semantics
  ( EffectSemantics
  )
import Core.Workflow.Eff
  ( WorkflowEffAlgebra
  )
import Effects.EffectTheory
  ( EffectTheory
  )
import Effects.Names
  ( HandlerName
  , SendName
  , TransformName
  , TypeName (..)
  )

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

newtype UserNameValue = UserNameValue String
  deriving (Eq, Show)

newtype UserRecordValue = UserRecordValue String
  deriving (Eq, Show)

newtype ReportInputValue = ReportInputValue String
  deriving (Eq, Show)

newtype ReportOutputValue = ReportOutputValue String
  deriving (Eq, Show)

newtype LogMessageValue = LogMessageValue String
  deriving (Eq, Show)

data ValueTag value where
  NoInputTag :: ValueTag NoInputValue
  UnitTag :: ValueTag UnitValue
  ErrorInputTag :: ValueTag ErrorInputValue
  UserNameTag :: ValueTag UserNameValue
  UserRecordTag :: ValueTag UserRecordValue
  ReportInputTag :: ValueTag ReportInputValue
  ReportOutputTag :: ValueTag ReportOutputValue
  LogMessageTag :: ValueTag LogMessageValue

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
  , runtimeEnvEffectSemantics :: EffectSemantics
  , runtimeEnvCallbacks :: [RuntimeCallback]
  }

data RuntimeCallback = RuntimeCallback
  { runtimeCallbackTarget :: WorkflowName
  , runtimeCallbackBody :: WorkflowProgram
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

type Registry = [WorkflowFact]

type WorkflowProgram = RuntimeM ()

type RuntimeFAlgebra = WorkflowEffAlgebra WorkflowFact WorkflowProgram

type RuntimeRecursionModel = RuntimeFAlgebra -> AppBlueprint -> IO ()

type RuntimeContextware = EffectTheory -> RuntimeFAlgebra -> RuntimeFAlgebra

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
      Just (SomeRuntimeValue (RuntimeTypedValue NoInputTag NoInputValue))
    Unit ->
      Just (SomeRuntimeValue (RuntimeTypedValue UnitTag UnitValue))
    ErrorInput ->
      Just (SomeRuntimeValue (RuntimeTypedValue ErrorInputTag (ErrorInputValue (runtimeValueText currentValue))))
    UserName ->
      Just (SomeRuntimeValue (RuntimeTypedValue UserNameTag (UserNameValue (runtimeValueText currentValue))))
    UserRecord ->
      Just (SomeRuntimeValue (RuntimeTypedValue UserRecordTag (UserRecordValue (runtimeValueText currentValue))))
    ReportInput ->
      Just (SomeRuntimeValue (RuntimeTypedValue ReportInputTag (ReportInputValue (runtimeValueText currentValue))))
    ReportOutput ->
      Just (SomeRuntimeValue (RuntimeTypedValue ReportOutputTag (ReportOutputValue (runtimeValueText currentValue))))
    LogMessage ->
      Just (SomeRuntimeValue (RuntimeTypedValue LogMessageTag (LogMessageValue (runtimeValueText currentValue))))

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
sameValueTag left right =
  case (left, right) of
    (NoInputTag, NoInputTag) -> Just Refl
    (UnitTag, UnitTag) -> Just Refl
    (ErrorInputTag, ErrorInputTag) -> Just Refl
    (UserNameTag, UserNameTag) -> Just Refl
    (UserRecordTag, UserRecordTag) -> Just Refl
    (ReportInputTag, ReportInputTag) -> Just Refl
    (ReportOutputTag, ReportOutputTag) -> Just Refl
    (LogMessageTag, LogMessageTag) -> Just Refl
    _ -> Nothing

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
valueTagTypeName currentTag =
  case currentTag of
    NoInputTag -> NoInput
    UnitTag -> Unit
    ErrorInputTag -> ErrorInput
    UserNameTag -> UserName
    UserRecordTag -> UserRecord
    ReportInputTag -> ReportInput
    ReportOutputTag -> ReportOutput
    LogMessageTag -> LogMessage

valueTagPayloadText :: ValueTag value -> value -> String
valueTagPayloadText currentTag currentValue =
  case currentTag of
    NoInputTag -> ""
    UnitTag -> ""
    ErrorInputTag ->
      case currentValue of
        ErrorInputValue text -> text
    UserNameTag ->
      case currentValue of
        UserNameValue text -> text
    UserRecordTag ->
      case currentValue of
        UserRecordValue text -> text
    ReportInputTag ->
      case currentValue of
        ReportInputValue text -> text
    ReportOutputTag ->
      case currentValue of
        ReportOutputValue text -> text
    LogMessageTag ->
      case currentValue of
        LogMessageValue text -> text

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest
