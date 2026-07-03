{-# LANGUAGE GADTs #-}

module Framework.Runtime.Handlers
  ( HandlerBinding (..)
  , HandlerInput (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , RuntimeEffectEnvironment (..)
  , RuntimeHandler (..)
  , RuntimeTransform (..)
  , TransformBinding (..)
  , TransformRegistry (..)
  , emptyHandlerRegistry
  , emptyTransformRegistry
  , handlerFor
  , handlerInputFromTypedValues
  , handlerInputFromValues
  , runtimeEffectEnvironment
  , runtimeEffectEnvironmentWithTransforms
  , runtimeTransformInput
  , runtimeTransformOutput
  , transformFor
  ) where

import Bootstrap.Effect
  ( HandlerName
  , SendName
  , TransformName
  , TypeName
  )
import Framework.Runtime.Types
import Framework.Runtime.Values
  ( runtimeValueToSome
  , someRuntimeValueToRuntimeValue
  )

data HandlerInput = HandlerInput
  { handlerInputValues :: [RuntimeValue]
  , handlerInputTypedValues :: [SomeRuntimeValue]
  }
  deriving (Eq, Show)

data HandlerResult
  = HandlerSucceeded [RuntimeValue]
  | HandlerSucceededTyped [SomeRuntimeValue]
  | HandlerFailed String
  deriving (Eq, Show)

newtype RuntimeHandler = RuntimeHandler
  { runRuntimeHandler :: SendName -> HandlerInput -> Runtime -> IO HandlerResult
  }

data HandlerBinding = HandlerBinding
  { handlerBindingSend :: SendName
  , handlerBindingName :: HandlerName
  , handlerBindingHandler :: RuntimeHandler
  }

newtype HandlerRegistry = HandlerRegistry
  { handlerRegistryBindings :: [HandlerBinding]
  }

data RuntimeTransform where
  RuntimeTransform :: ValueTag input -> ValueTag output -> (input -> output) -> RuntimeTransform

data TransformBinding = TransformBinding
  { transformBindingName :: TransformName
  , transformBindingTransform :: RuntimeTransform
  }

newtype TransformRegistry = TransformRegistry
  { transformRegistryBindings :: [TransformBinding]
  }

data RuntimeEffectEnvironment = RuntimeEffectEnvironment
  { runtimeEffectHandlers :: HandlerRegistry
  , runtimeEffectTransforms :: TransformRegistry
  }

emptyHandlerRegistry :: HandlerRegistry
emptyHandlerRegistry =
  HandlerRegistry []

emptyTransformRegistry :: TransformRegistry
emptyTransformRegistry =
  TransformRegistry []

runtimeEffectEnvironment :: HandlerRegistry -> RuntimeEffectEnvironment
runtimeEffectEnvironment handlers =
  RuntimeEffectEnvironment handlers emptyTransformRegistry

runtimeEffectEnvironmentWithTransforms :: HandlerRegistry -> TransformRegistry -> RuntimeEffectEnvironment
runtimeEffectEnvironmentWithTransforms =
  RuntimeEffectEnvironment

handlerInputFromValues :: [RuntimeValue] -> HandlerInput
handlerInputFromValues values =
  HandlerInput
    { handlerInputValues = values
    , handlerInputTypedValues =
        [ currentTypedValue
        | currentValue <- values
        , Just currentTypedValue <- [runtimeValueToSome currentValue]
        ]
    }

handlerInputFromTypedValues :: [SomeRuntimeValue] -> HandlerInput
handlerInputFromTypedValues values =
  HandlerInput
    { handlerInputValues = map someRuntimeValueToRuntimeValue values
    , handlerInputTypedValues = values
    }

runtimeTransformInput :: RuntimeTransform -> TypeName
runtimeTransformInput (RuntimeTransform inputTag _ _) =
  valueTagTypeName inputTag

runtimeTransformOutput :: RuntimeTransform -> TypeName
runtimeTransformOutput (RuntimeTransform _ outputTag _) =
  valueTagTypeName outputTag

handlerFor :: HandlerRegistry -> SendName -> Maybe HandlerBinding
handlerFor registry currentSend =
  firstJust
    [ Just binding
    | binding <- handlerRegistryBindings registry
    , handlerBindingSend binding == currentSend
    ]

transformFor :: TransformRegistry -> TransformName -> Maybe RuntimeTransform
transformFor registry currentTransform =
  firstJust
    [ Just (transformBindingTransform binding)
    | binding <- transformRegistryBindings registry
    , transformBindingName binding == currentTransform
    ]

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest
