{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Report where

import Blueprint

type ReportModule = Parallel

type ReportLoop = HangingComponent

type ReportHook = Middleware

type CalculationReport = Wait

-- plugin: reportModule
reportModule :: ReportModule
reportModule =
  parallel ReportModuleFlow
    [ calculationReport
    ]

-- plugin: reportLoop
reportLoop :: ReportLoop
reportLoop =
  loop reportModule

-- plugin: calculationReport
calculationReport :: CalculationReport
calculationReport =
  wait
    [ UserKnownFact
    ]
    ( chain CalculationReportFlow
        [ fact [CalculationSectionOpenedFact]
        , parallel CalculationsFlow
            [ fact [AddCalculatedFact]
            , fact [FactorialCalculatedFact]
            , fact [SquaresCalculatedFact]
            ]
        , fact [ReportGeneratedFact]
        ]
    )

-- plugin: reportHook
reportHook :: ReportHook
reportHook =
  middleware ReportMiddleware calculationReport
