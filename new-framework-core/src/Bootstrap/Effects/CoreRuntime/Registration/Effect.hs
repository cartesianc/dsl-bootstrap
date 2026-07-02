{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Effects.CoreRuntime.Registration.Effect
  ( coreRuntimeEffect
  ) where

import Bootstrap.Effects.CoreRuntime.Facts.RuntimeSmokePassed
  ( runtimeSmokePassedFact )
import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , EffectUnit
  , effect
  , externalMake
  )

coreRuntimeEffect :: EffectUnit
coreRuntimeEffect =
  effect CoreRuntimeEffect
    [ runtimeSmokePassedFact
    , runRuntimeSmokeBoundary
    ]

runRuntimeSmokeBoundary :: EffectSection
runRuntimeSmokeBoundary =
  externalMake RunRuntimeSmoke MinimalCoreReportArtifact RuntimeSmokeEvidence
