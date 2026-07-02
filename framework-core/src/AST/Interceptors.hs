module AST.Interceptors
  ( Interceptor (..)
  , LogEvent (..)
  ) where

newtype Interceptor = Interceptor
  { interceptorText :: String
  }
  deriving (Eq)

instance Show Interceptor where
  show =
    interceptorText

newtype LogEvent = LogEvent
  { logEventText :: String
  }
  deriving (Eq)

instance Show LogEvent where
  show =
    logEventText
