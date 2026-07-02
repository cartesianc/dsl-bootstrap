{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Effects.CoreRuntime.Registration.Effect
  ( coreRuntimeEffect
  ) where

import Bootstrap.Effects.CoreRuntime.Facts.RuntimeEvidencePassed
  ( runtimeEvidencePassedFact )
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
    [ runtimeEvidencePassedFact
    , runRuntimeEvidenceBoundary
    ]

runRuntimeEvidenceBoundary :: EffectSection
runRuntimeEvidenceBoundary =
  externalMake RunRuntimeEvidence MinimalCoreReportArtifact RuntimeEvidenceArtifact
