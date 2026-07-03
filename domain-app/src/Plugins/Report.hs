{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Report where

import Blueprint

type ReportModule = WorkflowComponent

type ReportLoop = HangingComponent

type ReportHook = Middleware

type CalculationReport = WorkflowComponent

-- plugin: reportModule
reportModule :: ReportModule
reportModule =
  run (effectSystem ReportModuleFlow [ReportGeneratedFact])

-- plugin: reportLoop
reportLoop :: ReportLoop
reportLoop =
  loop reportModule

-- plugin: calculationReport
calculationReport :: CalculationReport
calculationReport =
  reportModule

-- plugin: reportHook
reportHook :: ReportHook
reportHook =
  middleware ReportMiddleware calculationReport
