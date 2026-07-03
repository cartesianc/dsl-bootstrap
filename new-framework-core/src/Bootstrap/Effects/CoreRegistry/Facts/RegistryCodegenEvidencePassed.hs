module Bootstrap.Effects.CoreRegistry.Facts.RegistryCodegenEvidencePassed
  ( frameworkCoreFrontendGeneratedFact
  , registryCodegenEvidencePassedFact
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

registryCodegenEvidencePassedFact :: EffectSection
registryCodegenEvidencePassedFact =
  fact RegistryCodegenEvidencePassedFact
    [ needs FrameworkCoreFrontendGeneratedFact
    , needs MinimalCoreReportBuiltFact
    , Effect.take FrameworkCoreFrontendArtifact
    , Effect.take MinimalCoreReportArtifact
    , uses RunRegistryCodegenEvidence
    , make RegistryCodegenArtifact
    ]

frameworkCoreFrontendGeneratedFact :: EffectSection
frameworkCoreFrontendGeneratedFact =
  fact FrameworkCoreFrontendGeneratedFact
    [ needs MinimalCoreReportBuiltFact
    , Effect.take MinimalCoreReportArtifact
    , uses RunFrameworkCoreFrontendCodegenEvidence
    , make FrameworkCoreFrontendArtifact
    ]
