module Bootstrap.Effects.CoreArtifact.Facts.SelfArtifactManifestEvidencePassed
  ( selfArtifactManifestEvidencePassedFact
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

selfArtifactManifestEvidencePassedFact :: EffectSection
selfArtifactManifestEvidencePassedFact =
  fact SelfArtifactManifestEvidencePassedFact
    [ needs RegistryCodegenEvidencePassedFact
    , Effect.take RegistryCodegenArtifact
    , uses RunSelfArtifactManifestEvidence
    , make SelfArtifactManifestArtifact
    ]
