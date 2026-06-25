module Report
  ( ReportModule
  , reportModule
  , calculationReport
  ) where

import Blueprint

type ReportModule = Parallel

type CalculationReport = Callback

-- plugin: reportModule
reportModule :: ReportModule
reportModule =
  parallel ReportModuleFlow
    [ calculationReport
    ]

-- plugin: calculationReport
calculationReport :: CalculationReport
calculationReport =
  callback
    [ UserKnownFact
    ]
    ( middleware
        ReportMiddleware
        ( chain CalculationReportFlow
            [ effect [CalculationSectionOpenedFact]
            , parallel CalculationsFlow
                [ effect [AddCalculatedFact]
                , effect [FactorialCalculatedFact]
                , effect [SquaresCalculatedFact]
                ]
            , effect [ReportGeneratedFact]
            ]
        )
    )
