module Interpreter.Runtime.Workflow.Choice
  ( choiceByKey
  ) where

import Core.Architecture
  ( Choice (..)
  , ChoiceKey (..)
  )
import Core.Architecture.Internal
  ( ChoiceBranch (..)
  , FreeChoice (..)
  )
import Interpreter.Runtime.Monad
  ( throwRuntimeError
  , traceRuntimeM
  )
import Interpreter.Runtime.Types
  ( RuntimeError (..)
  , WorkflowProgram
  )

choiceByKey :: ChoiceKey -> Choice WorkflowProgram -> WorkflowProgram
choiceByKey selectedKey branches = do
  traceRuntimeM ("choice " ++ renderChoiceKey selectedKey)
  runChoice selectedKey (freeChoiceBranches (choiceBranches branches))

runChoice ::
  ChoiceKey ->
  [ChoiceBranch ChoiceKey WorkflowProgram] ->
  WorkflowProgram
runChoice selectedKey [] =
  throwRuntimeError (RuntimeChoiceMissingBranch (renderChoiceKey selectedKey))
runChoice selectedKey (ChoiceBranch branchKey branch : rest)
  | selectedKey == branchKey =
      branch
  | otherwise =
      runChoice selectedKey rest

renderChoiceKey :: ChoiceKey -> String
renderChoiceKey (ChoiceKey value) =
  value
