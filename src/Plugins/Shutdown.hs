{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Shutdown where

import Framework.Workflow

type ShutdownModule = Wait

type ShutdownHook = Middleware

-- plugin: shutdownModule
shutdownModule :: ShutdownModule
shutdownModule =
  wait
    [ ReportGeneratedFact
    ]
    ( parallel ShutdownFlow
        [ fact [AppFinishedFact]
        ]
    )

-- plugin: shutdownHook
shutdownHook :: ShutdownHook
shutdownHook =
  middleware ShutdownMiddleware shutdownModule
