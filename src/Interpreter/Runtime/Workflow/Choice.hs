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
import Interpreter.Runtime.Types
  ( Runtime
  , WorkflowProgram
  )
import Interpreter.Runtime.Trace
  ( traceRuntime
  )

choiceByKey :: ChoiceKey -> Choice WorkflowProgram -> WorkflowProgram
choiceByKey selectedKey branches runtime = do
  traceRuntime ("choice " ++ renderChoiceKey selectedKey)
  runChoice runtime selectedKey (freeChoiceBranches (choiceBranches branches))

runChoice ::
  Runtime ->
  ChoiceKey ->
  [ChoiceBranch ChoiceKey WorkflowProgram] ->
  IO Runtime
runChoice _ selectedKey [] =
  ioError (userError ("Choice workflow has no branch for " ++ renderChoiceKey selectedKey))
runChoice runtime selectedKey (ChoiceBranch branchKey branch : rest)
  | selectedKey == branchKey =
      branch runtime
  | otherwise =
      runChoice runtime selectedKey rest

renderChoiceKey :: ChoiceKey -> String
renderChoiceKey (ChoiceKey value) =
  value
