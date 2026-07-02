{-# LANGUAGE PatternSynonyms #-}

module Effects.Logging
  ( loggingEffect
  ) where

import Domain.EffectVocabulary
  ( pattern LoggingEffect )
import Domain.Business
  ( loggingCapabilities )
import Framework.Business
  ( capabilitiesEffect )
import Framework.Effect
  ( EffectUnit )

-- effect: loggingEffect
loggingEffect :: EffectUnit
loggingEffect =
  capabilitiesEffect LoggingEffect loggingCapabilities
