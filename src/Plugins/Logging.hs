{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Logging where

import Framework.Workflow
-- plugin imports: begin
import Plugins.Report
-- plugin imports: end

type LoggingHook = Middleware

-- plugin: loggingHook
loggingHook :: LoggingHook
loggingHook =
  middleware LoggingMiddleware reportModule
