module Plugins.Report
  ( ReportModule
  , reportModule
  , calculationReport
  ) where

import Blueprint

type ReportModule = Parallel

type CalculationReport = Wait

-- plugin: reportModule
reportModule :: ReportModule
reportModule =
  parallel ReportModuleFlow
    [ calculationReport
    ]

-- plugin: calculationReport
calculationReport :: CalculationReport
calculationReport =
  wait
    [ UserKnownFact
    ]
    ( middleware
        ReportMiddleware
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
    )
