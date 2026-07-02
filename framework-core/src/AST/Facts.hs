module AST.Facts
  ( WorkflowFact (..)
  ) where

newtype WorkflowFact = WorkflowFact
  { workflowFactText :: String
  }
  deriving (Eq)

instance Show WorkflowFact where
  show =
    workflowFactText
