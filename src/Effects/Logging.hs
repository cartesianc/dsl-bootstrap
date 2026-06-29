module Effects.Logging
  ( loggingEffect
  ) where

import Effects.EffectTheory

-- effect: loggingEffect
loggingEffect :: EffectUnit
loggingEffect =
  effect LoggingEffect
    [ send WriteLog LogMessage Unit
    , profile Production
        [ implement WriteLog ConsoleLogHandler
        ]
    , profile Test
        [ implement WriteLog MockLogHandler
        ]
    ]
