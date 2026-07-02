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
    [ Effect.fact RuntimeEvidencePassedFact
        [ Effect.needs MinimalCoreReportBuiltFact
        , Effect.take MinimalCoreReportArtifact
        , Effect.uses RunRuntimeEvidence
        , Effect.make RuntimeEvidenceArtifact
        ]
    , Effect.externalMake RunRuntimeEvidence MinimalCoreReportArtifact RuntimeEvidenceArtifact
    ]

coreRegistryEffect :: EffectUnit
coreRegistryEffect =
  Effect.effect CoreRegistryEffect
    [ Effect.fact RegistryCodegenEvidencePassedFact
        [ Effect.needs MinimalCoreReportBuiltFact
        , Effect.take MinimalCoreReportArtifact
        , Effect.uses RunRegistryCodegenEvidence
        , Effect.make RegistryCodegenArtifact
        ]
    , Effect.externalMake RunRegistryCodegenEvidence MinimalCoreReportArtifact RegistryCodegenArtifact
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
    , Effect.fact RuntimeInterpreterExpressedFact
        [ Effect.needs CoreSurfaceFormalizedFact
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
        [ Effect.needs RuntimeEvidencePassedFact
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
