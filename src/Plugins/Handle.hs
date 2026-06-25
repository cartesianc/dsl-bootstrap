module Plugins.Handle
  ( UserModule
  , userModule
  , onboarding
  ) where

import Blueprint

type UserModule = Parallel

type Onboarding = Wait

-- plugin: userModule
userModule :: UserModule
userModule =
  parallel UserModuleFlow
    [ onboarding
    ]

-- plugin: onboarding
onboarding :: Onboarding
onboarding =
  wait
    [ RuntimePreparedFact
    ]
    ( middleware
        UserFlowMiddleware
        ( chain OnboardingFlow
            [ fact [UserNameAskedFact]
            , fact [UserGreetedFact]
            , fact [UserKnownFact]
            ]
        )
    )
