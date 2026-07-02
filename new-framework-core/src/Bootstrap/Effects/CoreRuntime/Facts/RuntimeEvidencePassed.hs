module Bootstrap.Effects.CoreRuntime.Facts.RuntimeEvidencePassed
  ( runtimeEvidencePassedFact
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

runtimeEvidencePassedFact :: EffectSection
runtimeEvidencePassedFact =
  fact RuntimeEvidencePassedFact
    [ needs MinimalCoreReportBuiltFact
    , Effect.take MinimalCoreReportArtifact
    , uses RunRuntimeEvidence
    , make RuntimeEvidenceArtifact
    ]
