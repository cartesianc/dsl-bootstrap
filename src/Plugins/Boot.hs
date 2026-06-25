module Plugins.Boot
  ( BootModule
  , bootModule
  ) where

import Blueprint

type BootModule = Wait

-- plugin: bootModule
bootModule :: BootModule
bootModule =
  wait
    [ AppConfiguredFact
    ]
    ( parallel BootPreparation
        [ middleware BootMiddleware (fact [AppStartedFact])
        , middleware RuntimeMiddleware (fact [RuntimePreparedFact])
        ]
    )
