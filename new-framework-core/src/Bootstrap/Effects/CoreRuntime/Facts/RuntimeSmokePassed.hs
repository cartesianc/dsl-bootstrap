module Bootstrap.Effects.CoreRuntime.Facts.RuntimeSmokePassed
  ( runtimeSmokePassedFact
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

runtimeSmokePassedFact :: EffectSection
runtimeSmokePassedFact =
  fact RuntimeSmokePassedFact
    [ needs MinimalCoreReportBuiltFact
    , Effect.take MinimalCoreReportArtifact
    , uses RunRuntimeSmoke
    , make RuntimeSmokeEvidence
    ]
