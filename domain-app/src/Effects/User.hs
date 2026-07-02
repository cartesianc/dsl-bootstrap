{-# LANGUAGE NoImplicitPrelude #-}

module Effects.User
  ( userEffect
  ) where

import Domain.EffectVocabulary
import Domain.Vocabulary
import Framework.Effect

-- effect: userEffect
userEffect :: EffectUnit
userEffect =
  effect UserEffect
    [ fact UserNameAskedFact
        [ uses AskUserName
        , error HandleUserNameError
        ]
    , fact UserGreetedFact
        [ needs UserNameAskedFact
        ]
    , fact UserKnownFact
        [ needs UserNameAskedFact
        , needs UserGreetedFact
        , uses RememberUser
        ]
    , externalMake AskUserName NoInput UserName
    , externalMake HandleUserNameError ErrorInput Unit
    , externalMake RememberUser UserName Unit
    ]
