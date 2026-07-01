module Effects.Names
  ( EffectName (..)
  , HandlerName (..)
  , SendName (..)
  , TransformName (..)
  , TypeName (..)
  ) where

data EffectName
  = UserEffect
  | ReportEffect
  | LoggingEffect
  | SystemEffect
  | DemoEffect
  deriving (Eq, Show)

data SendName
  = AskUserName
  | HandleUserNameError
  | RememberUser
  | GenerateReport
  | WriteLog
  deriving (Eq, Show)

data HandlerName
  = RuntimeAskUserName
  | RuntimeHandleUserNameError
  | RuntimeRememberUser
  | RuntimeGenerateReport
  | ConsoleLogHandler
  | MockAskUserName
  | MockRememberUser
  | MockReportHandler
  | MockLogHandler
  deriving (Eq, Show)

data TransformName
  = UserNameToReportInput
  deriving (Eq, Show)

data TypeName
  = NoInput
  | ErrorInput
  | UserName
  | UserRecord
  | ReportInput
  | ReportOutput
  | LogMessage
  | Unit
  deriving (Eq, Show)
