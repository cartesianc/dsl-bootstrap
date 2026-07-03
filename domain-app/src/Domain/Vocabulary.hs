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

import Framework.Ast
  ( EffectSystemName (..)
  , Interceptor (..)
  , LogEvent (..)
  , WorkflowFact (..)
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

pattern AppFlow :: EffectSystemName
pattern AppFlow = EffectSystemName "AppFlow"

pattern LifecycleStartFlow :: EffectSystemName
pattern LifecycleStartFlow = EffectSystemName "LifecycleStartFlow"

pattern ConfigurationFlow :: EffectSystemName
pattern ConfigurationFlow = EffectSystemName "ConfigurationFlow"

pattern BootPreparation :: EffectSystemName
pattern BootPreparation = EffectSystemName "BootPreparation"

pattern UserModuleFlow :: EffectSystemName
pattern UserModuleFlow = EffectSystemName "UserModuleFlow"

pattern OnboardingFlow :: EffectSystemName
pattern OnboardingFlow = EffectSystemName "OnboardingFlow"

pattern ReportModuleFlow :: EffectSystemName
pattern ReportModuleFlow = EffectSystemName "ReportModuleFlow"

pattern CalculationReportFlow :: EffectSystemName
pattern CalculationReportFlow = EffectSystemName "CalculationReportFlow"

pattern CalculationsFlow :: EffectSystemName
pattern CalculationsFlow = EffectSystemName "CalculationsFlow"

pattern ShutdownFlow :: EffectSystemName
pattern ShutdownFlow = EffectSystemName "ShutdownFlow"

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
