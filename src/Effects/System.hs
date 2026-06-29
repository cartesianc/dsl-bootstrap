module Effects.System
  ( systemEffect
  ) where

import Effects.EffectTheory

-- effect: systemEffect
systemEffect :: EffectUnit
systemEffect =
  effect SystemEffect
    [ fact AppConfiguredFact
    , fact AppStartedFact
        [ needs AppConfiguredFact
        ]
    , fact RuntimePreparedFact
        [ needs AppConfiguredFact
        ]
    , fact AppFinishedFact
        [ needs ReportGeneratedFact
        ]
    ]
