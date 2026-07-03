{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Shutdown where

import Blueprint

type ShutdownModule = WorkflowComponent

type ShutdownHook = Middleware

-- plugin: shutdownModule
shutdownModule :: ShutdownModule
shutdownModule =
  run (effectSystem ShutdownFlow [AppFinishedFact])

-- plugin: shutdownHook
shutdownHook :: ShutdownHook
shutdownHook =
  middleware ShutdownMiddleware shutdownModule
