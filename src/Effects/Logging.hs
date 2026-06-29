module Effects.Logging
  ( loggingEffect
  ) where

import Framework.Effect

-- effect: loggingEffect
loggingEffect :: EffectUnit
loggingEffect =
  effect LoggingEffect
    [ externalMake WriteLog LogMessage Unit
    , profile Production
        [ implement WriteLog ConsoleLogHandler
        ]
    , profile Test
        [ implement WriteLog MockLogHandler
        ]
    ]
