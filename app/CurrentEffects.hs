module CurrentEffects
  ( currentEffects
  ) where

import Effects.EffectTheory
  ( EffectTheory
  )
import Effects.Theory
  ( effectTheory
  )

currentEffects :: EffectTheory
currentEffects =
  effectTheory
