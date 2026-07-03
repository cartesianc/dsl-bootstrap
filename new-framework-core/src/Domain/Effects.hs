module Domain.Effects
  ( EffectRegistration (..)
  , effectRegistrationNames
  , frameworkCoreEffectRegistration
  , frameworkCoreEffects
  , registeredEffects
  ) where

import qualified Bootstrap.CoreSurface as CoreSurface
import Domain.Vocabulary
import Framework.Effect
  ( EffectTheory
  , EffectUnit
  )
import qualified Framework.Effect as Effect

data EffectRegistration = EffectRegistration
  { effectRegistrationName :: String
  , effectRegistrationTheory :: EffectTheory
  }

frameworkCoreEffectRegistration :: EffectRegistration
frameworkCoreEffectRegistration =
  EffectRegistration
    { effectRegistrationName = "framework-core"
    , effectRegistrationTheory = frameworkCoreEffects
    }

registeredEffects :: [EffectRegistration]
registeredEffects =
  [frameworkCoreEffectRegistration]

effectRegistrationNames :: [String]
effectRegistrationNames =
  map effectRegistrationName registeredEffects

frameworkCoreEffects :: EffectTheory
frameworkCoreEffects =
  Effect.theory
    [ coreModuleEffect
    , CoreSurface.coreSurfaceEffect
    , coreBoundaryEffect
    , coreLanguageEffect
    , coreProofEffect
    , coreRegistryEffect
    , coreArtifactEffect
    , coreRuntimeEffect
    , coreExpressionEffect
    , coreReportEffect
    ]

coreModuleEffect :: EffectUnit
coreModuleEffect =
  Effect.effect CoreModuleEffect
    [ Effect.fact PackageModulesDiscoveredFact
        [ Effect.uses ReadPackageFiles
        , Effect.make PackageModuleCatalog
        ]
    , Effect.fact FrameworkCoreModulesClassifiedFact
        [ Effect.needs PackageModulesDiscoveredFact
        , Effect.take PackageModuleCatalog
        , Effect.make FrameworkCoreModuleCatalog
        ]
    , Effect.fact CoreHostModulesClassifiedFact
        [ Effect.needs PackageModulesDiscoveredFact
        , Effect.take PackageModuleCatalog
        , Effect.make CoreHostModuleCatalog
        ]
    , Effect.externalMake ReadPackageFiles Effect.NoInput PackageModuleCatalog
    ]

coreBoundaryEffect :: EffectUnit
coreBoundaryEffect =
  Effect.effect CoreBoundaryEffect
    [ Effect.fact ImportGraphBuiltFact
        [ Effect.uses ExtractRealImportGraph
        , Effect.make ImportGraphArtifact
        ]
    , Effect.fact CoreBoundaryValidatedFact
        [ Effect.needs ImportGraphBuiltFact
        , Effect.take ImportGraphArtifact
        , Effect.uses CheckCoreBoundary
        , Effect.make CoreBoundaryEvidence
        ]
    , Effect.fact FrontendBoundaryValidatedFact
        [ Effect.needs ImportGraphBuiltFact
        , Effect.take ImportGraphArtifact
        , Effect.uses CheckFrontendBoundary
        , Effect.make FrontendBoundaryEvidence
        ]
    , Effect.externalMake ExtractRealImportGraph Effect.NoInput ImportGraphArtifact
    , Effect.externalMake CheckCoreBoundary ImportGraphArtifact CoreBoundaryEvidence
    , Effect.externalMake CheckFrontendBoundary ImportGraphArtifact FrontendBoundaryEvidence
    ]

coreLanguageEffect :: EffectUnit
coreLanguageEffect =
  Effect.effect CoreLanguageEffect
    [ Effect.fact LanguageSpecValidatedFact
        [ Effect.uses CheckLanguageSpec
        , Effect.make LanguageSpecEvidence
        ]
    , Effect.fact ElaborationContractValidatedFact
        [ Effect.needs LanguageSpecValidatedFact
        , Effect.take LanguageSpecEvidence
        , Effect.uses CheckElaborationContract
        , Effect.make ElaborationContractEvidence
        ]
    , Effect.externalMake CheckLanguageSpec Effect.NoInput LanguageSpecEvidence
    , Effect.externalMake CheckElaborationContract LanguageSpecEvidence ElaborationContractEvidence
    ]

coreProofEffect :: EffectUnit
coreProofEffect =
  Effect.effect CoreProofEffect
    [ Effect.fact MinimalCoreReportBuiltFact
        [ Effect.needs CoreBoundaryValidatedFact
        , Effect.needs FrontendBoundaryValidatedFact
        , Effect.needs LanguageSpecValidatedFact
        , Effect.needs ElaborationContractValidatedFact
        , Effect.take CoreBoundaryEvidence
        , Effect.take FrontendBoundaryEvidence
        , Effect.take LanguageSpecEvidence
        , Effect.take ElaborationContractEvidence
        , Effect.uses BuildMinimalCoreReport
        , Effect.make MinimalCoreReportArtifact
        ]
    , Effect.fact ConstraintIRBuiltFact
        [ Effect.needs MinimalCoreReportBuiltFact
        , Effect.take MinimalCoreReportArtifact
        , Effect.uses GenerateConstraintIR
        , Effect.make ConstraintIRArtifact
        ]
    , Effect.fact SmtProofPassedFact
        [ Effect.needs ConstraintIRBuiltFact
        , Effect.take ConstraintIRArtifact
        , Effect.uses RunSmtProof
        , Effect.make SmtProofEvidence
        ]
    , Effect.externalMake BuildMinimalCoreReport Effect.NoInput MinimalCoreReportArtifact
    , Effect.externalMake GenerateConstraintIR MinimalCoreReportArtifact ConstraintIRArtifact
    , Effect.externalMake RunSmtProof ConstraintIRArtifact SmtProofEvidence
    ]

coreRuntimeEffect :: EffectUnit
coreRuntimeEffect =
  Effect.effect CoreRuntimeEffect
    [ Effect.fact RuntimePlanBuiltFact
        [ Effect.needs MinimalCoreReportBuiltFact
        , Effect.take MinimalCoreReportArtifact
        , Effect.uses BuildRuntimePlan
        , Effect.make RuntimePlanArtifact
        ]
    , Effect.fact RuntimeFactRuleClosureValidatedFact
        [ Effect.needs RuntimePlanBuiltFact
        , Effect.take RuntimePlanArtifact
        , Effect.uses ValidateRuntimeFactRuleClosure
        , Effect.make RuntimeFactRuleClosureArtifact
        ]
    , Effect.fact RuntimeArtifactClosureValidatedFact
        [ Effect.needs RuntimeFactRuleClosureValidatedFact
        , Effect.take RuntimeFactRuleClosureArtifact
        , Effect.uses ValidateRuntimeArtifactClosure
        , Effect.make RuntimeArtifactClosureArtifact
        ]
    , Effect.fact RuntimeSendBoundaryCoveredFact
        [ Effect.needs RuntimePlanBuiltFact
        , Effect.take RuntimePlanArtifact
        , Effect.uses ValidateRuntimeSendBoundaryCoverage
        , Effect.make RuntimeSendBoundaryCoverageArtifact
        ]
    , Effect.fact RuntimeHandlerRegistryValidatedFact
        [ Effect.needs RuntimeSendBoundaryCoveredFact
        , Effect.take RuntimeSendBoundaryCoverageArtifact
        , Effect.uses ValidateRuntimeHandlerRegistry
        , Effect.make RuntimeHandlerRegistryArtifact
        ]
    , Effect.fact RuntimeTransformRegistryValidatedFact
        [ Effect.needs RuntimePlanBuiltFact
        , Effect.take RuntimePlanArtifact
        , Effect.uses ValidateRuntimeTransformRegistry
        , Effect.make RuntimeTransformRegistryArtifact
        ]
    , Effect.fact RuntimePlanBuildEvidencePassedFact
        [ Effect.needs RuntimePlanBuiltFact
        , Effect.needs RuntimeFactRuleClosureValidatedFact
        , Effect.needs RuntimeArtifactClosureValidatedFact
        , Effect.needs RuntimeSendBoundaryCoveredFact
        , Effect.needs RuntimeHandlerRegistryValidatedFact
        , Effect.needs RuntimeTransformRegistryValidatedFact
        , Effect.take RuntimePlanArtifact
        , Effect.take RuntimeFactRuleClosureArtifact
        , Effect.take RuntimeArtifactClosureArtifact
        , Effect.take RuntimeSendBoundaryCoverageArtifact
        , Effect.take RuntimeHandlerRegistryArtifact
        , Effect.take RuntimeTransformRegistryArtifact
        , Effect.uses RunRuntimePlanBuildEvidence
        , Effect.make RuntimePlanBuildEvidenceArtifact
        ]
    , Effect.fact RuntimeValidationEvidencePassedFact
        [ Effect.needs MinimalCoreReportBuiltFact
        , Effect.needs ConstraintIRBuiltFact
        , Effect.needs SmtProofPassedFact
        , Effect.take MinimalCoreReportArtifact
        , Effect.take ConstraintIRArtifact
        , Effect.take SmtProofEvidence
        , Effect.uses RunRuntimeValidationEvidence
        , Effect.make RuntimeValidationEvidenceArtifact
        ]
    , Effect.fact RuntimeExecutionEvidencePassedFact
        [ Effect.needs MinimalCoreReportBuiltFact
        , Effect.take MinimalCoreReportArtifact
        , Effect.uses RunRuntimeExecutionEvidence
        , Effect.make RuntimeExecutionEvidenceArtifact
        ]
    , Effect.fact RuntimeConcurrencyEvidencePassedFact
        [ Effect.needs RuntimeExecutionEvidencePassedFact
        , Effect.take RuntimeExecutionEvidenceArtifact
        , Effect.uses RunRuntimeConcurrencyEvidence
        , Effect.make RuntimeConcurrencyEvidenceArtifact
        ]
    , Effect.fact RuntimeErrorDispatchValidatedFact
        [ Effect.needs RuntimeExecutionEvidencePassedFact
        , Effect.take RuntimeExecutionEvidenceArtifact
        , Effect.uses ValidateRuntimeErrorDispatch
        , Effect.make RuntimeErrorDispatchArtifact
        ]
    , Effect.fact RuntimeRetryPolicyValidatedFact
        [ Effect.needs RuntimeErrorDispatchValidatedFact
        , Effect.take RuntimeErrorDispatchArtifact
        , Effect.uses ValidateRuntimeRetryPolicy
        , Effect.make RuntimeRetryPolicyArtifact
        ]
    , Effect.fact RuntimeIdempotencyPolicyValidatedFact
        [ Effect.needs RuntimeErrorDispatchValidatedFact
        , Effect.take RuntimeErrorDispatchArtifact
        , Effect.uses ValidateRuntimeIdempotencyPolicy
        , Effect.make RuntimeIdempotencyPolicyArtifact
        ]
    , Effect.fact RuntimeDiagnosisEvidencePassedFact
        [ Effect.needs RuntimeErrorDispatchValidatedFact
        , Effect.needs RuntimeRetryPolicyValidatedFact
        , Effect.needs RuntimeIdempotencyPolicyValidatedFact
        , Effect.take RuntimeErrorDispatchArtifact
        , Effect.take RuntimeRetryPolicyArtifact
        , Effect.take RuntimeIdempotencyPolicyArtifact
        , Effect.uses RunRuntimeDiagnosisEvidence
        , Effect.make RuntimeDiagnosisEvidenceArtifact
        ]
    , Effect.fact RuntimeBackendParityEvidencePassedFact
        [ Effect.needs RuntimeExecutionEvidencePassedFact
        , Effect.needs RuntimeConcurrencyEvidencePassedFact
        , Effect.take RuntimeExecutionEvidenceArtifact
        , Effect.take RuntimeConcurrencyEvidenceArtifact
        , Effect.uses RunRuntimeBackendParityEvidence
        , Effect.make RuntimeBackendParityEvidenceArtifact
        ]
    , Effect.fact RuntimeEvidencePassedFact
        [ Effect.needs RuntimePlanBuildEvidencePassedFact
        , Effect.needs RuntimeValidationEvidencePassedFact
        , Effect.needs RuntimeExecutionEvidencePassedFact
        , Effect.needs RuntimeConcurrencyEvidencePassedFact
        , Effect.needs RuntimeDiagnosisEvidencePassedFact
        , Effect.needs RuntimeBackendParityEvidencePassedFact
        , Effect.take RuntimePlanBuildEvidenceArtifact
        , Effect.take RuntimeValidationEvidenceArtifact
        , Effect.take RuntimeExecutionEvidenceArtifact
        , Effect.take RuntimeConcurrencyEvidenceArtifact
        , Effect.take RuntimeDiagnosisEvidenceArtifact
        , Effect.take RuntimeBackendParityEvidenceArtifact
        , Effect.uses RunRuntimeEvidence
        , Effect.make RuntimeEvidenceArtifact
        ]
    , Effect.externalMake BuildRuntimePlan MinimalCoreReportArtifact RuntimePlanArtifact
    , Effect.externalMake ValidateRuntimeFactRuleClosure RuntimePlanArtifact RuntimeFactRuleClosureArtifact
    , Effect.externalMake ValidateRuntimeArtifactClosure RuntimeFactRuleClosureArtifact RuntimeArtifactClosureArtifact
    , Effect.externalMake ValidateRuntimeSendBoundaryCoverage RuntimePlanArtifact RuntimeSendBoundaryCoverageArtifact
    , Effect.externalMake ValidateRuntimeHandlerRegistry RuntimeSendBoundaryCoverageArtifact RuntimeHandlerRegistryArtifact
    , Effect.externalMake ValidateRuntimeTransformRegistry RuntimePlanArtifact RuntimeTransformRegistryArtifact
    , Effect.externalMake RunRuntimePlanBuildEvidence RuntimeTransformRegistryArtifact RuntimePlanBuildEvidenceArtifact
    , Effect.externalMake RunRuntimeValidationEvidence MinimalCoreReportArtifact RuntimeValidationEvidenceArtifact
    , Effect.externalMake RunRuntimeExecutionEvidence MinimalCoreReportArtifact RuntimeExecutionEvidenceArtifact
    , Effect.externalMake RunRuntimeConcurrencyEvidence RuntimeExecutionEvidenceArtifact RuntimeConcurrencyEvidenceArtifact
    , Effect.externalMake ValidateRuntimeErrorDispatch RuntimeExecutionEvidenceArtifact RuntimeErrorDispatchArtifact
    , Effect.externalMake ValidateRuntimeRetryPolicy RuntimeErrorDispatchArtifact RuntimeRetryPolicyArtifact
    , Effect.externalMake ValidateRuntimeIdempotencyPolicy RuntimeErrorDispatchArtifact RuntimeIdempotencyPolicyArtifact
    , Effect.externalMake RunRuntimeDiagnosisEvidence RuntimeIdempotencyPolicyArtifact RuntimeDiagnosisEvidenceArtifact
    , Effect.externalMake RunRuntimeBackendParityEvidence RuntimeConcurrencyEvidenceArtifact RuntimeBackendParityEvidenceArtifact
    , Effect.externalMake RunRuntimeEvidence RuntimeBackendParityEvidenceArtifact RuntimeEvidenceArtifact
    ]

coreRegistryEffect :: EffectUnit
coreRegistryEffect =
  Effect.effect CoreRegistryEffect
    [ Effect.fact FrameworkCoreFrontendGeneratedFact
        [ Effect.needs MinimalCoreReportBuiltFact
        , Effect.take MinimalCoreReportArtifact
        , Effect.uses RunFrameworkCoreFrontendCodegenEvidence
        , Effect.make FrameworkCoreFrontendArtifact
        ]
    , Effect.fact RegistryCodegenEvidencePassedFact
        [ Effect.needs FrameworkCoreFrontendGeneratedFact
        , Effect.needs MinimalCoreReportBuiltFact
        , Effect.take FrameworkCoreFrontendArtifact
        , Effect.take MinimalCoreReportArtifact
        , Effect.uses RunRegistryCodegenEvidence
        , Effect.make RegistryCodegenArtifact
        ]
    , Effect.externalMake RunFrameworkCoreFrontendCodegenEvidence MinimalCoreReportArtifact FrameworkCoreFrontendArtifact
    , Effect.externalMake RunRegistryCodegenEvidence FrameworkCoreFrontendArtifact RegistryCodegenArtifact
    ]

coreArtifactEffect :: EffectUnit
coreArtifactEffect =
  Effect.effect CoreArtifactEffect
    [ Effect.fact SelfArtifactManifestEvidencePassedFact
        [ Effect.needs RegistryCodegenEvidencePassedFact
        , Effect.take RegistryCodegenArtifact
        , Effect.uses RunSelfArtifactManifestEvidence
        , Effect.make SelfArtifactManifestArtifact
        ]
    , Effect.externalMake RunSelfArtifactManifestEvidence RegistryCodegenArtifact SelfArtifactManifestArtifact
    ]

coreExpressionEffect :: EffectUnit
coreExpressionEffect =
  Effect.effect CoreExpressionEffect
    [ Effect.fact AstStructureExpressedFact
        [ Effect.needs FrameworkCoreModulesClassifiedFact
        , Effect.needs CoreSurfaceAstFormalizedFact
        ]
    , Effect.fact EffectTheoryDslExpressedFact
        [ Effect.needs CoreSurfaceEffectTheoryFormalizedFact
        ]
    , Effect.fact RuntimeTypesExpressedFact
        [ Effect.needs CoreSurfaceFormalizedFact
        ]
    , Effect.fact RuntimePlanBuildExpressedFact
        [ Effect.needs MinimalCoreReportBuiltFact
        , Effect.needs RuntimePlanBuiltFact
        , Effect.needs RuntimeFactRuleClosureValidatedFact
        , Effect.needs RuntimeArtifactClosureValidatedFact
        , Effect.needs RuntimeSendBoundaryCoveredFact
        , Effect.needs RuntimePlanBuildEvidencePassedFact
        ]
    , Effect.fact RuntimeValidationExpressedFact
        [ Effect.needs MinimalCoreReportBuiltFact
        , Effect.needs ConstraintIRBuiltFact
        , Effect.needs SmtProofPassedFact
        , Effect.needs RuntimeFactRuleClosureValidatedFact
        , Effect.needs RuntimeArtifactClosureValidatedFact
        , Effect.needs RuntimeValidationEvidencePassedFact
        ]
    , Effect.fact RuntimeExecutionSemanticsExpressedFact
        [ Effect.needs RuntimeExecutionEvidencePassedFact
        ]
    , Effect.fact RuntimeConcurrencySemanticsExpressedFact
        [ Effect.needs RuntimeConcurrencyEvidencePassedFact
        ]
    , Effect.fact RuntimeDiagnosisExpressedFact
        [ Effect.needs RuntimeErrorDispatchValidatedFact
        , Effect.needs RuntimeRetryPolicyValidatedFact
        , Effect.needs RuntimeIdempotencyPolicyValidatedFact
        , Effect.needs RuntimeDiagnosisEvidencePassedFact
        ]
    , Effect.fact RuntimeBackendAdapterExpressedFact
        [ Effect.needs CoreSurfaceFormalizedFact
        , Effect.needs RuntimeHandlerRegistryValidatedFact
        , Effect.needs RuntimeTransformRegistryValidatedFact
        , Effect.needs RuntimeExecutionEvidencePassedFact
        ]
    , Effect.fact RuntimeBackendParityExpressedFact
        [ Effect.needs CoreSurfaceFormalizedFact
        , Effect.needs RuntimeBackendParityEvidencePassedFact
        ]
    , Effect.fact RuntimeInterpreterExpressedFact
        [ Effect.needs RuntimeTypesExpressedFact
        , Effect.needs RuntimeExecutionSemanticsExpressedFact
        , Effect.needs RuntimeConcurrencySemanticsExpressedFact
        , Effect.needs RuntimeDiagnosisExpressedFact
        , Effect.needs RuntimeBackendAdapterExpressedFact
        , Effect.needs RuntimeBackendParityExpressedFact
        , Effect.needs CoreSurfaceFormalizedFact
        , Effect.needs RuntimeEvidencePassedFact
        ]
    , Effect.fact BuildAppValidationExpressedFact
        [ Effect.needs MinimalCoreReportBuiltFact
        ]
    , Effect.fact BoundaryChecksExpressedFact
        [ Effect.needs CoreBoundaryValidatedFact
        , Effect.needs FrontendBoundaryValidatedFact
        ]
    , Effect.fact HyloRenderingProofSurfaceExpressedFact
        [ Effect.needs CoreSurfaceFormalizedFact
        , Effect.needs ConstraintIRBuiltFact
        , Effect.needs SmtProofPassedFact
        ]
    , Effect.fact RuntimeFactClosureExpressedFact
        [ Effect.needs RuntimePlanBuildExpressedFact
        , Effect.needs RuntimeValidationExpressedFact
        , Effect.needs RuntimeExecutionSemanticsExpressedFact
        , Effect.needs RuntimeArtifactClosureValidatedFact
        , Effect.needs RuntimeSendBoundaryCoveredFact
        , Effect.needs RuntimeEvidencePassedFact
        , Effect.needs SmtProofPassedFact
        ]
    , Effect.fact RegistryCodegenExpressedFact
        [ Effect.needs RegistryCodegenEvidencePassedFact
        ]
    , Effect.fact SelfArtifactManifestExpressedFact
        [ Effect.needs SelfArtifactManifestEvidencePassedFact
        ]
    , Effect.fact FrameworkCoreNativeValidatedFact
        [ Effect.needs AstStructureExpressedFact
        , Effect.needs EffectTheoryDslExpressedFact
        , Effect.needs RuntimeInterpreterExpressedFact
        , Effect.needs BuildAppValidationExpressedFact
        , Effect.needs BoundaryChecksExpressedFact
        , Effect.needs HyloRenderingProofSurfaceExpressedFact
        , Effect.needs RuntimeFactClosureExpressedFact
        , Effect.needs RegistryCodegenExpressedFact
        , Effect.needs SelfArtifactManifestExpressedFact
        ]
    , Effect.fact FrameworkCoreExpressedFact
        [ Effect.needs FrameworkCoreNativeValidatedFact
        ]
    ]

coreReportEffect :: EffectUnit
coreReportEffect =
  Effect.effect CoreReportEffect
    [ Effect.fact FrameworkCoreReportPublishedFact
        [ Effect.needs FrameworkCoreNativeValidatedFact
        , Effect.needs FrameworkCoreExpressedFact
        , Effect.needs RuntimeEvidencePassedFact
        , Effect.take RuntimeEvidenceArtifact
        , Effect.uses PublishFrameworkCoreReport
        , Effect.make FrameworkCoreReportArtifact
        ]
    , Effect.externalMake PublishFrameworkCoreReport RuntimeEvidenceArtifact FrameworkCoreReportArtifact
    ]
