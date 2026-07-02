module Bootstrap.Effects.CoreLanguage.Facts.ElaborationContractValidated
  ( elaborationContractValidatedFact
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

elaborationContractValidatedFact :: EffectSection
elaborationContractValidatedFact =
  fact ElaborationContractValidatedFact
    [ needs LanguageSpecValidatedFact
    , Effect.take LanguageSpecEvidence
    , uses CheckElaborationContract
    , make ElaborationContractEvidence
    ]
