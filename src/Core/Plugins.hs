{-# OPTIONS_GHC -Wno-missing-export-lists #-}
{-# OPTIONS_GHC -Wno-missing-signatures #-}

module Plugins
  where

import qualified Plugins.Boot
import qualified Plugins.Configuration
import qualified Plugins.Handle
import qualified Plugins.Lifecycle
import qualified Plugins.Logging
import qualified Plugins.Report
import qualified Plugins.Shutdown

bootHook = Plugins.Boot.bootHook
bootModule = Plugins.Boot.bootModule
runtimeHook = Plugins.Boot.runtimeHook
configurationHook = Plugins.Configuration.configurationHook
configurationModule = Plugins.Configuration.configurationModule
onboarding = Plugins.Handle.onboarding
userHook = Plugins.Handle.userHook
userModule = Plugins.Handle.userModule
lifecycleEnd = Plugins.Lifecycle.lifecycleEnd
lifecycleStart = Plugins.Lifecycle.lifecycleStart
loggingHook = Plugins.Logging.loggingHook
calculationReport = Plugins.Report.calculationReport
reportHook = Plugins.Report.reportHook
reportLoop = Plugins.Report.reportLoop
reportModule = Plugins.Report.reportModule
shutdownHook = Plugins.Shutdown.shutdownHook
shutdownModule = Plugins.Shutdown.shutdownModule
