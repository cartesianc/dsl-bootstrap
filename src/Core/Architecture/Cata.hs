module Core.Architecture.Cata
  ( WorkflowAlgebra (..)
  , cataWorkflow
  , cataHanging
  ) where

import Core.Architecture
import Core.Architecture.Cata.Types
  ( WorkflowAlgebra (..)
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

cataWorkflow ::
  WorkflowAlgebra fact result ->
  Workflow fact hook ->
  result
cataWorkflow =
  gpreproWorkflow lowerWorkflow interpretWorkflowProgram

cataHanging ::
  WorkflowAlgebra fact result ->
  Hanging (HangingAction fact hook (Workflow fact hook)) ->
  Hanging (HangingAction fact hook result)
cataHanging =
  gpreproHanging lowerHanging interpretHangingProgram
