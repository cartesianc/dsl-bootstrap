module Bootstrap.Effects.CoreProof.Facts.MinimalCoreReportBuilt
  ( minimalCoreReportBuiltFact
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

minimalCoreReportBuiltFact :: EffectSection
minimalCoreReportBuiltFact =
  fact MinimalCoreReportBuiltFact
    [ needs CoreBoundaryValidatedFact
    , needs FrontendBoundaryValidatedFact
    , needs LanguageSpecValidatedFact
    , needs ElaborationContractValidatedFact
    , Effect.take CoreBoundaryEvidence
    , Effect.take FrontendBoundaryEvidence
    , Effect.take LanguageSpecEvidence
    , Effect.take ElaborationContractEvidence
    , uses BuildMinimalCoreReport
    , make MinimalCoreReportArtifact
    ]
