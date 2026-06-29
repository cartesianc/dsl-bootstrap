module Effects.User
  ( userEffect
  ) where

import Framework.Effect

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
    , externalMake AskUserName NoInput UserName
    , externalMake RememberUser UserRecord Unit
    , profile Production
        [ implement AskUserName RuntimeAskUserName
        , implement RememberUser RuntimeRememberUser
        ]
    , profile Test
        [ implement AskUserName MockAskUserName
        , implement RememberUser MockRememberUser
        ]
    ]
