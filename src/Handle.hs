module Handle
  ( UserModule
  , userModule
  , onboarding
  ) where

import Blueprint

type UserModule = Parallel

type Onboarding = Callback

-- plugin: userModule
userModule :: UserModule
userModule =
  parallel UserModuleFlow
    [ onboarding
    ]

-- plugin: onboarding
onboarding :: Onboarding
onboarding =
  callback
    [ RuntimePreparedFact
    ]
    ( middleware
        UserFlowMiddleware
        ( chain OnboardingFlow
            [ effect [UserNameAskedFact]
            , effect [UserGreetedFact]
            , effect [UserKnownFact]
            ]
        )
    )
