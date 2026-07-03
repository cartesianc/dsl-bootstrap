{-# LANGUAGE GADTs #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE TypeOperators #-}

module Framework.Runtime.Values
  ( runtimeTypedValueToRuntimeValue
  , runtimeValueToSome
  , sameValueTag
  , someRuntimeValueToRuntimeValue
  , typedValueFor
  , typedValueFromSome
  ) where

import Data.Type.Equality
  ( (:~:) (Refl) )
import Data.Typeable
  ( eqT )

import Bootstrap.Effect
  ( pattern ErrorInput
  , pattern NoInput
  , pattern Unit
  )
import Framework.Runtime.Types

runtimeValueToSome :: RuntimeValue -> Maybe SomeRuntimeValue
runtimeValueToSome currentValue =
  case runtimeValueType currentValue of
    NoInput ->
      Just (SomeRuntimeValue (RuntimeTypedValue noInputTag NoInputValue))
    Unit ->
      Just (SomeRuntimeValue (RuntimeTypedValue unitTag UnitValue))
    ErrorInput ->
      Just (SomeRuntimeValue (RuntimeTypedValue errorInputTag (ErrorInputValue (runtimeValueText currentValue))))
    _ ->
      Nothing

someRuntimeValueToRuntimeValue :: SomeRuntimeValue -> RuntimeValue
someRuntimeValueToRuntimeValue (SomeRuntimeValue currentValue) =
  runtimeTypedValueToRuntimeValue currentValue

runtimeTypedValueToRuntimeValue :: RuntimeTypedValue value -> RuntimeValue
runtimeTypedValueToRuntimeValue currentValue =
  RuntimeValue
    { runtimeValueType = runtimeTypedValueType currentValue
    , runtimeValueText = runtimeTypedValueText currentValue
    }

typedValueFor :: ValueTag value -> Runtime -> Maybe (RuntimeTypedValue value)
typedValueFor currentTag runtime =
  firstJust
    [ typedValueFromSome currentTag currentValue
    | currentValue <- runtimeTypedValues runtime
    ]

typedValueFromSome :: ValueTag value -> SomeRuntimeValue -> Maybe (RuntimeTypedValue value)
typedValueFromSome expectedTag (SomeRuntimeValue currentValue) =
  case sameValueTag expectedTag (runtimeTypedValueTag currentValue) of
    Just Refl ->
      Just currentValue
    Nothing ->
      Nothing

sameValueTag :: ValueTag left -> ValueTag right -> Maybe (left :~: right)
sameValueTag (ValueTag leftType _) (ValueTag rightType _)
  | leftType == rightType =
      eqT
  | otherwise =
      Nothing

noInputTag :: ValueTag NoInputValue
noInputTag =
  ValueTag NoInput (\_ -> "")

unitTag :: ValueTag UnitValue
unitTag =
  ValueTag Unit (\_ -> "")

errorInputTag :: ValueTag ErrorInputValue
errorInputTag =
  ValueTag ErrorInput (\(ErrorInputValue text) -> text)

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest
