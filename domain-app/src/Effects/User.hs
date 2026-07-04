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
  ( EffectUnit
  , capabilitiesEffect
  )

-- lowering facade: Domain.Business.userCapabilities -> EffectUnit
userEffect :: EffectUnit
userEffect =
  capabilitiesEffect UserEffect userCapabilities
