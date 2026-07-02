module Bootstrap.Effects.CoreArtifact.Registration.Effect
  ( coreArtifactEffect
  ) where

import Bootstrap.Effects.CoreArtifact.Facts.SelfArtifactManifestEvidencePassed
  ( selfArtifactManifestEvidencePassedFact )
import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , EffectUnit
  , effect
  , externalMake
  )

coreArtifactEffect :: EffectUnit
coreArtifactEffect =
  effect CoreArtifactEffect
    [ selfArtifactManifestEvidencePassedFact
    , runSelfArtifactManifestEvidenceBoundary
    ]

runSelfArtifactManifestEvidenceBoundary :: EffectSection
runSelfArtifactManifestEvidenceBoundary =
  externalMake RunSelfArtifactManifestEvidence RegistryCodegenArtifact SelfArtifactManifestArtifact
