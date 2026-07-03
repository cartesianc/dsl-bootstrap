{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Effects.CoreRuntime.Registration.Effect
  ( coreRuntimeEffect
  ) where

import Bootstrap.Effects.CoreRuntime.Facts.RuntimeEvidencePassed
  ( runtimeArtifactClosureValidatedFact
  , runtimeBackendParityEvidencePassedFact
  , runtimeConcurrencyEvidencePassedFact
  , runtimeDiagnosisEvidencePassedFact
  , runtimeErrorDispatchValidatedFact
  , runtimeEvidencePassedFact
  , runtimeExecutionEvidencePassedFact
  , runtimeFactRuleClosureValidatedFact
  , runtimeHandlerRegistryValidatedFact
  , runtimeIdempotencyPolicyValidatedFact
  , runtimePlanBuildEvidencePassedFact
  , runtimePlanBuiltFact
  , runtimeRetryPolicyValidatedFact
  , runtimeSendBoundaryCoveredFact
  , runtimeTransformRegistryValidatedFact
  , runtimeValidationEvidencePassedFact
  )
import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , EffectUnit
  , effect
  , externalMake
  )

coreRuntimeEffect :: EffectUnit
coreRuntimeEffect =
  effect CoreRuntimeEffect
    [ runtimePlanBuiltFact
    , runtimeFactRuleClosureValidatedFact
    , runtimeArtifactClosureValidatedFact
    , runtimeSendBoundaryCoveredFact
    , runtimeHandlerRegistryValidatedFact
    , runtimeTransformRegistryValidatedFact
    , runtimePlanBuildEvidencePassedFact
    , runtimeValidationEvidencePassedFact
    , runtimeExecutionEvidencePassedFact
    , runtimeConcurrencyEvidencePassedFact
    , runtimeErrorDispatchValidatedFact
    , runtimeRetryPolicyValidatedFact
    , runtimeIdempotencyPolicyValidatedFact
    , runtimeDiagnosisEvidencePassedFact
    , runtimeBackendParityEvidencePassedFact
    , runtimeEvidencePassedFact
    , buildRuntimePlanBoundary
    , validateRuntimeFactRuleClosureBoundary
    , validateRuntimeArtifactClosureBoundary
    , validateRuntimeSendBoundaryCoverageBoundary
    , validateRuntimeHandlerRegistryBoundary
    , validateRuntimeTransformRegistryBoundary
    , runRuntimePlanBuildEvidenceBoundary
    , runRuntimeValidationEvidenceBoundary
    , runRuntimeExecutionEvidenceBoundary
    , runRuntimeConcurrencyEvidenceBoundary
    , validateRuntimeErrorDispatchBoundary
    , validateRuntimeRetryPolicyBoundary
    , validateRuntimeIdempotencyPolicyBoundary
    , runRuntimeDiagnosisEvidenceBoundary
    , runRuntimeBackendParityEvidenceBoundary
    , runRuntimeEvidenceBoundary
    ]

buildRuntimePlanBoundary :: EffectSection
buildRuntimePlanBoundary =
  externalMake BuildRuntimePlan MinimalCoreReportArtifact RuntimePlanArtifact

validateRuntimeFactRuleClosureBoundary :: EffectSection
validateRuntimeFactRuleClosureBoundary =
  externalMake ValidateRuntimeFactRuleClosure RuntimePlanArtifact RuntimeFactRuleClosureArtifact

validateRuntimeArtifactClosureBoundary :: EffectSection
validateRuntimeArtifactClosureBoundary =
  externalMake ValidateRuntimeArtifactClosure RuntimeFactRuleClosureArtifact RuntimeArtifactClosureArtifact

validateRuntimeSendBoundaryCoverageBoundary :: EffectSection
validateRuntimeSendBoundaryCoverageBoundary =
  externalMake ValidateRuntimeSendBoundaryCoverage RuntimePlanArtifact RuntimeSendBoundaryCoverageArtifact

validateRuntimeHandlerRegistryBoundary :: EffectSection
validateRuntimeHandlerRegistryBoundary =
  externalMake ValidateRuntimeHandlerRegistry RuntimeSendBoundaryCoverageArtifact RuntimeHandlerRegistryArtifact

validateRuntimeTransformRegistryBoundary :: EffectSection
validateRuntimeTransformRegistryBoundary =
  externalMake ValidateRuntimeTransformRegistry RuntimePlanArtifact RuntimeTransformRegistryArtifact

runRuntimePlanBuildEvidenceBoundary :: EffectSection
runRuntimePlanBuildEvidenceBoundary =
  externalMake RunRuntimePlanBuildEvidence RuntimeTransformRegistryArtifact RuntimePlanBuildEvidenceArtifact

runRuntimeValidationEvidenceBoundary :: EffectSection
runRuntimeValidationEvidenceBoundary =
  externalMake RunRuntimeValidationEvidence MinimalCoreReportArtifact RuntimeValidationEvidenceArtifact

runRuntimeExecutionEvidenceBoundary :: EffectSection
runRuntimeExecutionEvidenceBoundary =
  externalMake RunRuntimeExecutionEvidence MinimalCoreReportArtifact RuntimeExecutionEvidenceArtifact

runRuntimeConcurrencyEvidenceBoundary :: EffectSection
runRuntimeConcurrencyEvidenceBoundary =
  externalMake RunRuntimeConcurrencyEvidence RuntimeExecutionEvidenceArtifact RuntimeConcurrencyEvidenceArtifact

validateRuntimeErrorDispatchBoundary :: EffectSection
validateRuntimeErrorDispatchBoundary =
  externalMake ValidateRuntimeErrorDispatch RuntimeExecutionEvidenceArtifact RuntimeErrorDispatchArtifact

validateRuntimeRetryPolicyBoundary :: EffectSection
validateRuntimeRetryPolicyBoundary =
  externalMake ValidateRuntimeRetryPolicy RuntimeErrorDispatchArtifact RuntimeRetryPolicyArtifact

validateRuntimeIdempotencyPolicyBoundary :: EffectSection
validateRuntimeIdempotencyPolicyBoundary =
  externalMake ValidateRuntimeIdempotencyPolicy RuntimeErrorDispatchArtifact RuntimeIdempotencyPolicyArtifact

runRuntimeDiagnosisEvidenceBoundary :: EffectSection
runRuntimeDiagnosisEvidenceBoundary =
  externalMake RunRuntimeDiagnosisEvidence RuntimeIdempotencyPolicyArtifact RuntimeDiagnosisEvidenceArtifact

runRuntimeBackendParityEvidenceBoundary :: EffectSection
runRuntimeBackendParityEvidenceBoundary =
  externalMake RunRuntimeBackendParityEvidence RuntimeConcurrencyEvidenceArtifact RuntimeBackendParityEvidenceArtifact

runRuntimeEvidenceBoundary :: EffectSection
runRuntimeEvidenceBoundary =
  externalMake RunRuntimeEvidence RuntimeBackendParityEvidenceArtifact RuntimeEvidenceArtifact
