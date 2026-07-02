{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Handle where

import Blueprint

type UserModule = Parallel

type UserHook = Middleware

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
    ( chain OnboardingFlow
        [ fact [UserNameAskedFact]
        , fact [UserGreetedFact]
        , fact [UserKnownFact]
        ]
    )

-- plugin: userHook
userHook :: UserHook
userHook =
  middleware UserFlowMiddleware onboarding
