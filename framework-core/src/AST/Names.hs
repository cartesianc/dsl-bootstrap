module AST.Names
  ( WorkflowName (..)
  ) where

data WorkflowName
  = AppFlow
  | LifecycleStartFlow
  | ConfigurationFlow
  | BootPreparation
  | UserModuleFlow
  | OnboardingFlow
  | ReportModuleFlow
  | CalculationReportFlow
  | CalculationsFlow
  | ShutdownFlow
  | Abc
  | Foo1
  | Foo2
  | Foo3
  | Foo4
  | Foo5
  | Foo6
  deriving (Eq, Show)
