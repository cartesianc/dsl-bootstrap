module Domain.EffectHandlers
  ( EffectHandlerRegistration (..)
  , effectHandlerRegistrationNames
  , frameworkCoreEffectHandlerRegistration
  , frameworkCoreEffectHandlers
  , registeredEffectHandlers
  ) where

import qualified Bootstrap.Runtime
import Bootstrap.Runtime
  ( HandlerRegistry
  , RuntimeEffectEnvironment
  , TransformRegistry
  )

data EffectHandlerRegistration = EffectHandlerRegistration
  { effectHandlerRegistrationName :: String
  , effectHandlerEnvironment :: RuntimeEffectEnvironment
  , effectHandlerRegistry :: HandlerRegistry
  , effectHandlerTransforms :: TransformRegistry
  }

frameworkCoreEffectHandlerRegistration :: EffectHandlerRegistration
frameworkCoreEffectHandlerRegistration =
  EffectHandlerRegistration
    { effectHandlerRegistrationName = "framework-core-runtime"
    , effectHandlerEnvironment = Bootstrap.Runtime.bootstrapRuntimeEffectEnvironment
    , effectHandlerRegistry = Bootstrap.Runtime.bootstrapHandlerRegistry
    , effectHandlerTransforms = Bootstrap.Runtime.bootstrapTransformRegistry
    }

registeredEffectHandlers :: [EffectHandlerRegistration]
registeredEffectHandlers =
  [frameworkCoreEffectHandlerRegistration]

effectHandlerRegistrationNames :: [String]
effectHandlerRegistrationNames =
  map effectHandlerRegistrationName registeredEffectHandlers

frameworkCoreEffectHandlers :: RuntimeEffectEnvironment
frameworkCoreEffectHandlers =
  effectHandlerEnvironment frameworkCoreEffectHandlerRegistration
