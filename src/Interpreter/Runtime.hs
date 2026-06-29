module Interpreter.Runtime
  ( Runtime (..)
  , runApp
  , runAppWith
  , runBlueprint
  , runBlueprintWithAlgebra
  , runBlueprintWith
  , runBlueprintWithEffects
  ) where

import AST.AppBlueprint
  ( App
  , AppBlueprint (..)
  )
import Core.Architecture.Recursion
  ( gpreproHanging
  , gpreproWorkflow
  )
import qualified Core.App as App
import Core.Workflow.Eff
  ( compileHangingEff
  , compileWorkflowEff
  , interpretHangingEff
  , interpretWorkflowEff
  )
import Effects.EffectTheory
  ( EffectTheory (..)
  )
import Effects.Names
  ( ProfileName (Production)
  )
import Interpreter.Runtime.Algebra
  ( runtimeAlgebra
  )
import Interpreter.Runtime.Contextware
  ( contextware
  )
import Interpreter.Runtime.Hanging.FreeMonoid
  ( runHanging
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , RuntimeFAlgebra
  , emptyRuntime
  )
import Interpreter.Runtime.Trace
  ( traceRuntime
  )

runApp :: App -> IO ()
runApp =
  runAppWith emptyRuntime

runAppWith :: Runtime -> App -> IO ()
runAppWith runtime appArchitecture = do
  _ <- gpreproWorkflow compileWorkflowEff interpretWorkflowEff runtimeAlgebra appArchitecture runtime
  pure ()

runBlueprint :: AppBlueprint -> IO ()
runBlueprint =
  runBlueprintWith emptyRuntime

runBlueprintWith :: Runtime -> AppBlueprint -> IO ()
runBlueprintWith =
  runBlueprintWithAlgebra runtimeAlgebra

runBlueprintWithAlgebra :: RuntimeFAlgebra -> Runtime -> AppBlueprint -> IO ()
runBlueprintWithAlgebra currentAlgebra runtime blueprint = do
  appRuntime <- gpreproWorkflow compileWorkflowEff interpretWorkflowEff currentAlgebra (blueprintApp blueprint) runtime
  _ <- runHanging (gpreproHanging compileHangingEff interpretHangingEff currentAlgebra (blueprintHanging blueprint)) appRuntime
  pure ()

runBlueprintWithEffects :: EffectTheory -> AppBlueprint -> IO ()
runBlueprintWithEffects effects blueprint =
  case App.app blueprint effects Production of
    Left errorReport ->
      traceRuntime ("app build failed: " ++ App.renderAppError errorReport)
    Right appPlan -> do
      traceRuntime ("effect theory loaded " ++ show (length (theoryUnits effects)) ++ " units")
      traceRuntime
        ( "app built with "
            ++ show (length (App.appPlanFacts appPlan))
            ++ " facts and "
            ++ show (length (App.appPlanSendBoundaries appPlan))
            ++ " send boundaries"
        )
      runBlueprintWithAlgebra (contextware (App.appPlanEffects appPlan) runtimeAlgebra) emptyRuntime (App.appPlanBlueprint appPlan)
