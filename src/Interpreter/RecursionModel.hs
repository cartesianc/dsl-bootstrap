module Interpreter.RecursionModel
  ( cataModel
  ) where

import AST.AppBlueprint
  ( AppBlueprint (..)
  )
import Core.Architecture.Cata
  ( cataHanging
  , cataWorkflow
  )
import Interpreter.Types
  ( RecursionModel
  )
import Interpreter.View.Algebra
  ( runBlueprint
  )

cataModel :: RecursionModel
cataModel algebra =
  cataAfterCheck algebra

cataAfterCheck :: RecursionModel
cataAfterCheck algebra ast =
  runBlueprint
    (cataWorkflow algebra (blueprintApp ast))
    (cataHanging algebra (blueprintHanging ast))
