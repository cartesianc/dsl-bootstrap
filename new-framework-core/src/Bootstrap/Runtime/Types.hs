module Bootstrap.Runtime.Types
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , NativeHandler (..)
  , NativeRuntime (..)
  , RuntimeArtifact (..)
  , RuntimeEffectEnvironment (..)
  , SendContract (..)
  , TransformBinding (..)
  , TransformRegistry (..)
  ) where

import Bootstrap.Effect
  ( HandlerName
  , IdempotencyPolicy
  , RetryPolicy
  , SendName
  , SendSignature
  , TransformName
  , TypeName
  )
import Bootstrap.Workflow
  ( WorkflowFact )

data HandlerRegistry = HandlerRegistry
  { handlerRegistryBindings :: [HandlerBinding]
  }

data HandlerBinding = HandlerBinding
  { handlerBindingSend :: SendName
  , handlerBindingName :: HandlerName
  , handlerBindingHandler :: NativeHandler
  }

newtype NativeHandler = NativeHandler
  { runNativeHandler :: SendName -> [RuntimeArtifact] -> NativeRuntime -> IO HandlerResult
  }

data HandlerResult
  = HandlerSucceeded [RuntimeArtifact]
  | HandlerFailed String
  deriving (Eq, Show)

newtype TransformRegistry = TransformRegistry
  { transformRegistryBindings :: [TransformBinding]
  }

data TransformBinding = TransformBinding
  { transformBindingName :: TransformName
  , transformBindingInput :: TypeName
  , transformBindingOutput :: TypeName
  }
  deriving (Eq, Show)

data RuntimeEffectEnvironment = RuntimeEffectEnvironment
  { runtimeEffectHandlers :: HandlerRegistry
  , runtimeEffectTransforms :: TransformRegistry
  }

data RuntimeArtifact = RuntimeArtifact
  { artifactType :: TypeName
  , artifactText :: String
  }
  deriving (Eq, Show)

data NativeRuntime = NativeRuntime
  { availableFacts :: [WorkflowFact]
  , runtimeArtifacts :: [RuntimeArtifact]
  , runtimeTrace :: [String]
  , runtimeFailures :: [String]
  }
  deriving (Eq, Show)

data NativeAppPlan = NativeAppPlan
  { nativeAppPlanFacts :: [WorkflowFact]
  , nativeAppPlanRootFacts :: [WorkflowFact]
  , nativeAppPlanSendBoundaries :: [SendName]
  , nativeAppPlanSendContracts :: [SendContract]
  , nativeAppPlanFactRules :: [NativeFactRule]
  , nativeAppPlanConstraints :: [NativeConstraint]
  }

data SendContract = SendContract
  { sendContractName :: SendName
  , sendContractSignature :: SendSignature
  , sendContractIdempotency :: IdempotencyPolicy
  , sendContractRetry :: RetryPolicy
  }

data NativeFactRule = NativeFactRule
  { nativeRuleFact :: WorkflowFact
  , nativeRuleNeeds :: [WorkflowFact]
  , nativeRuleTakes :: [TypeName]
  , nativeRuleMakes :: [TypeName]
  , nativeRuleUses :: [SendName]
  , nativeRuleTransforms :: [(TypeName, TypeName, TransformName)]
  , nativeRuleErrors :: [SendName]
  , nativeRuleExternal :: Bool
  }
  deriving (Eq, Show)

data NativeConstraint = NativeConstraint
  { nativeConstraintName :: String
  , nativeConstraintPassed :: Bool
  , nativeConstraintMessage :: String
  }
  deriving (Eq, Show)
