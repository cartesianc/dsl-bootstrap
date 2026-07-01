module Effects.Logging
  ( loggingEffect
  ) where

import Framework.Effect

-- effect: loggingEffect
loggingEffect :: EffectUnit
loggingEffect =
  effect LoggingEffect
    [ externalMake WriteLog LogMessage Unit
    ]
