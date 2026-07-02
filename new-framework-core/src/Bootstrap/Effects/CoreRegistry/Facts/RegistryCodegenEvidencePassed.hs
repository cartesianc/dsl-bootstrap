module Bootstrap.Effects.CoreRegistry.Facts.RegistryCodegenEvidencePassed
  ( registryCodegenEvidencePassedFact
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
    [ needs MinimalCoreReportBuiltFact
    , Effect.take MinimalCoreReportArtifact
    , uses RunRegistryCodegenEvidence
    , make RegistryCodegenArtifact
    ]
