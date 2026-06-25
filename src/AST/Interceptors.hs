module AST.Interceptors
  ( Interceptor (..)
  , LogEvent (..)
  ) where

data Interceptor
  = ConfigurationMiddleware
  | BootMiddleware
  | RuntimeMiddleware
  | UserFlowMiddleware
  | ReportMiddleware
  | ShutdownMiddleware
  deriving (Show)

data LogEvent
  = AppStarted
  | RuntimePrepared
  | AppFinished
  | UserRemembered
  | ReportFinished
