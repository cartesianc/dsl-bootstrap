module Bootstrap.Effects.CoreLanguage.Facts.LanguageSpecValidated
  ( languageSpecValidatedFact
  ) where

import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , fact
  , make
  , uses
  )

languageSpecValidatedFact :: EffectSection
languageSpecValidatedFact =
  fact LanguageSpecValidatedFact
    [ uses CheckLanguageSpec
    , make LanguageSpecEvidence
    ]
