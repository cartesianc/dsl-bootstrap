{-# OPTIONS_GHC -Wno-missing-export-lists #-}
{-# OPTIONS_GHC -Wno-missing-signatures #-}

module Plugins
  where

import qualified Plugins.Boot
import qualified Plugins.Configuration
import qualified Plugins.Handle
import qualified Plugins.Lifecycle
import qualified Plugins.Report
import qualified Plugins.Shutdown

bootModule = Plugins.Boot.bootModule
configurationModule = Plugins.Configuration.configurationModule
onboarding = Plugins.Handle.onboarding
userModule = Plugins.Handle.userModule
lifecycleEnd = Plugins.Lifecycle.lifecycleEnd
lifecycleStart = Plugins.Lifecycle.lifecycleStart
calculationReport = Plugins.Report.calculationReport
reportModule = Plugins.Report.reportModule
shutdownModule = Plugins.Shutdown.shutdownModule
