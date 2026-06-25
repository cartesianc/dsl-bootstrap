{-# OPTIONS_GHC -Wno-missing-export-lists #-}
{-# OPTIONS_GHC -Wno-missing-signatures #-}

module Plugins
  where

import qualified Boot
import qualified Configuration
import qualified Handle
import qualified Lifecycle
import qualified Report
import qualified Shutdown

bootModule = Boot.bootModule
configurationModule = Configuration.configurationModule
onboarding = Handle.onboarding
userModule = Handle.userModule
lifecycleEnd = Lifecycle.lifecycleEnd
lifecycleStart = Lifecycle.lifecycleStart
calculationReport = Report.calculationReport
reportModule = Report.reportModule
shutdownModule = Shutdown.shutdownModule
