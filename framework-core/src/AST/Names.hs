module AST.Names
  ( WorkflowName (..)
  ) where

newtype WorkflowName = WorkflowName
  { workflowNameText :: String
  }
  deriving (Eq)

instance Show WorkflowName where
  show =
    workflowNameText
