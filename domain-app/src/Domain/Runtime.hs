{-# LANGUAGE PatternSynonyms #-}

module Domain.Runtime
  ( LogMessageValue (..)
  , ReportInputValue (..)
  , ReportOutputValue (..)
  , UserNameValue (..)
  , UserRecordValue (..)
  , domainHandlerRegistry
  , domainRuntimeEffectEnvironment
  , domainTransformRegistry
  , pattern LogMessageTag
  , pattern ReportInputTag
  , pattern ReportOutputTag
  , pattern UserNameTag
  , pattern UserRecordTag
  ) where

import Domain.EffectVocabulary
import Framework.Background
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , RuntimeEffectEnvironment
  , RuntimeHandler (..)
  , RuntimeTypedValue (..)
  , RuntimeTransform (..)
  , SomeRuntimeValue (..)
  , TransformBinding (..)
  , TransformRegistry (..)
  , ValueTag (..)
  , runtimeEffectEnvironmentWithTransforms
  )
import Framework.Effect
  ( SendName
  )

newtype UserNameValue = UserNameValue String
  deriving (Eq, Show)

newtype UserRecordValue = UserRecordValue String
  deriving (Eq, Show)

newtype ReportInputValue = ReportInputValue String
  deriving (Eq, Show)

newtype ReportOutputValue = ReportOutputValue String
  deriving (Eq, Show)

newtype LogMessageValue = LogMessageValue String
  deriving (Eq, Show)

pattern UserNameTag :: ValueTag UserNameValue
pattern UserNameTag <- ValueTag UserName _
  where
    UserNameTag = ValueTag UserName userNameValueText

pattern UserRecordTag :: ValueTag UserRecordValue
pattern UserRecordTag <- ValueTag UserRecord _
  where
    UserRecordTag = ValueTag UserRecord userRecordValueText

pattern ReportInputTag :: ValueTag ReportInputValue
pattern ReportInputTag <- ValueTag ReportInput _
  where
    ReportInputTag = ValueTag ReportInput reportInputValueText

pattern ReportOutputTag :: ValueTag ReportOutputValue
pattern ReportOutputTag <- ValueTag ReportOutput _
  where
    ReportOutputTag = ValueTag ReportOutput reportOutputValueText

pattern LogMessageTag :: ValueTag LogMessageValue
pattern LogMessageTag <- ValueTag LogMessage _
  where
    LogMessageTag = ValueTag LogMessage logMessageValueText

domainRuntimeEffectEnvironment :: RuntimeEffectEnvironment
domainRuntimeEffectEnvironment =
  runtimeEffectEnvironmentWithTransforms domainHandlerRegistry domainTransformRegistry

domainHandlerRegistry :: HandlerRegistry
domainHandlerRegistry =
  HandlerRegistry
    [ HandlerBinding AskUserName RuntimeAskUserName domainSucceedHandler
    , HandlerBinding HandleUserNameError RuntimeHandleUserNameError domainSucceedHandler
    , HandlerBinding RememberUser RuntimeRememberUser domainSucceedHandler
    , HandlerBinding GenerateReport RuntimeGenerateReport domainSucceedHandler
    , HandlerBinding WriteLog ConsoleLogHandler domainSucceedHandler
    ]

domainTransformRegistry :: TransformRegistry
domainTransformRegistry =
  TransformRegistry
    [ TransformBinding
        UserNameToReportInput
        ( RuntimeTransform
            UserNameTag
            ReportInputTag
            ( \(UserNameValue text) ->
                ReportInputValue ("report-input:" ++ text)
            )
        )
    ]

domainSucceedHandler :: RuntimeHandler
domainSucceedHandler =
  RuntimeHandler (\currentSend _ _ -> pure (domainDefaultHandlerResult currentSend))

domainDefaultHandlerResult :: SendName -> HandlerResult
domainDefaultHandlerResult AskUserName =
  HandlerSucceededTyped
    [SomeRuntimeValue (RuntimeTypedValue UserNameTag (UserNameValue "runtime-user"))]
domainDefaultHandlerResult GenerateReport =
  HandlerSucceededTyped
    [SomeRuntimeValue (RuntimeTypedValue ReportOutputTag (ReportOutputValue "runtime-report"))]
domainDefaultHandlerResult _ =
  HandlerSucceeded []

userNameValueText :: UserNameValue -> String
userNameValueText (UserNameValue text) =
  text

userRecordValueText :: UserRecordValue -> String
userRecordValueText (UserRecordValue text) =
  text

reportInputValueText :: ReportInputValue -> String
reportInputValueText (ReportInputValue text) =
  text

reportOutputValueText :: ReportOutputValue -> String
reportOutputValueText (ReportOutputValue text) =
  text

logMessageValueText :: LogMessageValue -> String
logMessageValueText (LogMessageValue text) =
  text
