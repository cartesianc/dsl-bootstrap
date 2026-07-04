{-# LANGUAGE PatternSynonyms #-}

module Effects.System
  ( systemEffect
  ) where

import Domain.EffectVocabulary
  ( pattern SystemEffect )
import Domain.Business
  ( systemCapabilities )
import Framework.Business
  ( EffectUnit
  , capabilitiesEffect
  )

-- lowering facade: Domain.Business.systemCapabilities -> EffectUnit
systemEffect :: EffectUnit
systemEffect =
  capabilitiesEffect SystemEffect systemCapabilities
