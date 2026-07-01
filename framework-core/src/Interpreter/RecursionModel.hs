module Interpreter.RecursionModel
  ( cataModel
  ) where

import AST.AppBlueprint
  ( AppBlueprint (..)
  )
import Core.Architecture.Recursion
  ( gpreproHanging
  , gpreproWorkflow
  )
import Core.Workflow.Semantics
  ( interpretHangingProgram
  , interpretWorkflowProgram
  , lowerHanging
  , lowerWorkflow
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
    (gpreproWorkflow lowerWorkflow interpretWorkflowProgram algebra (blueprintApp ast))
    (gpreproHanging lowerHanging interpretHangingProgram algebra (blueprintHanging ast))
