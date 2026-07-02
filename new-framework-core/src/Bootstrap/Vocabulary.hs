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
  , pattern RunRegistryCodegenEvidence
  , pattern RuntimeEvidenceArtifact
  , pattern RunRuntimeEvidence
  , pattern RunSmtProof
  , pattern SmtProofEvidence
  , pattern RuntimeEvidencePassedFact
  , pattern SmtProofPassedFact
  , pattern ValidateRuntimeFlow
  , pattern ValidateStaticContractsFlow
  ) where

import Bootstrap.Effect
  ( EffectName (..)
  , SendName (..)
  , TypeName (..)
  )
import Bootstrap.Workflow
  ( Interceptor (..)
  , WorkflowFact (..)
  , WorkflowName (..)
  )

pattern FrameworkCoreFlow :: WorkflowName
pattern FrameworkCoreFlow = WorkflowName "FrameworkCoreFlow"

pattern CoreSurfaceFormalizationFlow :: WorkflowName
pattern CoreSurfaceFormalizationFlow = WorkflowName "CoreSurfaceFormalizationFlow"

pattern CoreSurfaceModulesFormalizationFlow :: WorkflowName
pattern CoreSurfaceModulesFormalizationFlow = WorkflowName "CoreSurfaceModulesFormalizationFlow"

pattern ValidateStaticContractsFlow :: WorkflowName
pattern ValidateStaticContractsFlow = WorkflowName "ValidateStaticContractsFlow"

pattern BuildProofFlow :: WorkflowName
pattern BuildProofFlow = WorkflowName "BuildProofFlow"

pattern ValidateRuntimeFlow :: WorkflowName
pattern ValidateRuntimeFlow = WorkflowName "ValidateRuntimeFlow"

pattern PublishBootstrapReportFlow :: WorkflowName
pattern PublishBootstrapReportFlow = WorkflowName "PublishFrameworkCoreReportFlow"

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

pattern RegistryCodegenEvidencePassedFact :: WorkflowFact
pattern RegistryCodegenEvidencePassedFact = WorkflowFact "RegistryCodegenEvidencePassedFact"

pattern AstStructureExpressedFact :: WorkflowFact
pattern AstStructureExpressedFact = WorkflowFact "AstStructureExpressedFact"

pattern EffectTheoryDslExpressedFact :: WorkflowFact
pattern EffectTheoryDslExpressedFact = WorkflowFact "EffectTheoryDslExpressedFact"

pattern RuntimeInterpreterExpressedFact :: WorkflowFact
pattern RuntimeInterpreterExpressedFact = WorkflowFact "RuntimeInterpreterExpressedFact"

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

pattern RegistryCodegenArtifact :: TypeName
pattern RegistryCodegenArtifact = TypeName "RegistryCodegenArtifact"

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

pattern RunRuntimeEvidence :: SendName
pattern RunRuntimeEvidence = SendName "RunRuntimeEvidence"

pattern RunRegistryCodegenEvidence :: SendName
pattern RunRegistryCodegenEvidence = SendName "RunRegistryCodegenEvidence"

pattern PublishFrameworkCoreReport :: SendName
pattern PublishFrameworkCoreReport = SendName "PublishFrameworkCoreReport"
