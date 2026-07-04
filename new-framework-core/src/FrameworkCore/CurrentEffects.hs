module FrameworkCore.CurrentEffects
  ( currentEffects
  ) where

import Domain.Effects
  ( frameworkCoreEffects
  )
import Framework.Business
  ( EffectTheory
  )

currentEffects :: EffectTheory
currentEffects =
  frameworkCoreEffects
