module Plugins.Shutdown
  ( ShutdownModule
  , shutdownModule
  ) where

import Blueprint

type ShutdownModule = Wait

-- plugin: shutdownModule
shutdownModule :: ShutdownModule
shutdownModule =
  wait
    [ ReportGeneratedFact
    ]
    ( parallel ShutdownFlow
        [ middleware ShutdownMiddleware (fact [AppFinishedFact])
        ]
    )
