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
import Core.Effect.Semantics
  ( effectSemantics
  )
import Interpreter.Runtime.Algebra
  ( runtimeAlgebra
  )
import Interpreter.Runtime.Contextware
  ( contextwareWithEffectEnvironment
  )
import Interpreter.Runtime.Handlers
  ( defaultHandlerRegistry
  , runtimeEffectEnvironment
  )
import Interpreter.Runtime.Hanging.FreeMonoid
  ( runHanging
  )
import Interpreter.Runtime.Monad
  ( defaultRuntimeEnv
  , runRuntimeMOrThrow
  , runtimeEnv
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , RuntimeEnv
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
  _ <-
    runRuntimeMOrThrow
      defaultRuntimeEnv
      runtime
      (gpreproWorkflow compileWorkflowEff interpretWorkflowEff runtimeAlgebra appArchitecture)
  pure ()

runBlueprint :: AppBlueprint -> IO ()
runBlueprint =
  runBlueprintWith emptyRuntime

runBlueprintWith :: Runtime -> AppBlueprint -> IO ()
runBlueprintWith =
  runBlueprintWithAlgebra runtimeAlgebra

runBlueprintWithAlgebra :: RuntimeFAlgebra -> Runtime -> AppBlueprint -> IO ()
runBlueprintWithAlgebra =
  runBlueprintWithAlgebraInEnv defaultRuntimeEnv

runBlueprintWithAlgebraInEnv :: RuntimeEnv -> RuntimeFAlgebra -> Runtime -> AppBlueprint -> IO ()
runBlueprintWithAlgebraInEnv environment currentAlgebra runtime blueprint = do
  appRuntime <-
    runRuntimeMOrThrow
      environment
      runtime
      (gpreproWorkflow compileWorkflowEff interpretWorkflowEff currentAlgebra (blueprintApp blueprint))
  _ <-
    runRuntimeMOrThrow
      environment
      appRuntime
      (runHanging (gpreproHanging compileHangingEff interpretHangingEff currentAlgebra (blueprintHanging blueprint)))
  pure ()

runBlueprintWithEffects :: EffectTheory -> AppBlueprint -> IO ()
runBlueprintWithEffects effects blueprint =
  case App.app blueprint effects Production of
    Left errorReport ->
      traceRuntime ("app build failed: " ++ App.renderAppError errorReport)
    Right appPlan -> do
      let currentEffectEnvironment =
            runtimeEffectEnvironment (App.appPlanProfile appPlan) defaultHandlerRegistry
      let currentRuntimeEnv =
            runtimeEnv currentEffectEnvironment (effectSemantics (App.appPlanEffects appPlan))
      traceRuntime ("effect theory loaded " ++ show (length (theoryUnits effects)) ++ " units")
      traceRuntime
        ( "app built with "
            ++ show (length (App.appPlanFacts appPlan))
            ++ " facts and "
            ++ show (length (App.appPlanSendBoundaries appPlan))
            ++ " send boundaries"
        )
      runBlueprintWithAlgebraInEnv
        currentRuntimeEnv
        ( contextwareWithEffectEnvironment
            currentEffectEnvironment
            (App.appPlanEffects appPlan)
            runtimeAlgebra
        )
        emptyRuntime
        (App.appPlanBlueprint appPlan)
