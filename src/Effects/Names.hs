module Effects.Names
  ( EffectName (..)
  , ImplementationName (..)
  , ProfileName (..)
  , SendName (..)
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
  | RememberUser
  | GenerateReport
  | WriteLog
  deriving (Eq, Show)

data ImplementationName
  = RuntimeAskUserName
  | RuntimeRememberUser
  | RuntimeGenerateReport
  | ConsoleLogHandler
  | MockAskUserName
  | MockRememberUser
  | MockReportHandler
  | MockLogHandler
  deriving (Eq, Show)

data ProfileName
  = Production
  | Test
  deriving (Eq, Show)

data TypeName
  = NoInput
  | UserName
  | UserRecord
  | ReportInput
  | ReportOutput
  | LogMessage
  | Unit
  deriving (Eq, Show)
