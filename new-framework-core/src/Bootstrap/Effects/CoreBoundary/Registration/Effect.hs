{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Effects.CoreBoundary.Registration.Effect
  ( coreBoundaryEffect
  ) where

import Bootstrap.Effects.CoreBoundary.Facts.CoreBoundaryValidated
  ( coreBoundaryValidatedFact )
import Bootstrap.Effects.CoreBoundary.Facts.FrontendBoundaryValidated
  ( frontendBoundaryValidatedFact )
import Bootstrap.Effects.CoreBoundary.Facts.ImportGraphBuilt
  ( importGraphBuiltFact )
import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , EffectUnit
  , effect
  , externalMake
  , pattern NoInput
  )

coreBoundaryEffect :: EffectUnit
coreBoundaryEffect =
  effect CoreBoundaryEffect
    [ importGraphBuiltFact
    , coreBoundaryValidatedFact
    , frontendBoundaryValidatedFact
    , extractRealImportGraphBoundary
    , checkCoreBoundaryBoundary
    , checkFrontendBoundaryBoundary
    ]

extractRealImportGraphBoundary :: EffectSection
extractRealImportGraphBoundary =
  externalMake ExtractRealImportGraph NoInput ImportGraphArtifact

checkCoreBoundaryBoundary :: EffectSection
checkCoreBoundaryBoundary =
  externalMake CheckCoreBoundary ImportGraphArtifact CoreBoundaryEvidence

checkFrontendBoundaryBoundary :: EffectSection
checkFrontendBoundaryBoundary =
  externalMake CheckFrontendBoundary ImportGraphArtifact FrontendBoundaryEvidence
