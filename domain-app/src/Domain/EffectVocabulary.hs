{-# LANGUAGE PatternSynonyms #-}

module Domain.EffectVocabulary
  ( pattern AskUserName
  , pattern ConsoleLogHandler
  , pattern GenerateReport
  , pattern LogMessage
  , pattern LoggingEffect
  , pattern MockAskUserName
  , pattern MockLogHandler
  , pattern MockRememberUser
  , pattern MockReportHandler
  , pattern RememberUser
  , pattern ReportEffect
  , pattern ReportInput
  , pattern ReportOutput
  , pattern RuntimeAskUserName
  , pattern RuntimeGenerateReport
  , pattern RuntimeHandleUserNameError
  , pattern RuntimeRememberUser
  , pattern SystemEffect
  , pattern UserEffect
  , pattern UserName
  , pattern UserNameToReportInput
  , pattern UserRecord
  , pattern WriteLog
  , pattern HandleUserNameError
  ) where

import Framework.Business
  ( EffectName (..)
  , HandlerName (..)
  , SendName (..)
  , TransformName (..)
  , TypeName (..)
  )

pattern UserEffect :: EffectName
pattern UserEffect = EffectName "UserEffect"

pattern ReportEffect :: EffectName
pattern ReportEffect = EffectName "ReportEffect"

pattern LoggingEffect :: EffectName
pattern LoggingEffect = EffectName "LoggingEffect"

pattern SystemEffect :: EffectName
pattern SystemEffect = EffectName "SystemEffect"

pattern AskUserName :: SendName
pattern AskUserName = SendName "AskUserName"

pattern HandleUserNameError :: SendName
pattern HandleUserNameError = SendName "HandleUserNameError"

pattern RememberUser :: SendName
pattern RememberUser = SendName "RememberUser"

pattern GenerateReport :: SendName
pattern GenerateReport = SendName "GenerateReport"

pattern WriteLog :: SendName
pattern WriteLog = SendName "WriteLog"

pattern RuntimeAskUserName :: HandlerName
pattern RuntimeAskUserName = HandlerName "RuntimeAskUserName"

pattern RuntimeHandleUserNameError :: HandlerName
pattern RuntimeHandleUserNameError = HandlerName "RuntimeHandleUserNameError"

pattern RuntimeRememberUser :: HandlerName
pattern RuntimeRememberUser = HandlerName "RuntimeRememberUser"

pattern RuntimeGenerateReport :: HandlerName
pattern RuntimeGenerateReport = HandlerName "RuntimeGenerateReport"

pattern ConsoleLogHandler :: HandlerName
pattern ConsoleLogHandler = HandlerName "ConsoleLogHandler"

pattern MockAskUserName :: HandlerName
pattern MockAskUserName = HandlerName "MockAskUserName"

pattern MockRememberUser :: HandlerName
pattern MockRememberUser = HandlerName "MockRememberUser"

pattern MockReportHandler :: HandlerName
pattern MockReportHandler = HandlerName "MockReportHandler"

pattern MockLogHandler :: HandlerName
pattern MockLogHandler = HandlerName "MockLogHandler"

pattern UserNameToReportInput :: TransformName
pattern UserNameToReportInput = TransformName "UserNameToReportInput"

pattern UserName :: TypeName
pattern UserName = TypeName "UserName"

pattern UserRecord :: TypeName
pattern UserRecord = TypeName "UserRecord"

pattern ReportInput :: TypeName
pattern ReportInput = TypeName "ReportInput"

pattern ReportOutput :: TypeName
pattern ReportOutput = TypeName "ReportOutput"

pattern LogMessage :: TypeName
pattern LogMessage = TypeName "LogMessage"
