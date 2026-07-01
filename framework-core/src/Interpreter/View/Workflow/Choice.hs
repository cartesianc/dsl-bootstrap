module Interpreter.View.Workflow.Choice
  ( choiceByKey
  ) where

import Core.Architecture
  ( Choice (..)
  , ChoiceKey
  )
import Core.Architecture.Internal
  ( FreeChoice (..)
  )
import Interpreter.View.Program
  ( Program
  , childIndent
  , printNode
  , renderChoiceKey
  , runChoiceBranch
  )

choiceByKey :: ChoiceKey -> Choice Program -> Program
choiceByKey selectedKey choices indent = do
  printNode indent ("choice " ++ renderChoiceKey selectedKey)
  mapM_ (runChoiceBranch (childIndent indent)) (freeChoiceBranches (choiceBranches choices))
