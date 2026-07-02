{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Effects.CoreProof.Registration.Effect
  ( coreProofEffect
  ) where

import Bootstrap.Effects.CoreProof.Facts.ConstraintIRBuilt
  ( constraintIRBuiltFact )
import Bootstrap.Effects.CoreProof.Facts.MinimalCoreReportBuilt
  ( minimalCoreReportBuiltFact )
import Bootstrap.Effects.CoreProof.Facts.SmtProofPassed
  ( smtProofPassedFact )
import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , EffectUnit
  , effect
  , externalMake
  , pattern NoInput
  )

coreProofEffect :: EffectUnit
coreProofEffect =
  effect CoreProofEffect
    [ minimalCoreReportBuiltFact
    , constraintIRBuiltFact
    , smtProofPassedFact
    , buildMinimalCoreReportBoundary
    , generateConstraintIRBoundary
    , runSmtProofBoundary
    ]

buildMinimalCoreReportBoundary :: EffectSection
buildMinimalCoreReportBoundary =
  externalMake BuildMinimalCoreReport NoInput MinimalCoreReportArtifact

generateConstraintIRBoundary :: EffectSection
generateConstraintIRBoundary =
  externalMake GenerateConstraintIR MinimalCoreReportArtifact ConstraintIRArtifact

runSmtProofBoundary :: EffectSection
runSmtProofBoundary =
  externalMake RunSmtProof ConstraintIRArtifact SmtProofEvidence
