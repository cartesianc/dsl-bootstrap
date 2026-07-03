module Bootstrap.Effects.CoreExpression.Facts.FrameworkCoreExpression
  ( astStructureExpressedFact
  , boundaryChecksExpressedFact
  , buildAppValidationExpressedFact
  , effectTheoryDslExpressedFact
  , frameworkCoreExpressedFact
  , frameworkCoreNativeValidatedFact
  , hyloRenderingProofSurfaceExpressedFact
  , registryCodegenExpressedFact
  , runtimeBackendAdapterExpressedFact
  , runtimeBackendParityExpressedFact
  , runtimeConcurrencySemanticsExpressedFact
  , runtimeDiagnosisExpressedFact
  , runtimeExecutionSemanticsExpressedFact
  , runtimeFactClosureExpressedFact
  , runtimeInterpreterExpressedFact
  , runtimePlanBuildExpressedFact
  , runtimeTypesExpressedFact
  , runtimeValidationExpressedFact
  , selfArtifactManifestExpressedFact
  ) where

import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , fact
  , needs
  )

astStructureExpressedFact :: EffectSection
astStructureExpressedFact =
  fact AstStructureExpressedFact
    [ needs FrameworkCoreModulesClassifiedFact
    , needs CoreSurfaceAstFormalizedFact
    ]

effectTheoryDslExpressedFact :: EffectSection
effectTheoryDslExpressedFact =
  fact EffectTheoryDslExpressedFact
    [ needs CoreSurfaceEffectTheoryFormalizedFact
    ]

runtimeInterpreterExpressedFact :: EffectSection
runtimeInterpreterExpressedFact =
  fact RuntimeInterpreterExpressedFact
    [ needs RuntimeTypesExpressedFact
    , needs RuntimeExecutionSemanticsExpressedFact
    , needs RuntimeConcurrencySemanticsExpressedFact
    , needs RuntimeDiagnosisExpressedFact
    , needs RuntimeBackendAdapterExpressedFact
    , needs RuntimeBackendParityExpressedFact
    , needs CoreSurfaceFormalizedFact
    , needs RuntimeEvidencePassedFact
    ]

runtimeTypesExpressedFact :: EffectSection
runtimeTypesExpressedFact =
  fact RuntimeTypesExpressedFact
    [ needs CoreSurfaceFormalizedFact
    ]

runtimePlanBuildExpressedFact :: EffectSection
runtimePlanBuildExpressedFact =
  fact RuntimePlanBuildExpressedFact
    [ needs MinimalCoreReportBuiltFact
    , needs RuntimePlanBuiltFact
    , needs RuntimeFactRuleClosureValidatedFact
    , needs RuntimeArtifactClosureValidatedFact
    , needs RuntimeSendBoundaryCoveredFact
    , needs RuntimePlanBuildEvidencePassedFact
    ]

runtimeValidationExpressedFact :: EffectSection
runtimeValidationExpressedFact =
  fact RuntimeValidationExpressedFact
    [ needs MinimalCoreReportBuiltFact
    , needs ConstraintIRBuiltFact
    , needs SmtProofPassedFact
    , needs RuntimeFactRuleClosureValidatedFact
    , needs RuntimeArtifactClosureValidatedFact
    , needs RuntimeValidationEvidencePassedFact
    ]

runtimeExecutionSemanticsExpressedFact :: EffectSection
runtimeExecutionSemanticsExpressedFact =
  fact RuntimeExecutionSemanticsExpressedFact
    [ needs RuntimeExecutionEvidencePassedFact
    ]

runtimeConcurrencySemanticsExpressedFact :: EffectSection
runtimeConcurrencySemanticsExpressedFact =
  fact RuntimeConcurrencySemanticsExpressedFact
    [ needs RuntimeConcurrencyEvidencePassedFact
    ]

runtimeDiagnosisExpressedFact :: EffectSection
runtimeDiagnosisExpressedFact =
  fact RuntimeDiagnosisExpressedFact
    [ needs RuntimeErrorDispatchValidatedFact
    , needs RuntimeRetryPolicyValidatedFact
    , needs RuntimeIdempotencyPolicyValidatedFact
    , needs RuntimeDiagnosisEvidencePassedFact
    ]

runtimeBackendAdapterExpressedFact :: EffectSection
runtimeBackendAdapterExpressedFact =
  fact RuntimeBackendAdapterExpressedFact
    [ needs CoreSurfaceFormalizedFact
    , needs RuntimeHandlerRegistryValidatedFact
    , needs RuntimeTransformRegistryValidatedFact
    , needs RuntimeExecutionEvidencePassedFact
    ]

runtimeBackendParityExpressedFact :: EffectSection
runtimeBackendParityExpressedFact =
  fact RuntimeBackendParityExpressedFact
    [ needs CoreSurfaceFormalizedFact
    , needs RuntimeBackendParityEvidencePassedFact
    ]

buildAppValidationExpressedFact :: EffectSection
buildAppValidationExpressedFact =
  fact BuildAppValidationExpressedFact
    [ needs MinimalCoreReportBuiltFact
    ]

boundaryChecksExpressedFact :: EffectSection
boundaryChecksExpressedFact =
  fact BoundaryChecksExpressedFact
    [ needs CoreBoundaryValidatedFact
    , needs FrontendBoundaryValidatedFact
    ]

hyloRenderingProofSurfaceExpressedFact :: EffectSection
hyloRenderingProofSurfaceExpressedFact =
  fact HyloRenderingProofSurfaceExpressedFact
    [ needs CoreSurfaceFormalizedFact
    , needs ConstraintIRBuiltFact
    , needs SmtProofPassedFact
    ]

runtimeFactClosureExpressedFact :: EffectSection
runtimeFactClosureExpressedFact =
  fact RuntimeFactClosureExpressedFact
    [ needs RuntimePlanBuildExpressedFact
    , needs RuntimeValidationExpressedFact
    , needs RuntimeExecutionSemanticsExpressedFact
    , needs RuntimeArtifactClosureValidatedFact
    , needs RuntimeSendBoundaryCoveredFact
    , needs RuntimeEvidencePassedFact
    , needs SmtProofPassedFact
    ]

registryCodegenExpressedFact :: EffectSection
registryCodegenExpressedFact =
  fact RegistryCodegenExpressedFact
    [ needs RegistryCodegenEvidencePassedFact
    ]

selfArtifactManifestExpressedFact :: EffectSection
selfArtifactManifestExpressedFact =
  fact SelfArtifactManifestExpressedFact
    [ needs SelfArtifactManifestEvidencePassedFact
    ]

frameworkCoreNativeValidatedFact :: EffectSection
frameworkCoreNativeValidatedFact =
  fact FrameworkCoreNativeValidatedFact
    [ needs AstStructureExpressedFact
    , needs EffectTheoryDslExpressedFact
    , needs RuntimeInterpreterExpressedFact
    , needs BuildAppValidationExpressedFact
    , needs BoundaryChecksExpressedFact
    , needs HyloRenderingProofSurfaceExpressedFact
    , needs RuntimeFactClosureExpressedFact
    , needs RegistryCodegenExpressedFact
    , needs SelfArtifactManifestExpressedFact
    ]

frameworkCoreExpressedFact :: EffectSection
frameworkCoreExpressedFact =
  fact FrameworkCoreExpressedFact
    [ needs FrameworkCoreNativeValidatedFact
    ]
