module FrameworkCore.CurrentEffects
  ( currentEffects
  ) where

import Domain.Effects
  ( frameworkCoreEffects
  )
import Framework.Effect
  ( EffectTheory
  )

currentEffects :: EffectTheory
currentEffects =
  frameworkCoreEffects
