{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Lifecycle where

import Framework.Workflow
-- plugin imports: begin
import Plugins.Boot
import Plugins.Configuration
import Plugins.Shutdown
-- plugin imports: end

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
