{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Vocabulary
  ( pattern AstStructureExpressedFact
  , pattern BoundaryChecksExpressedFact
  , pattern BuildAppValidationExpressedFact
  , pattern BuildMinimalCoreReport
  , pattern BuildProofFlow
  , pattern CheckCoreBoundary
  , pattern CheckElaborationContract
  , pattern CheckFrontendBoundary
  , pattern CheckLanguageSpec
  , pattern CompileCoreSurfaceEffectTheory
  , pattern ConstraintIRArtifact
  , pattern ComposeCoreSurfaceAst
  , pattern CoreArtifactEffect
  , pattern ConstraintIRBuiltFact
  , pattern CoreBoundaryEffect
  , pattern CoreBoundaryEvidence
  , pattern CoreBoundaryValidatedFact
  , pattern CoreExpressionEffect
  , pattern CoreLanguageEffect
  , pattern CoreModuleEffect
  , pattern CoreProofEffect
  , pattern CoreRegistryEffect
  , pattern CoreReportEffect
  , pattern CoreRuntimeEffect
  , pattern CoreHostModuleCatalog
  , pattern CoreHostModulesClassifiedFact
  , pattern CoreSurfaceAstFormalizedFact
  , pattern CoreSurfaceCatalogLoadedFact
  , pattern CoreSurfaceEffect
  , pattern CoreSurfaceEffectTheoryFormalizedFact
  , pattern CoreSurfaceFormalizationFlow
  , pattern CoreSurfaceFormalizedFact
  , pattern CoreSurfaceModulesFormalizationFlow
  , pattern EffectTheoryDslExpressedFact
  , pattern ElaborationContractValidatedFact
  , pattern ElaborationContractEvidence
  , pattern ExtractRealImportGraph
  , pattern FormalizeCoreSurfaceCapability
  , pattern FormalizeCoreSurfaceModule
  , pattern FrameworkCoreExpressedFact
  , pattern FrameworkCoreFlow
  , pattern FrameworkCoreFrontendArtifact
  , pattern FrameworkCoreFrontendGeneratedFact
  , pattern FrameworkCoreModuleCatalog
  , pattern FrameworkCoreModulesClassifiedFact
  , pattern FrameworkCoreNativeValidatedFact
  , pattern FrameworkCoreReportArtifact
  , pattern FrameworkCoreReportPublishedFact
  , pattern FrameworkCoreTraceMiddleware
  , pattern FrontendBoundaryValidatedFact
  , pattern FrontendBoundaryEvidence
  , pattern GenerateConstraintIR
  , pattern HyloRenderingProofSurfaceExpressedFact
  , pattern ImportGraphArtifact
  , pattern ImportGraphBuiltFact
  , pattern LanguageSpecValidatedFact
  , pattern LanguageSpecEvidence
  , pattern LoadCoreSurfaceCatalog
  , pattern MinimalCoreReportArtifact
  , pattern MinimalCoreReportBuiltFact
  , pattern PackageModuleCatalog
  , pattern PackageModulesDiscoveredFact
  , pattern PublishFrameworkCoreReport
  , pattern PublishBootstrapReportFlow
  , pattern ReadPackageFiles
  , pattern RuntimeFactClosureExpressedFact
  , pattern RuntimeInterpreterExpressedFact
  , pattern RegistryCodegenArtifact
  , pattern RegistryCodegenEvidencePassedFact
  , pattern RegistryCodegenExpressedFact
  , pattern RunFrameworkCoreFrontendCodegenEvidence
  , pattern RunRegistryCodegenEvidence
  , pattern RunSelfArtifactManifestEvidence
  , pattern BuildRuntimePlan
  , pattern RuntimeEvidenceArtifact
  , pattern RuntimeBackendAdapterExpressedFact
  , pattern RuntimeBackendParityExpressedFact
  , pattern RuntimeBackendParityEvidenceArtifact
  , pattern RuntimeBackendParityEvidencePassedFact
  , pattern RuntimeBranchExpressionFlow
  , pattern RuntimeArtifactClosureArtifact
  , pattern RuntimeArtifactClosureValidatedFact
  , pattern RuntimeConcurrencyEvidenceArtifact
  , pattern RuntimeConcurrencyEvidencePassedFact
  , pattern RuntimeConcurrencySemanticsExpressedFact
  , pattern RuntimeErrorDispatchArtifact
  , pattern RuntimeErrorDispatchValidatedFact
  , pattern RuntimeFactRuleClosureArtifact
  , pattern RuntimeFactRuleClosureValidatedFact
  , pattern RuntimeHandlerRegistryArtifact
  , pattern RuntimeHandlerRegistryValidatedFact
  , pattern RuntimeIdempotencyPolicyArtifact
  , pattern RuntimeIdempotencyPolicyValidatedFact
  , pattern RuntimePlanArtifact
  , pattern RuntimePlanBuiltFact
  , pattern RuntimeRetryPolicyArtifact
  , pattern RuntimeRetryPolicyValidatedFact
  , pattern RuntimeSendBoundaryCoverageArtifact
  , pattern RuntimeSendBoundaryCoveredFact
  , pattern RuntimeTransformRegistryArtifact
  , pattern RuntimeTransformRegistryValidatedFact
  , pattern ValidateRuntimeArtifactClosure
  , pattern ValidateRuntimeErrorDispatch
  , pattern ValidateRuntimeFactRuleClosure
  , pattern ValidateRuntimeHandlerRegistry
  , pattern ValidateRuntimeIdempotencyPolicy
  , pattern RunRuntimeBackendParityEvidence
  , pattern RunRuntimeConcurrencyEvidence
  , pattern RunRuntimeDiagnosisEvidence
  , pattern RunRuntimeExecutionEvidence
  , pattern RunRuntimeEvidence
  , pattern RunRuntimePlanBuildEvidence
  , pattern RunRuntimeValidationEvidence
  , pattern RunSmtProof
  , pattern ValidateRuntimeRetryPolicy
  , pattern ValidateRuntimeSendBoundaryCoverage
  , pattern ValidateRuntimeTransformRegistry
  , pattern RuntimeDiagnosisEvidenceArtifact
  , pattern RuntimeDiagnosisEvidencePassedFact
  , pattern RuntimeDiagnosisExpressedFact
  , pattern SelfArtifactManifestArtifact
  , pattern SelfArtifactManifestEvidencePassedFact
  , pattern SelfArtifactManifestExpressedFact
  , pattern SmtProofEvidence
  , pattern RuntimeEvidencePassedFact
  , pattern RuntimeExecutionEvidenceArtifact
  , pattern RuntimeExecutionEvidencePassedFact
  , pattern RuntimeExecutionSemanticsExpressedFact
  , pattern RuntimePlanBuildEvidenceArtifact
  , pattern RuntimePlanBuildEvidencePassedFact
  , pattern SmtProofPassedFact
  , pattern RuntimeValidationEvidenceArtifact
  , pattern RuntimeValidationEvidencePassedFact
  , pattern RuntimePlanBuildExpressedFact
  , pattern RuntimeTypesExpressedFact
  , pattern RuntimeValidationExpressedFact
  , pattern ValidateRuntimeFlow
  , pattern ValidateStaticContractsFlow
  ) where

import Bootstrap.Effect
  ( EffectName (..)
  , SendName (..)
  , TypeName (..)
  )
import Bootstrap.Workflow
  ( EffectSystemName (..)
  , Interceptor (..)
  , WorkflowFact (..)
  )

pattern FrameworkCoreFlow :: EffectSystemName
pattern FrameworkCoreFlow = EffectSystemName "FrameworkCoreFlow"

pattern CoreSurfaceFormalizationFlow :: EffectSystemName
pattern CoreSurfaceFormalizationFlow = EffectSystemName "CoreSurfaceFormalizationFlow"

pattern CoreSurfaceModulesFormalizationFlow :: EffectSystemName
pattern CoreSurfaceModulesFormalizationFlow = EffectSystemName "CoreSurfaceModulesFormalizationFlow"

pattern ValidateStaticContractsFlow :: EffectSystemName
pattern ValidateStaticContractsFlow = EffectSystemName "ValidateStaticContractsFlow"

pattern BuildProofFlow :: EffectSystemName
pattern BuildProofFlow = EffectSystemName "BuildProofFlow"

pattern ValidateRuntimeFlow :: EffectSystemName
pattern ValidateRuntimeFlow = EffectSystemName "ValidateRuntimeFlow"

pattern RuntimeBranchExpressionFlow :: EffectSystemName
pattern RuntimeBranchExpressionFlow = EffectSystemName "RuntimeBranchExpressionFlow"

pattern PublishBootstrapReportFlow :: EffectSystemName
pattern PublishBootstrapReportFlow = EffectSystemName "PublishFrameworkCoreReportFlow"

pattern FrameworkCoreTraceMiddleware :: Interceptor
pattern FrameworkCoreTraceMiddleware = Interceptor "FrameworkCoreTraceMiddleware"

pattern PackageModulesDiscoveredFact :: WorkflowFact
pattern PackageModulesDiscoveredFact = WorkflowFact "PackageModulesDiscoveredFact"

pattern FrameworkCoreModulesClassifiedFact :: WorkflowFact
pattern FrameworkCoreModulesClassifiedFact = WorkflowFact "FrameworkCoreModulesClassifiedFact"

pattern CoreHostModulesClassifiedFact :: WorkflowFact
pattern CoreHostModulesClassifiedFact = WorkflowFact "CoreHostModulesClassifiedFact"

pattern CoreSurfaceCatalogLoadedFact :: WorkflowFact
pattern CoreSurfaceCatalogLoadedFact = WorkflowFact "CoreSurfaceCatalogLoadedFact"

pattern CoreSurfaceAstFormalizedFact :: WorkflowFact
pattern CoreSurfaceAstFormalizedFact = WorkflowFact "CoreSurfaceAstFormalizedFact"

pattern CoreSurfaceEffectTheoryFormalizedFact :: WorkflowFact
pattern CoreSurfaceEffectTheoryFormalizedFact = WorkflowFact "CoreSurfaceEffectTheoryFormalizedFact"

pattern CoreSurfaceFormalizedFact :: WorkflowFact
pattern CoreSurfaceFormalizedFact = WorkflowFact "CoreSurfaceFormalizedFact"

pattern ImportGraphBuiltFact :: WorkflowFact
pattern ImportGraphBuiltFact = WorkflowFact "ImportGraphBuiltFact"

pattern CoreBoundaryValidatedFact :: WorkflowFact
pattern CoreBoundaryValidatedFact = WorkflowFact "CoreBoundaryValidatedFact"

pattern FrontendBoundaryValidatedFact :: WorkflowFact
pattern FrontendBoundaryValidatedFact = WorkflowFact "FrontendBoundaryValidatedFact"

pattern LanguageSpecValidatedFact :: WorkflowFact
pattern LanguageSpecValidatedFact = WorkflowFact "LanguageSpecValidatedFact"

pattern ElaborationContractValidatedFact :: WorkflowFact
pattern ElaborationContractValidatedFact = WorkflowFact "ElaborationContractValidatedFact"

pattern MinimalCoreReportBuiltFact :: WorkflowFact
pattern MinimalCoreReportBuiltFact = WorkflowFact "MinimalCoreReportBuiltFact"

pattern ConstraintIRBuiltFact :: WorkflowFact
pattern ConstraintIRBuiltFact = WorkflowFact "ConstraintIRBuiltFact"

pattern SmtProofPassedFact :: WorkflowFact
pattern SmtProofPassedFact = WorkflowFact "SmtProofPassedFact"

pattern RuntimeEvidencePassedFact :: WorkflowFact
pattern RuntimeEvidencePassedFact = WorkflowFact "RuntimeEvidencePassedFact"

pattern RuntimePlanBuiltFact :: WorkflowFact
pattern RuntimePlanBuiltFact = WorkflowFact "RuntimePlanBuiltFact"

pattern RuntimeFactRuleClosureValidatedFact :: WorkflowFact
pattern RuntimeFactRuleClosureValidatedFact = WorkflowFact "RuntimeFactRuleClosureValidatedFact"

pattern RuntimeArtifactClosureValidatedFact :: WorkflowFact
pattern RuntimeArtifactClosureValidatedFact = WorkflowFact "RuntimeArtifactClosureValidatedFact"

pattern RuntimeSendBoundaryCoveredFact :: WorkflowFact
pattern RuntimeSendBoundaryCoveredFact = WorkflowFact "RuntimeSendBoundaryCoveredFact"

pattern RuntimeHandlerRegistryValidatedFact :: WorkflowFact
pattern RuntimeHandlerRegistryValidatedFact = WorkflowFact "RuntimeHandlerRegistryValidatedFact"

pattern RuntimeTransformRegistryValidatedFact :: WorkflowFact
pattern RuntimeTransformRegistryValidatedFact = WorkflowFact "RuntimeTransformRegistryValidatedFact"

pattern RuntimePlanBuildEvidencePassedFact :: WorkflowFact
pattern RuntimePlanBuildEvidencePassedFact = WorkflowFact "RuntimePlanBuildEvidencePassedFact"

pattern RuntimeValidationEvidencePassedFact :: WorkflowFact
pattern RuntimeValidationEvidencePassedFact = WorkflowFact "RuntimeValidationEvidencePassedFact"

pattern RuntimeExecutionEvidencePassedFact :: WorkflowFact
pattern RuntimeExecutionEvidencePassedFact = WorkflowFact "RuntimeExecutionEvidencePassedFact"

pattern RuntimeConcurrencyEvidencePassedFact :: WorkflowFact
pattern RuntimeConcurrencyEvidencePassedFact = WorkflowFact "RuntimeConcurrencyEvidencePassedFact"

pattern RuntimeErrorDispatchValidatedFact :: WorkflowFact
pattern RuntimeErrorDispatchValidatedFact = WorkflowFact "RuntimeErrorDispatchValidatedFact"

pattern RuntimeRetryPolicyValidatedFact :: WorkflowFact
pattern RuntimeRetryPolicyValidatedFact = WorkflowFact "RuntimeRetryPolicyValidatedFact"

pattern RuntimeIdempotencyPolicyValidatedFact :: WorkflowFact
pattern RuntimeIdempotencyPolicyValidatedFact = WorkflowFact "RuntimeIdempotencyPolicyValidatedFact"

pattern RuntimeDiagnosisEvidencePassedFact :: WorkflowFact
pattern RuntimeDiagnosisEvidencePassedFact = WorkflowFact "RuntimeDiagnosisEvidencePassedFact"

pattern RuntimeBackendParityEvidencePassedFact :: WorkflowFact
pattern RuntimeBackendParityEvidencePassedFact = WorkflowFact "RuntimeBackendParityEvidencePassedFact"

pattern FrameworkCoreFrontendGeneratedFact :: WorkflowFact
pattern FrameworkCoreFrontendGeneratedFact = WorkflowFact "FrameworkCoreFrontendGeneratedFact"

pattern RegistryCodegenEvidencePassedFact :: WorkflowFact
pattern RegistryCodegenEvidencePassedFact = WorkflowFact "RegistryCodegenEvidencePassedFact"

pattern SelfArtifactManifestEvidencePassedFact :: WorkflowFact
pattern SelfArtifactManifestEvidencePassedFact = WorkflowFact "SelfArtifactManifestEvidencePassedFact"

pattern AstStructureExpressedFact :: WorkflowFact
pattern AstStructureExpressedFact = WorkflowFact "AstStructureExpressedFact"

pattern EffectTheoryDslExpressedFact :: WorkflowFact
pattern EffectTheoryDslExpressedFact = WorkflowFact "EffectTheoryDslExpressedFact"

pattern RuntimeInterpreterExpressedFact :: WorkflowFact
pattern RuntimeInterpreterExpressedFact = WorkflowFact "RuntimeInterpreterExpressedFact"

pattern RuntimeTypesExpressedFact :: WorkflowFact
pattern RuntimeTypesExpressedFact = WorkflowFact "RuntimeTypesExpressedFact"

pattern RuntimePlanBuildExpressedFact :: WorkflowFact
pattern RuntimePlanBuildExpressedFact = WorkflowFact "RuntimePlanBuildExpressedFact"

pattern RuntimeValidationExpressedFact :: WorkflowFact
pattern RuntimeValidationExpressedFact = WorkflowFact "RuntimeValidationExpressedFact"

pattern RuntimeExecutionSemanticsExpressedFact :: WorkflowFact
pattern RuntimeExecutionSemanticsExpressedFact = WorkflowFact "RuntimeExecutionSemanticsExpressedFact"

pattern RuntimeConcurrencySemanticsExpressedFact :: WorkflowFact
pattern RuntimeConcurrencySemanticsExpressedFact = WorkflowFact "RuntimeConcurrencySemanticsExpressedFact"

pattern RuntimeDiagnosisExpressedFact :: WorkflowFact
pattern RuntimeDiagnosisExpressedFact = WorkflowFact "RuntimeDiagnosisExpressedFact"

pattern RuntimeBackendAdapterExpressedFact :: WorkflowFact
pattern RuntimeBackendAdapterExpressedFact = WorkflowFact "RuntimeBackendAdapterExpressedFact"

pattern RuntimeBackendParityExpressedFact :: WorkflowFact
pattern RuntimeBackendParityExpressedFact = WorkflowFact "RuntimeBackendParityExpressedFact"

pattern BuildAppValidationExpressedFact :: WorkflowFact
pattern BuildAppValidationExpressedFact = WorkflowFact "BuildAppValidationExpressedFact"

pattern BoundaryChecksExpressedFact :: WorkflowFact
pattern BoundaryChecksExpressedFact = WorkflowFact "BoundaryChecksExpressedFact"

pattern HyloRenderingProofSurfaceExpressedFact :: WorkflowFact
pattern HyloRenderingProofSurfaceExpressedFact = WorkflowFact "HyloRenderingProofSurfaceExpressedFact"

pattern RuntimeFactClosureExpressedFact :: WorkflowFact
pattern RuntimeFactClosureExpressedFact = WorkflowFact "RuntimeFactClosureExpressedFact"

pattern RegistryCodegenExpressedFact :: WorkflowFact
pattern RegistryCodegenExpressedFact = WorkflowFact "RegistryCodegenExpressedFact"

pattern SelfArtifactManifestExpressedFact :: WorkflowFact
pattern SelfArtifactManifestExpressedFact = WorkflowFact "SelfArtifactManifestExpressedFact"

pattern FrameworkCoreNativeValidatedFact :: WorkflowFact
pattern FrameworkCoreNativeValidatedFact = WorkflowFact "FrameworkCoreNativeValidatedFact"

pattern FrameworkCoreExpressedFact :: WorkflowFact
pattern FrameworkCoreExpressedFact = WorkflowFact "FrameworkCoreExpressedFact"

pattern FrameworkCoreReportPublishedFact :: WorkflowFact
pattern FrameworkCoreReportPublishedFact = WorkflowFact "FrameworkCoreReportPublishedFact"

pattern CoreModuleEffect :: EffectName
pattern CoreModuleEffect = EffectName "CoreModuleEffect"

pattern CoreBoundaryEffect :: EffectName
pattern CoreBoundaryEffect = EffectName "CoreBoundaryEffect"

pattern CoreLanguageEffect :: EffectName
pattern CoreLanguageEffect = EffectName "CoreLanguageEffect"

pattern CoreProofEffect :: EffectName
pattern CoreProofEffect = EffectName "CoreProofEffect"

pattern CoreRegistryEffect :: EffectName
pattern CoreRegistryEffect = EffectName "CoreRegistryEffect"

pattern CoreArtifactEffect :: EffectName
pattern CoreArtifactEffect = EffectName "CoreArtifactEffect"

pattern CoreRuntimeEffect :: EffectName
pattern CoreRuntimeEffect = EffectName "CoreRuntimeEffect"

pattern CoreSurfaceEffect :: EffectName
pattern CoreSurfaceEffect = EffectName "CoreSurfaceEffect"

pattern CoreReportEffect :: EffectName
pattern CoreReportEffect = EffectName "CoreReportEffect"

pattern CoreExpressionEffect :: EffectName
pattern CoreExpressionEffect = EffectName "CoreExpressionEffect"

pattern PackageModuleCatalog :: TypeName
pattern PackageModuleCatalog = TypeName "PackageModuleCatalog"

pattern FrameworkCoreModuleCatalog :: TypeName
pattern FrameworkCoreModuleCatalog = TypeName "FrameworkCoreModuleCatalog"

pattern CoreHostModuleCatalog :: TypeName
pattern CoreHostModuleCatalog = TypeName "CoreHostModuleCatalog"

pattern ImportGraphArtifact :: TypeName
pattern ImportGraphArtifact = TypeName "ImportGraphArtifact"

pattern CoreBoundaryEvidence :: TypeName
pattern CoreBoundaryEvidence = TypeName "CoreBoundaryEvidence"

pattern FrontendBoundaryEvidence :: TypeName
pattern FrontendBoundaryEvidence = TypeName "FrontendBoundaryEvidence"

pattern LanguageSpecEvidence :: TypeName
pattern LanguageSpecEvidence = TypeName "LanguageSpecEvidence"

pattern ElaborationContractEvidence :: TypeName
pattern ElaborationContractEvidence = TypeName "ElaborationContractEvidence"

pattern MinimalCoreReportArtifact :: TypeName
pattern MinimalCoreReportArtifact = TypeName "MinimalCoreReportArtifact"

pattern ConstraintIRArtifact :: TypeName
pattern ConstraintIRArtifact = TypeName "ConstraintIRArtifact"

pattern SmtProofEvidence :: TypeName
pattern SmtProofEvidence = TypeName "SmtProofEvidence"

pattern RuntimeEvidenceArtifact :: TypeName
pattern RuntimeEvidenceArtifact = TypeName "RuntimeEvidenceArtifact"

pattern RuntimePlanArtifact :: TypeName
pattern RuntimePlanArtifact = TypeName "RuntimePlanArtifact"

pattern RuntimeFactRuleClosureArtifact :: TypeName
pattern RuntimeFactRuleClosureArtifact = TypeName "RuntimeFactRuleClosureArtifact"

pattern RuntimeArtifactClosureArtifact :: TypeName
pattern RuntimeArtifactClosureArtifact = TypeName "RuntimeArtifactClosureArtifact"

pattern RuntimeSendBoundaryCoverageArtifact :: TypeName
pattern RuntimeSendBoundaryCoverageArtifact = TypeName "RuntimeSendBoundaryCoverageArtifact"

pattern RuntimeHandlerRegistryArtifact :: TypeName
pattern RuntimeHandlerRegistryArtifact = TypeName "RuntimeHandlerRegistryArtifact"

pattern RuntimeTransformRegistryArtifact :: TypeName
pattern RuntimeTransformRegistryArtifact = TypeName "RuntimeTransformRegistryArtifact"

pattern RuntimePlanBuildEvidenceArtifact :: TypeName
pattern RuntimePlanBuildEvidenceArtifact = TypeName "RuntimePlanBuildEvidenceArtifact"

pattern RuntimeValidationEvidenceArtifact :: TypeName
pattern RuntimeValidationEvidenceArtifact = TypeName "RuntimeValidationEvidenceArtifact"

pattern RuntimeExecutionEvidenceArtifact :: TypeName
pattern RuntimeExecutionEvidenceArtifact = TypeName "RuntimeExecutionEvidenceArtifact"

pattern RuntimeConcurrencyEvidenceArtifact :: TypeName
pattern RuntimeConcurrencyEvidenceArtifact = TypeName "RuntimeConcurrencyEvidenceArtifact"

pattern RuntimeErrorDispatchArtifact :: TypeName
pattern RuntimeErrorDispatchArtifact = TypeName "RuntimeErrorDispatchArtifact"

pattern RuntimeRetryPolicyArtifact :: TypeName
pattern RuntimeRetryPolicyArtifact = TypeName "RuntimeRetryPolicyArtifact"

pattern RuntimeIdempotencyPolicyArtifact :: TypeName
pattern RuntimeIdempotencyPolicyArtifact = TypeName "RuntimeIdempotencyPolicyArtifact"

pattern RuntimeDiagnosisEvidenceArtifact :: TypeName
pattern RuntimeDiagnosisEvidenceArtifact = TypeName "RuntimeDiagnosisEvidenceArtifact"

pattern RuntimeBackendParityEvidenceArtifact :: TypeName
pattern RuntimeBackendParityEvidenceArtifact = TypeName "RuntimeBackendParityEvidenceArtifact"

pattern FrameworkCoreFrontendArtifact :: TypeName
pattern FrameworkCoreFrontendArtifact = TypeName "FrameworkCoreFrontendArtifact"

pattern RegistryCodegenArtifact :: TypeName
pattern RegistryCodegenArtifact = TypeName "RegistryCodegenArtifact"

pattern SelfArtifactManifestArtifact :: TypeName
pattern SelfArtifactManifestArtifact = TypeName "SelfArtifactManifestArtifact"

pattern FrameworkCoreReportArtifact :: TypeName
pattern FrameworkCoreReportArtifact = TypeName "FrameworkCoreReportArtifact"

pattern LoadCoreSurfaceCatalog :: SendName
pattern LoadCoreSurfaceCatalog = SendName "LoadCoreSurfaceCatalog"

pattern FormalizeCoreSurfaceModule :: SendName
pattern FormalizeCoreSurfaceModule = SendName "FormalizeCoreSurfaceModule"

pattern FormalizeCoreSurfaceCapability :: SendName
pattern FormalizeCoreSurfaceCapability = SendName "FormalizeCoreSurfaceCapability"

pattern ComposeCoreSurfaceAst :: SendName
pattern ComposeCoreSurfaceAst = SendName "ComposeCoreSurfaceAst"

pattern CompileCoreSurfaceEffectTheory :: SendName
pattern CompileCoreSurfaceEffectTheory = SendName "CompileCoreSurfaceEffectTheory"

pattern ReadPackageFiles :: SendName
pattern ReadPackageFiles = SendName "ReadPackageFiles"

pattern ExtractRealImportGraph :: SendName
pattern ExtractRealImportGraph = SendName "ExtractRealImportGraph"

pattern CheckCoreBoundary :: SendName
pattern CheckCoreBoundary = SendName "CheckCoreBoundary"

pattern CheckFrontendBoundary :: SendName
pattern CheckFrontendBoundary = SendName "CheckFrontendBoundary"

pattern CheckLanguageSpec :: SendName
pattern CheckLanguageSpec = SendName "CheckLanguageSpec"

pattern CheckElaborationContract :: SendName
pattern CheckElaborationContract = SendName "CheckElaborationContract"

pattern BuildMinimalCoreReport :: SendName
pattern BuildMinimalCoreReport = SendName "BuildMinimalCoreReport"

pattern GenerateConstraintIR :: SendName
pattern GenerateConstraintIR = SendName "GenerateConstraintIR"

pattern RunSmtProof :: SendName
pattern RunSmtProof = SendName "RunSmtProof"

pattern BuildRuntimePlan :: SendName
pattern BuildRuntimePlan = SendName "BuildRuntimePlan"

pattern ValidateRuntimeFactRuleClosure :: SendName
pattern ValidateRuntimeFactRuleClosure = SendName "ValidateRuntimeFactRuleClosure"

pattern ValidateRuntimeArtifactClosure :: SendName
pattern ValidateRuntimeArtifactClosure = SendName "ValidateRuntimeArtifactClosure"

pattern ValidateRuntimeSendBoundaryCoverage :: SendName
pattern ValidateRuntimeSendBoundaryCoverage = SendName "ValidateRuntimeSendBoundaryCoverage"

pattern ValidateRuntimeHandlerRegistry :: SendName
pattern ValidateRuntimeHandlerRegistry = SendName "ValidateRuntimeHandlerRegistry"

pattern ValidateRuntimeTransformRegistry :: SendName
pattern ValidateRuntimeTransformRegistry = SendName "ValidateRuntimeTransformRegistry"

pattern ValidateRuntimeErrorDispatch :: SendName
pattern ValidateRuntimeErrorDispatch = SendName "ValidateRuntimeErrorDispatch"

pattern ValidateRuntimeRetryPolicy :: SendName
pattern ValidateRuntimeRetryPolicy = SendName "ValidateRuntimeRetryPolicy"

pattern ValidateRuntimeIdempotencyPolicy :: SendName
pattern ValidateRuntimeIdempotencyPolicy = SendName "ValidateRuntimeIdempotencyPolicy"

pattern RunRuntimeEvidence :: SendName
pattern RunRuntimeEvidence = SendName "RunRuntimeEvidence"

pattern RunRuntimePlanBuildEvidence :: SendName
pattern RunRuntimePlanBuildEvidence = SendName "RunRuntimePlanBuildEvidence"

pattern RunRuntimeValidationEvidence :: SendName
pattern RunRuntimeValidationEvidence = SendName "RunRuntimeValidationEvidence"

pattern RunRuntimeExecutionEvidence :: SendName
pattern RunRuntimeExecutionEvidence = SendName "RunRuntimeExecutionEvidence"

pattern RunRuntimeConcurrencyEvidence :: SendName
pattern RunRuntimeConcurrencyEvidence = SendName "RunRuntimeConcurrencyEvidence"

pattern RunRuntimeDiagnosisEvidence :: SendName
pattern RunRuntimeDiagnosisEvidence = SendName "RunRuntimeDiagnosisEvidence"

pattern RunRuntimeBackendParityEvidence :: SendName
pattern RunRuntimeBackendParityEvidence = SendName "RunRuntimeBackendParityEvidence"

pattern RunFrameworkCoreFrontendCodegenEvidence :: SendName
pattern RunFrameworkCoreFrontendCodegenEvidence = SendName "RunFrameworkCoreFrontendCodegenEvidence"

pattern RunRegistryCodegenEvidence :: SendName
pattern RunRegistryCodegenEvidence = SendName "RunRegistryCodegenEvidence"

pattern RunSelfArtifactManifestEvidence :: SendName
pattern RunSelfArtifactManifestEvidence = SendName "RunSelfArtifactManifestEvidence"

pattern PublishFrameworkCoreReport :: SendName
pattern PublishFrameworkCoreReport = SendName "PublishFrameworkCoreReport"
