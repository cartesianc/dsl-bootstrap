module Interpreter
  ( Runtime (..)
  , interpreter
  , runApp
  , runAppWith
  ) where

import AST.AppBlueprint
  ( AppBlueprint (..)
  )
import AST.Vocabulary
  ( Interceptor
  , WorkflowFact
  )
import Core.Architecture.Cata
  ( WorkflowAlgebra
  , cataHanging
  , cataWorkflow
  )
import Interpreter.Runtime
  ( Runtime (..)
  , runApp
  , runAppWith
  )
import Interpreter.View.Algebra
  ( Program
  , algebra
  , runBlueprint
  )

interpreter :: AppBlueprint -> IO ()
interpreter ast =
  cata algebra ast

cata :: WorkflowAlgebra WorkflowFact Interceptor Program -> AppBlueprint -> IO ()
cata currentAlgebra ast =
  runBlueprint
    (cataWorkflow currentAlgebra (blueprintApp ast))
    (cataHanging currentAlgebra (blueprintHanging ast))
