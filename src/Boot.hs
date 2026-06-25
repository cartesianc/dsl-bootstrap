module Boot
  ( BootModule
  , bootModule
  ) where

import Blueprint

type BootModule = Callback

-- plugin: bootModule
bootModule :: BootModule
bootModule =
  callback
    [ AppConfiguredFact
    ]
    ( parallel BootPreparation
        [ middleware BootMiddleware (effect [AppStartedFact])
        , middleware RuntimeMiddleware (effect [RuntimePreparedFact])
        ]
    )
