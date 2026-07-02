{-# LANGUAGE PatternSynonyms #-}

module Domain.Vocabulary
  ( pattern AddCalculatedFact
  , pattern AppConfiguredFact
  , pattern AppFinished
  , pattern AppFinishedFact
  , pattern AppFlow
  , pattern AppStarted
  , pattern AppStartedFact
  , pattern BootMiddleware
  , pattern BootPreparation
  , pattern CalculationReportFlow
  , pattern CalculationSectionOpenedFact
  , pattern CalculationsFlow
  , pattern ConfigurationFlow
  , pattern ConfigurationMiddleware
  , pattern FactorialCalculatedFact
  , pattern LifecycleStartFlow
  , pattern LoggingMiddleware
  , pattern OnboardingFlow
  , pattern ReportFinished
  , pattern ReportGeneratedFact
  , pattern ReportMiddleware
  , pattern ReportModuleFlow
  , pattern RuntimeMiddleware
  , pattern RuntimePrepared
  , pattern RuntimePreparedFact
  , pattern ShutdownFlow
  , pattern ShutdownMiddleware
  , pattern SquaresCalculatedFact
  , pattern UserFlowMiddleware
  , pattern UserGreetedFact
  , pattern UserKnownFact
  , pattern UserModuleFlow
  , pattern UserNameAskedFact
  , pattern UserRemembered
  ) where

import Framework.Workflow
  ( Interceptor (..)
  , LogEvent (..)
  , WorkflowFact (..)
  , WorkflowName (..)
  )

pattern AppConfiguredFact :: WorkflowFact
pattern AppConfiguredFact = WorkflowFact "AppConfiguredFact"

pattern AppStartedFact :: WorkflowFact
pattern AppStartedFact = WorkflowFact "AppStartedFact"

pattern RuntimePreparedFact :: WorkflowFact
pattern RuntimePreparedFact = WorkflowFact "RuntimePreparedFact"

pattern UserNameAskedFact :: WorkflowFact
pattern UserNameAskedFact = WorkflowFact "UserNameAskedFact"

pattern UserGreetedFact :: WorkflowFact
pattern UserGreetedFact = WorkflowFact "UserGreetedFact"

pattern UserKnownFact :: WorkflowFact
pattern UserKnownFact = WorkflowFact "UserKnownFact"

pattern CalculationSectionOpenedFact :: WorkflowFact
pattern CalculationSectionOpenedFact = WorkflowFact "CalculationSectionOpenedFact"

pattern AddCalculatedFact :: WorkflowFact
pattern AddCalculatedFact = WorkflowFact "AddCalculatedFact"

pattern FactorialCalculatedFact :: WorkflowFact
pattern FactorialCalculatedFact = WorkflowFact "FactorialCalculatedFact"

pattern SquaresCalculatedFact :: WorkflowFact
pattern SquaresCalculatedFact = WorkflowFact "SquaresCalculatedFact"

pattern ReportGeneratedFact :: WorkflowFact
pattern ReportGeneratedFact = WorkflowFact "ReportGeneratedFact"

pattern AppFinishedFact :: WorkflowFact
pattern AppFinishedFact = WorkflowFact "AppFinishedFact"

pattern AppFlow :: WorkflowName
pattern AppFlow = WorkflowName "AppFlow"

pattern LifecycleStartFlow :: WorkflowName
pattern LifecycleStartFlow = WorkflowName "LifecycleStartFlow"

pattern ConfigurationFlow :: WorkflowName
pattern ConfigurationFlow = WorkflowName "ConfigurationFlow"

pattern BootPreparation :: WorkflowName
pattern BootPreparation = WorkflowName "BootPreparation"

pattern UserModuleFlow :: WorkflowName
pattern UserModuleFlow = WorkflowName "UserModuleFlow"

pattern OnboardingFlow :: WorkflowName
pattern OnboardingFlow = WorkflowName "OnboardingFlow"

pattern ReportModuleFlow :: WorkflowName
pattern ReportModuleFlow = WorkflowName "ReportModuleFlow"

pattern CalculationReportFlow :: WorkflowName
pattern CalculationReportFlow = WorkflowName "CalculationReportFlow"

pattern CalculationsFlow :: WorkflowName
pattern CalculationsFlow = WorkflowName "CalculationsFlow"

pattern ShutdownFlow :: WorkflowName
pattern ShutdownFlow = WorkflowName "ShutdownFlow"

pattern ConfigurationMiddleware :: Interceptor
pattern ConfigurationMiddleware = Interceptor "ConfigurationMiddleware"

pattern BootMiddleware :: Interceptor
pattern BootMiddleware = Interceptor "BootMiddleware"

pattern RuntimeMiddleware :: Interceptor
pattern RuntimeMiddleware = Interceptor "RuntimeMiddleware"

pattern LoggingMiddleware :: Interceptor
pattern LoggingMiddleware = Interceptor "LoggingMiddleware"

pattern UserFlowMiddleware :: Interceptor
pattern UserFlowMiddleware = Interceptor "UserFlowMiddleware"

pattern ReportMiddleware :: Interceptor
pattern ReportMiddleware = Interceptor "ReportMiddleware"

pattern ShutdownMiddleware :: Interceptor
pattern ShutdownMiddleware = Interceptor "ShutdownMiddleware"

pattern AppStarted :: LogEvent
pattern AppStarted = LogEvent "AppStarted"

pattern RuntimePrepared :: LogEvent
pattern RuntimePrepared = LogEvent "RuntimePrepared"

pattern AppFinished :: LogEvent
pattern AppFinished = LogEvent "AppFinished"

pattern UserRemembered :: LogEvent
pattern UserRemembered = LogEvent "UserRemembered"

pattern ReportFinished :: LogEvent
pattern ReportFinished = LogEvent "ReportFinished"
