{-# LANGUAGE GADTs #-}

module Framework.Runtime.Types
  ( ErrorInputValue (..)
  , NoInputValue (..)
  , Runtime (..)
  , RuntimeCallbackEvent (..)
  , RuntimeComponentEvent (..)
  , RuntimeComponentStatus (..)
  , RuntimeContextEvent (..)
  , RuntimeDiagnosisBlocker (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisNodeKind (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeDiagnosisRootCause (..)
  , RuntimeDiagnosisStep (..)
  , RuntimeError (..)
  , RuntimeFactClaim (..)
  , RuntimeFactFailure (..)
  , RuntimeFactStatus (..)
  , RuntimeFailureDiagnosis (..)
  , RuntimeMiddlewareEvent (..)
  , RuntimeSnapshot (..)
  , RuntimeState
  , RuntimeSuspenseEvent (..)
  , RuntimeTypedValue (..)
  , RuntimeValue (..)
  , SomeRuntimeValue (..)
  , UnitValue (..)
  , ValueTag (..)
  , runtimeTypedValueText
  , runtimeTypedValueType
  , someRuntimeValueText
  , someRuntimeValueType
  , valueTagPayloadText
  , valueTagTypeName
  ) where

import Data.Typeable
  ( Typeable )

import Bootstrap.Effect
  ( SendName
  , TransformName
  , TypeName
  )
import Bootstrap.Workflow
  ( EffectSystemName
  , Interceptor
  , RecursionContextName
  , WorkflowFact
  )

data Runtime = Runtime
  { availableFacts :: [WorkflowFact]
  , availablePipeTypes :: [TypeName]
  , runtimeValues :: [RuntimeValue]
  , runtimeTypedValues :: [SomeRuntimeValue]
  , runtimeFactClaims :: [RuntimeFactClaim]
  , runtimeTrace :: [String]
  , runtimeActiveComponents :: [EffectSystemName]
  , runtimeCompletedComponents :: [EffectSystemName]
  , runtimeComponentEvents :: [RuntimeComponentEvent]
  , runtimeCallbackEvents :: [RuntimeCallbackEvent]
  , runtimeSuspenseEvents :: [RuntimeSuspenseEvent]
  , runtimeActiveContexts :: [RecursionContextName]
  , runtimeContextEvents :: [RuntimeContextEvent]
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
  , snapshotRuntimeActiveComponents :: [EffectSystemName]
  , snapshotRuntimeCompletedComponents :: [EffectSystemName]
  , snapshotRuntimeActiveContexts :: [RecursionContextName]
  , snapshotRuntimeContextEvents :: [RuntimeContextEvent]
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

data RuntimeFailureDiagnosis = RuntimeFailureDiagnosis
  { diagnosisRootSystem :: Maybe EffectSystemName
  , diagnosisRootFact :: WorkflowFact
  , diagnosisPipelineStep :: Maybe RuntimeDiagnosisStep
  , diagnosisRootCause :: RuntimeDiagnosisRootCause
  , diagnosisRootSend :: Maybe SendName
  , diagnosisRootError :: String
  , diagnosisNodes :: [RuntimeDiagnosisNode]
  , diagnosisProbes :: [RuntimeDiagnosisProbe]
  , diagnosisSuspects :: [WorkflowFact]
  , diagnosisPollutedFacts :: [WorkflowFact]
  }
  deriving (Eq, Show)

data RuntimeDiagnosisStep
  = DiagnosisFactStep WorkflowFact
  | DiagnosisSendStep SendName
  | DiagnosisTransformStep String
  deriving (Eq, Show)

data RuntimeDiagnosisRootCause
  = DiagnosisMissingFactRuleCause WorkflowFact
  | DiagnosisMissingSendBoundaryCause SendName
  | DiagnosisMissingHandlerCause SendName
  | DiagnosisMissingHandlerInputCause SendName TypeName
  | DiagnosisHandlerOutputMismatchCause SendName TypeName [TypeName]
  | DiagnosisHandlerFailedCause SendName String
  | DiagnosisMissingTransformCause String
  | DiagnosisMissingTransformInputCause String TypeName
  | DiagnosisTransformMismatchCause String
  | DiagnosisDependencyFailedCause WorkflowFact
  | DiagnosisWaitBlockedCause String
  | DiagnosisChoiceMissingBranchCause String
  | DiagnosisParallelBranchFailedCause Int
  | DiagnosisParallelMergeConflictCause String
  | DiagnosisFallbackExhaustedCause
  | DiagnosisRaceExhaustedCause
  | DiagnosisLoopExceededCause Int
  | DiagnosisIoExceptionCause String
  | DiagnosisUnknownRootCause String
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
  = RuntimeComponentEntered EffectSystemName
  | RuntimeComponentExited EffectSystemName
  deriving (Eq, Show)

data RuntimeCallbackEvent
  = RuntimeCallbackTriggered EffectSystemName
  | RuntimeCallbackCompleted EffectSystemName
  | RuntimeCallbackFailed EffectSystemName
  deriving (Eq, Show)

data RuntimeSuspenseEvent
  = RuntimeSuspenseRequested EffectSystemName RuntimeComponentStatus RuntimeSnapshot
  deriving (Eq, Show)

data RuntimeMiddlewareEvent
  = RuntimeMiddlewareEntered Interceptor
  | RuntimeMiddlewareExited Interceptor
  deriving (Eq, Show)

data RuntimeContextEvent
  = RuntimeContextStarted RecursionContextName
  | RuntimeContextCompleted RecursionContextName
  | RuntimeContextNodeEntered RecursionContextName [String] String String
  | RuntimeContextNodeExited RecursionContextName [String] String String
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

valueTagTypeName :: ValueTag value -> TypeName
valueTagTypeName (ValueTag currentType _) =
  currentType

valueTagPayloadText :: ValueTag value -> value -> String
valueTagPayloadText (ValueTag _ renderValue) =
  renderValue
