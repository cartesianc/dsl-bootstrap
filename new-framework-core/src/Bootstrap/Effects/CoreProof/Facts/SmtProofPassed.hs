module Bootstrap.Effects.CoreProof.Facts.SmtProofPassed
  ( smtProofPassedFact
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

smtProofPassedFact :: EffectSection
smtProofPassedFact =
  fact SmtProofPassedFact
    [ needs ConstraintIRBuiltFact
    , Effect.take ConstraintIRArtifact
    , uses RunSmtProof
    , make SmtProofEvidence
    ]
