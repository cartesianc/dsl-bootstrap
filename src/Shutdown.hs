module Shutdown
  ( ShutdownModule
  , shutdownModule
  ) where

import Blueprint

type ShutdownModule = Callback

-- plugin: shutdownModule
shutdownModule :: ShutdownModule
shutdownModule =
  callback
    [ ReportGeneratedFact
    ]
    ( parallel ShutdownFlow
        [ middleware ShutdownMiddleware (effect [AppFinishedFact])
        ]
    )
