{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Boot where

import Framework.Workflow

type BootModule = Wait

type BootHook = Middleware

-- plugin: bootModule
bootModule :: BootModule
bootModule =
  wait
    [ AppConfiguredFact
    ]
    ( parallel BootPreparation
        [ fact [AppStartedFact]
        , fact [RuntimePreparedFact]
        ]
    )

-- plugin: bootHook
bootHook :: BootHook
bootHook =
  middleware BootMiddleware bootModule

-- plugin: runtimeHook
runtimeHook :: BootHook
runtimeHook =
  middleware RuntimeMiddleware bootModule
