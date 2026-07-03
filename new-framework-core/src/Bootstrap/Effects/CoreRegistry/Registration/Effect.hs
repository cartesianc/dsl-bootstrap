module Bootstrap.Effects.CoreRegistry.Registration.Effect
  ( coreRegistryEffect
  ) where

import Bootstrap.Effects.CoreRegistry.Facts.RegistryCodegenEvidencePassed
  ( frameworkCoreFrontendGeneratedFact
  , registryCodegenEvidencePassedFact
  )
import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , EffectUnit
  , effect
  , externalMake
  )

coreRegistryEffect :: EffectUnit
coreRegistryEffect =
  effect CoreRegistryEffect
    [ frameworkCoreFrontendGeneratedFact
    , registryCodegenEvidencePassedFact
    , runFrameworkCoreFrontendCodegenEvidenceBoundary
    , runRegistryCodegenEvidenceBoundary
    ]

runFrameworkCoreFrontendCodegenEvidenceBoundary :: EffectSection
runFrameworkCoreFrontendCodegenEvidenceBoundary =
  externalMake RunFrameworkCoreFrontendCodegenEvidence MinimalCoreReportArtifact FrameworkCoreFrontendArtifact

runRegistryCodegenEvidenceBoundary :: EffectSection
runRegistryCodegenEvidenceBoundary =
  externalMake RunRegistryCodegenEvidence FrameworkCoreFrontendArtifact RegistryCodegenArtifact
