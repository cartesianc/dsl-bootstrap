module Bootstrap.Effects.CoreRuntime.Facts.RuntimeEvidencePassed
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
  ) where

import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , fact
  , make
  , needs
  , uses
  )
import qualified Bootstrap.Effect as Effect

runtimeEvidencePassedFact :: EffectSection
runtimeEvidencePassedFact =
  fact RuntimeEvidencePassedFact
    [ needs RuntimePlanBuildEvidencePassedFact
    , needs RuntimeValidationEvidencePassedFact
    , needs RuntimeExecutionEvidencePassedFact
    , needs RuntimeConcurrencyEvidencePassedFact
    , needs RuntimeDiagnosisEvidencePassedFact
    , needs RuntimeBackendParityEvidencePassedFact
    , Effect.take RuntimePlanBuildEvidenceArtifact
    , Effect.take RuntimeValidationEvidenceArtifact
    , Effect.take RuntimeExecutionEvidenceArtifact
    , Effect.take RuntimeConcurrencyEvidenceArtifact
    , Effect.take RuntimeDiagnosisEvidenceArtifact
    , Effect.take RuntimeBackendParityEvidenceArtifact
    , uses RunRuntimeEvidence
    , make RuntimeEvidenceArtifact
    ]

runtimePlanBuildEvidencePassedFact :: EffectSection
runtimePlanBuildEvidencePassedFact =
  fact RuntimePlanBuildEvidencePassedFact
    [ needs RuntimePlanBuiltFact
    , needs RuntimeFactRuleClosureValidatedFact
    , needs RuntimeArtifactClosureValidatedFact
    , needs RuntimeSendBoundaryCoveredFact
    , needs RuntimeHandlerRegistryValidatedFact
    , needs RuntimeTransformRegistryValidatedFact
    , Effect.take RuntimePlanArtifact
    , Effect.take RuntimeFactRuleClosureArtifact
    , Effect.take RuntimeArtifactClosureArtifact
    , Effect.take RuntimeSendBoundaryCoverageArtifact
    , Effect.take RuntimeHandlerRegistryArtifact
    , Effect.take RuntimeTransformRegistryArtifact
    , uses RunRuntimePlanBuildEvidence
    , make RuntimePlanBuildEvidenceArtifact
    ]

runtimePlanBuiltFact :: EffectSection
runtimePlanBuiltFact =
  fact RuntimePlanBuiltFact
    [ needs MinimalCoreReportBuiltFact
    , Effect.take MinimalCoreReportArtifact
    , uses BuildRuntimePlan
    , make RuntimePlanArtifact
    ]

runtimeFactRuleClosureValidatedFact :: EffectSection
runtimeFactRuleClosureValidatedFact =
  fact RuntimeFactRuleClosureValidatedFact
    [ needs RuntimePlanBuiltFact
    , Effect.take RuntimePlanArtifact
    , uses ValidateRuntimeFactRuleClosure
    , make RuntimeFactRuleClosureArtifact
    ]

runtimeArtifactClosureValidatedFact :: EffectSection
runtimeArtifactClosureValidatedFact =
  fact RuntimeArtifactClosureValidatedFact
    [ needs RuntimeFactRuleClosureValidatedFact
    , Effect.take RuntimeFactRuleClosureArtifact
    , uses ValidateRuntimeArtifactClosure
    , make RuntimeArtifactClosureArtifact
    ]

runtimeSendBoundaryCoveredFact :: EffectSection
runtimeSendBoundaryCoveredFact =
  fact RuntimeSendBoundaryCoveredFact
    [ needs RuntimePlanBuiltFact
    , Effect.take RuntimePlanArtifact
    , uses ValidateRuntimeSendBoundaryCoverage
    , make RuntimeSendBoundaryCoverageArtifact
    ]

runtimeHandlerRegistryValidatedFact :: EffectSection
runtimeHandlerRegistryValidatedFact =
  fact RuntimeHandlerRegistryValidatedFact
    [ needs RuntimeSendBoundaryCoveredFact
    , Effect.take RuntimeSendBoundaryCoverageArtifact
    , uses ValidateRuntimeHandlerRegistry
    , make RuntimeHandlerRegistryArtifact
    ]

runtimeTransformRegistryValidatedFact :: EffectSection
runtimeTransformRegistryValidatedFact =
  fact RuntimeTransformRegistryValidatedFact
    [ needs RuntimePlanBuiltFact
    , Effect.take RuntimePlanArtifact
    , uses ValidateRuntimeTransformRegistry
    , make RuntimeTransformRegistryArtifact
    ]

runtimeValidationEvidencePassedFact :: EffectSection
runtimeValidationEvidencePassedFact =
  fact RuntimeValidationEvidencePassedFact
    [ needs MinimalCoreReportBuiltFact
    , needs ConstraintIRBuiltFact
    , needs SmtProofPassedFact
    , Effect.take MinimalCoreReportArtifact
    , Effect.take ConstraintIRArtifact
    , Effect.take SmtProofEvidence
    , uses RunRuntimeValidationEvidence
    , make RuntimeValidationEvidenceArtifact
    ]

runtimeExecutionEvidencePassedFact :: EffectSection
runtimeExecutionEvidencePassedFact =
  fact RuntimeExecutionEvidencePassedFact
    [ needs MinimalCoreReportBuiltFact
    , Effect.take MinimalCoreReportArtifact
    , uses RunRuntimeExecutionEvidence
    , make RuntimeExecutionEvidenceArtifact
    ]

runtimeConcurrencyEvidencePassedFact :: EffectSection
runtimeConcurrencyEvidencePassedFact =
  fact RuntimeConcurrencyEvidencePassedFact
    [ needs RuntimeExecutionEvidencePassedFact
    , Effect.take RuntimeExecutionEvidenceArtifact
    , uses RunRuntimeConcurrencyEvidence
    , make RuntimeConcurrencyEvidenceArtifact
    ]

runtimeErrorDispatchValidatedFact :: EffectSection
runtimeErrorDispatchValidatedFact =
  fact RuntimeErrorDispatchValidatedFact
    [ needs RuntimeExecutionEvidencePassedFact
    , Effect.take RuntimeExecutionEvidenceArtifact
    , uses ValidateRuntimeErrorDispatch
    , make RuntimeErrorDispatchArtifact
    ]

runtimeRetryPolicyValidatedFact :: EffectSection
runtimeRetryPolicyValidatedFact =
  fact RuntimeRetryPolicyValidatedFact
    [ needs RuntimeErrorDispatchValidatedFact
    , Effect.take RuntimeErrorDispatchArtifact
    , uses ValidateRuntimeRetryPolicy
    , make RuntimeRetryPolicyArtifact
    ]

runtimeIdempotencyPolicyValidatedFact :: EffectSection
runtimeIdempotencyPolicyValidatedFact =
  fact RuntimeIdempotencyPolicyValidatedFact
    [ needs RuntimeErrorDispatchValidatedFact
    , Effect.take RuntimeErrorDispatchArtifact
    , uses ValidateRuntimeIdempotencyPolicy
    , make RuntimeIdempotencyPolicyArtifact
    ]

runtimeDiagnosisEvidencePassedFact :: EffectSection
runtimeDiagnosisEvidencePassedFact =
  fact RuntimeDiagnosisEvidencePassedFact
    [ needs RuntimeErrorDispatchValidatedFact
    , needs RuntimeRetryPolicyValidatedFact
    , needs RuntimeIdempotencyPolicyValidatedFact
    , Effect.take RuntimeErrorDispatchArtifact
    , Effect.take RuntimeRetryPolicyArtifact
    , Effect.take RuntimeIdempotencyPolicyArtifact
    , uses RunRuntimeDiagnosisEvidence
    , make RuntimeDiagnosisEvidenceArtifact
    ]

runtimeBackendParityEvidencePassedFact :: EffectSection
runtimeBackendParityEvidencePassedFact =
  fact RuntimeBackendParityEvidencePassedFact
    [ needs RuntimeExecutionEvidencePassedFact
    , needs RuntimeConcurrencyEvidencePassedFact
    , Effect.take RuntimeExecutionEvidenceArtifact
    , Effect.take RuntimeConcurrencyEvidenceArtifact
    , uses RunRuntimeBackendParityEvidence
    , make RuntimeBackendParityEvidenceArtifact
    ]
