module Effects.Report
  ( reportEffect
  ) where

import Framework.Effect

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
    , externalMake GenerateReport NoInput ReportOutput
    ]
