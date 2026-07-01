module AST.AppBlueprint
  ( AppBlueprint (..)
  , App
  , AppHanging
  ) where

import AST.Vocabulary
  ( Interceptor
  , WorkflowFact
  )
import Core.Architecture
  ( Hanging
  , HangingAction
  , Workflow
  )

data AppBlueprint = AppBlueprint
  { blueprintApp :: App
  , blueprintHanging :: AppHanging
  }

type App = Workflow WorkflowFact Interceptor

type AppHanging = Hanging (HangingAction WorkflowFact Interceptor App)
