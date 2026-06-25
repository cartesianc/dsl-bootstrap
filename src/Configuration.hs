module Configuration
  ( ConfigModule
  , configurationModule
  ) where

import Blueprint

type ConfigModule = Parallel

-- plugin: configurationModule
configurationModule :: ConfigModule
configurationModule =
  parallel ConfigurationFlow
    [ middleware ConfigurationMiddleware (effect [AppConfiguredFact])
    ]
