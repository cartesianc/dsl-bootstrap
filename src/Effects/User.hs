module Effects.User
  ( userEffect
  ) where

import Effects.EffectTheory

-- effect: userEffect
userEffect :: EffectUnit
userEffect =
  effect UserEffect
    [ fact UserNameAskedFact
        [ uses AskUserName
        ]
    , fact UserGreetedFact
        [ needs UserNameAskedFact
        ]
    , fact UserKnownFact
        [ needs UserNameAskedFact
        , needs UserGreetedFact
        , uses RememberUser
        ]
    , send AskUserName NoInput UserName
    , send RememberUser UserRecord Unit
    , profile Production
        [ implement AskUserName RuntimeAskUserName
        , implement RememberUser RuntimeRememberUser
        ]
    , profile Test
        [ implement AskUserName MockAskUserName
        , implement RememberUser MockRememberUser
        ]
    ]
