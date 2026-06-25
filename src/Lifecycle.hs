module Lifecycle
  ( lifecycleStart
  , lifecycleEnd
  ) where

import Blueprint
import Boot
import Configuration
import Shutdown

-- plugin: lifecycleStart
lifecycleStart :: Chain
lifecycleStart =
  chain LifecycleStartFlow
    [ configurationModule
    , bootModule
    ]

-- plugin: lifecycleEnd
lifecycleEnd :: Callback
lifecycleEnd =
  shutdownModule
