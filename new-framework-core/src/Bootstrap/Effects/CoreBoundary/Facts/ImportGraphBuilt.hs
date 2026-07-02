module Bootstrap.Effects.CoreBoundary.Facts.ImportGraphBuilt
  ( importGraphBuiltFact
  ) where

import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , fact
  , make
  , uses
  )

importGraphBuiltFact :: EffectSection
importGraphBuiltFact =
  fact ImportGraphBuiltFact
    [ uses ExtractRealImportGraph
    , make ImportGraphArtifact
    ]
