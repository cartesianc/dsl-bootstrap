{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Boot where

import Blueprint

type BootModule = WorkflowComponent

type BootHook = Middleware

-- plugin: bootModule
bootModule :: BootModule
bootModule =
  run (effectSystem BootPreparation [AppStartedFact, RuntimePreparedFact])

-- plugin: bootHook
bootHook :: BootHook
bootHook =
  middleware BootMiddleware bootModule

-- plugin: runtimeHook
runtimeHook :: BootHook
runtimeHook =
  middleware RuntimeMiddleware bootModule
