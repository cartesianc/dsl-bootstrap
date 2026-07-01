module CurrentEffects
  ( currentEffects
  ) where

import Framework.Effect
  ( EffectTheory
  )
import Effects.Theory
  ( effectTheory
  )

currentEffects :: EffectTheory
currentEffects =
  effectTheory
