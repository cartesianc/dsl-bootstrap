{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Configuration where

import Framework.Workflow

type ConfigModule = Parallel

type ConfigHook = Middleware

-- plugin: configurationModule
configurationModule :: ConfigModule
configurationModule =
  parallel ConfigurationFlow
    [ fact [AppConfiguredFact]
    ]

-- plugin: configurationHook
configurationHook :: ConfigHook
configurationHook =
  middleware ConfigurationMiddleware configurationModule
