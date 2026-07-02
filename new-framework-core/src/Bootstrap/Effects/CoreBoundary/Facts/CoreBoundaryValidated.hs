module Bootstrap.Effects.CoreBoundary.Facts.CoreBoundaryValidated
  ( coreBoundaryValidatedFact
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

coreBoundaryValidatedFact :: EffectSection
coreBoundaryValidatedFact =
  fact CoreBoundaryValidatedFact
    [ needs ImportGraphBuiltFact
    , Effect.take ImportGraphArtifact
    , uses CheckCoreBoundary
    , make CoreBoundaryEvidence
    ]
