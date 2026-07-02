{-# LANGUAGE PatternSynonyms #-}

module Domain.Business
  ( allDomainCapabilities
  , generateReportCapability
  , loggingCapabilities
  , reportCapabilities
  , systemCapabilities
  , userCapabilities
  ) where

import Domain.EffectVocabulary
import Domain.Vocabulary
import Framework.Business
import Framework.Effect
  ( pattern ErrorInput
  , pattern NoInput
  , pattern Unit
  )

allDomainCapabilities :: [Capability]
allDomainCapabilities =
  systemCapabilities
    ++ userCapabilities
    ++ reportCapabilities
    ++ loggingCapabilities

systemCapabilities :: [Capability]
systemCapabilities =
  [ capability "ConfigureApp"
      [ produces AppConfiguredFact
      ]
  , capability "StartApp"
      [ requires AppConfiguredFact
      , produces AppStartedFact
      ]
  , capability "PrepareRuntime"
      [ requires AppConfiguredFact
      , produces RuntimePreparedFact
      ]
  , capability "FinishApp"
      [ requires ReportGeneratedFact
      , produces AppFinishedFact
      ]
  ]

userCapabilities :: [Capability]
userCapabilities =
  [ capability "AskUserName"
      [ uses AskUserName NoInput UserName
      , onError HandleUserNameError ErrorInput Unit
      , output UserName
      , produces UserNameAskedFact
      , handler
          ( handlerBinding
              RuntimeAskUserName
              "AskUserName"
              []
              [UserName]
              [UserNameAskedFact]
          )
      ]
  , capability "GreetUser"
      [ requires UserNameAskedFact
      , produces UserGreetedFact
      ]
  , capability "RememberUser"
      [ requires UserNameAskedFact
      , requires UserGreetedFact
      , input UserName
      , uses RememberUser UserName Unit
      , produces UserKnownFact
      , handler
          ( handlerBinding
              RuntimeRememberUser
              "RememberUser"
              [UserName]
              []
              [UserKnownFact]
          )
      ]
  ]

reportCapabilities :: [Capability]
reportCapabilities =
  [ capability "OpenCalculationSection"
      [ requires UserKnownFact
      , produces CalculationSectionOpenedFact
      ]
  , capability "CalculateAdd"
      [ requires CalculationSectionOpenedFact
      , produces AddCalculatedFact
      ]
  , capability "CalculateFactorial"
      [ requires CalculationSectionOpenedFact
      , produces FactorialCalculatedFact
      ]
  , capability "CalculateSquares"
      [ requires CalculationSectionOpenedFact
      , produces SquaresCalculatedFact
      ]
  , generateReportCapability
  ]

generateReportCapability :: Capability
generateReportCapability =
  capability "GenerateReport"
    [ requires AddCalculatedFact
    , requires FactorialCalculatedFact
    , requires SquaresCalculatedFact
    , requires UserNameAskedFact
    , input UserName
    , pipeline "GenerateReportPipeline" [UserName, ReportInput, ReportOutput]
    , transform (transformBinding UserNameToReportInput UserName ReportInput)
    , uses GenerateReport ReportInput ReportOutput
    , output ReportOutput
    , produces ReportGeneratedFact
    , handler
        ( handlerBinding
            RuntimeGenerateReport
            "GenerateReport"
            [ReportInput]
            [ReportOutput]
            [ReportGeneratedFact]
        )
    ]

loggingCapabilities :: [Capability]
loggingCapabilities =
  [ capability "WriteLog"
      [ uses WriteLog LogMessage Unit
      , handler
          ( handlerBinding
              ConsoleLogHandler
              "WriteLog"
              [LogMessage]
              []
              []
          )
      ]
  ]
