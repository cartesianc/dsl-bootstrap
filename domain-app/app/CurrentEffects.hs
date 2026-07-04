module CurrentEffects
  ( currentEffects
  ) where

import Framework.Business
  ( EffectTheory
  )
import Effects.Theory
  ( effectTheory
  )

currentEffects :: EffectTheory
currentEffects =
  effectTheory
