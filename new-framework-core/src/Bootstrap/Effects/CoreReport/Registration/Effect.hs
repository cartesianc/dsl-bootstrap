{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Effects.CoreReport.Registration.Effect
  ( coreReportEffect
  ) where

import Bootstrap.Effects.CoreReport.Facts.FrameworkCoreReportPublished
  ( frameworkCoreReportPublishedFact )
import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , EffectUnit
  , effect
  , externalMake
  )

coreReportEffect :: EffectUnit
coreReportEffect =
  effect CoreReportEffect
    [ frameworkCoreReportPublishedFact
    , publishFrameworkCoreReportBoundary
    ]

publishFrameworkCoreReportBoundary :: EffectSection
publishFrameworkCoreReportBoundary =
  externalMake PublishFrameworkCoreReport RuntimeSmokeEvidence FrameworkCoreReportArtifact
