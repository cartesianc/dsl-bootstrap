{-# LANGUAGE PatternSynonyms #-}

module Effects.Names
  ( EffectName (..)
  , HandlerName (..)
  , SendName (..)
  , TransformName (..)
  , TypeName (..)
  , pattern ErrorInput
  , pattern NoInput
  , pattern Unit
  ) where

newtype EffectName = EffectName
  { effectNameText :: String
  }
  deriving (Eq)

instance Show EffectName where
  show =
    effectNameText

newtype SendName = SendName
  { sendNameText :: String
  }
  deriving (Eq)

instance Show SendName where
  show =
    sendNameText

newtype HandlerName = HandlerName
  { handlerNameText :: String
  }
  deriving (Eq)

instance Show HandlerName where
  show =
    handlerNameText

newtype TransformName = TransformName
  { transformNameText :: String
  }
  deriving (Eq)

instance Show TransformName where
  show =
    transformNameText

newtype TypeName = TypeName
  { typeNameText :: String
  }
  deriving (Eq)

instance Show TypeName where
  show =
    typeNameText

pattern NoInput :: TypeName
pattern NoInput = TypeName "NoInput"

pattern ErrorInput :: TypeName
pattern ErrorInput = TypeName "ErrorInput"

pattern Unit :: TypeName
pattern Unit = TypeName "Unit"
