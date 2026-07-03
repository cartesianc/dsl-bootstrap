{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Handle where

import Blueprint

type UserModule = WorkflowComponent

type UserHook = Middleware

type Onboarding = WorkflowComponent

-- plugin: userModule
userModule :: UserModule
userModule =
  run (effectSystem UserModuleFlow [UserKnownFact])

-- plugin: onboarding
onboarding :: Onboarding
onboarding =
  userModule

-- plugin: userHook
userHook :: UserHook
userHook =
  middleware UserFlowMiddleware onboarding
