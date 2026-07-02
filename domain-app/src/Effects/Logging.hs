module Effects.Logging
  ( loggingEffect
  ) where

import Domain.EffectVocabulary
import Framework.Effect

-- effect: loggingEffect
loggingEffect :: EffectUnit
loggingEffect =
  effect LoggingEffect
    [ externalMake WriteLog LogMessage Unit
    ]
