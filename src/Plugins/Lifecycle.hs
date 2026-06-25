module Plugins.Lifecycle
  ( lifecycleStart
  , lifecycleEnd
  ) where

import Blueprint
import Plugins.Boot
import Plugins.Configuration
import Plugins.Shutdown

-- plugin: lifecycleStart
lifecycleStart :: Chain
lifecycleStart =
  chain LifecycleStartFlow
    [ configurationModule
    , bootModule
    ]

-- plugin: lifecycleEnd
lifecycleEnd :: Wait
lifecycleEnd =
  shutdownModule
