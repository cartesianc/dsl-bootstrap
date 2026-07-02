module Bootstrap.Effects.CoreRegistry.Registration.Effect
  ( coreRegistryEffect
  ) where

import Bootstrap.Effects.CoreRegistry.Facts.RegistryCodegenEvidencePassed
  ( registryCodegenEvidencePassedFact )
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
    [ registryCodegenEvidencePassedFact
    , runRegistryCodegenEvidenceBoundary
    ]

runRegistryCodegenEvidenceBoundary :: EffectSection
runRegistryCodegenEvidenceBoundary =
  externalMake RunRegistryCodegenEvidence MinimalCoreReportArtifact RegistryCodegenArtifact
