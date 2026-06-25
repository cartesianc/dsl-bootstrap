module AST.Facts
  ( WorkflowFact (..)
  ) where

data WorkflowFact
  = AppConfiguredFact
  | AppStartedFact
  | RuntimePreparedFact
  | UserNameAskedFact
  | UserGreetedFact
  | UserKnownFact
  | CalculationSectionOpenedFact
  | AddCalculatedFact
  | FactorialCalculatedFact
  | SquaresCalculatedFact
  | ReportGeneratedFact
  | AppFinishedFact
  | Foo5Fact
  | Foo6Fact
  deriving (Eq, Show)
