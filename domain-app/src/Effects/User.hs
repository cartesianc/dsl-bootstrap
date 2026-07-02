{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE PatternSynonyms #-}

module Effects.User
  ( userEffect
  ) where

import Domain.EffectVocabulary
  ( pattern UserEffect )
import Domain.Business
  ( userCapabilities )
import Framework.Business
  ( capabilitiesEffect )
import Framework.Effect
  ( EffectUnit )

-- effect: userEffect
userEffect :: EffectUnit
userEffect =
  capabilitiesEffect UserEffect userCapabilities
