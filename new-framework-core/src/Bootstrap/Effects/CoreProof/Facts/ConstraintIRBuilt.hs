module Bootstrap.Effects.CoreProof.Facts.ConstraintIRBuilt
  ( constraintIRBuiltFact
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

constraintIRBuiltFact :: EffectSection
constraintIRBuiltFact =
  fact ConstraintIRBuiltFact
    [ needs MinimalCoreReportBuiltFact
    , Effect.take MinimalCoreReportArtifact
    , uses GenerateConstraintIR
    , make ConstraintIRArtifact
    ]
