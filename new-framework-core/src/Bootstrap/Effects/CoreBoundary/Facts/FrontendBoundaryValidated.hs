module Bootstrap.Effects.CoreBoundary.Facts.FrontendBoundaryValidated
  ( frontendBoundaryValidatedFact
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

frontendBoundaryValidatedFact :: EffectSection
frontendBoundaryValidatedFact =
  fact FrontendBoundaryValidatedFact
    [ needs ImportGraphBuiltFact
    , Effect.take ImportGraphArtifact
    , uses CheckFrontendBoundary
    , make FrontendBoundaryEvidence
    ]
