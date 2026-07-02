{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Effects.CoreLanguage.Registration.Effect
  ( coreLanguageEffect
  ) where

import Bootstrap.Effects.CoreLanguage.Facts.ElaborationContractValidated
  ( elaborationContractValidatedFact )
import Bootstrap.Effects.CoreLanguage.Facts.LanguageSpecValidated
  ( languageSpecValidatedFact )
import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , EffectUnit
  , effect
  , externalMake
  , pattern NoInput
  )

coreLanguageEffect :: EffectUnit
coreLanguageEffect =
  effect CoreLanguageEffect
    [ languageSpecValidatedFact
    , elaborationContractValidatedFact
    , checkLanguageSpecBoundary
    , checkElaborationContractBoundary
    ]

checkLanguageSpecBoundary :: EffectSection
checkLanguageSpecBoundary =
  externalMake CheckLanguageSpec NoInput LanguageSpecEvidence

checkElaborationContractBoundary :: EffectSection
checkElaborationContractBoundary =
  externalMake CheckElaborationContract LanguageSpecEvidence ElaborationContractEvidence
