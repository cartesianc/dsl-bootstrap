module Bootstrap.Effects.CoreReport.Facts.FrameworkCoreReportPublished
  ( frameworkCoreReportPublishedFact
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

frameworkCoreReportPublishedFact :: EffectSection
frameworkCoreReportPublishedFact =
  fact FrameworkCoreReportPublishedFact
    [ needs FrameworkCoreNativeValidatedFact
    , needs FrameworkCoreExpressedFact
    , needs RuntimeSmokePassedFact
    , Effect.take RuntimeSmokeEvidence
    , uses PublishFrameworkCoreReport
    , make FrameworkCoreReportArtifact
    ]
