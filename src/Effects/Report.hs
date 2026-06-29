module Effects.Report
  ( reportEffect
  ) where

import Effects.EffectTheory

-- effect: reportEffect
reportEffect :: EffectUnit
reportEffect =
  effect ReportEffect
    [ fact CalculationSectionOpenedFact
        [ needs UserKnownFact
        ]
    , fact AddCalculatedFact
        [ needs CalculationSectionOpenedFact
        ]
    , fact FactorialCalculatedFact
        [ needs CalculationSectionOpenedFact
        ]
    , fact SquaresCalculatedFact
        [ needs CalculationSectionOpenedFact
        ]
    , fact ReportGeneratedFact
        [ needs AddCalculatedFact
        , needs FactorialCalculatedFact
        , needs SquaresCalculatedFact
        , uses GenerateReport
        ]
    , externalMake GenerateReport ReportInput ReportOutput
    , profile Production
        [ implement GenerateReport RuntimeGenerateReport
        ]
    , profile Test
        [ implement GenerateReport MockReportHandler
        ]
    ]
