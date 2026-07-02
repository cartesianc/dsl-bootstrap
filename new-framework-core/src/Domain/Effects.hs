module Domain.Effects
  ( EffectRegistration (..)
  , effectRegistrationNames
  , frameworkCoreEffectRegistration
  , frameworkCoreEffects
  , registeredEffects
  ) where

import qualified Bootstrap.Effects
import Bootstrap.Effect
  ( EffectTheory
  )

data EffectRegistration = EffectRegistration
  { effectRegistrationName :: String
  , effectRegistrationTheory :: EffectTheory
  }

frameworkCoreEffectRegistration :: EffectRegistration
frameworkCoreEffectRegistration =
  EffectRegistration
    { effectRegistrationName = "framework-core"
    , effectRegistrationTheory = Bootstrap.Effects.coreBootstrapEffects
    }

registeredEffects :: [EffectRegistration]
registeredEffects =
  [frameworkCoreEffectRegistration]

effectRegistrationNames :: [String]
effectRegistrationNames =
  map effectRegistrationName registeredEffects

frameworkCoreEffects :: EffectTheory
frameworkCoreEffects =
  effectRegistrationTheory frameworkCoreEffectRegistration
