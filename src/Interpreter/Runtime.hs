module Interpreter.Runtime
  ( Runtime (..)
  , runApp
  , runAppWith
  , runBlueprint
  , runBlueprintWith
  , runBlueprintWithEffects
  ) where

import AST.AppBlueprint
  ( App
  , AppBlueprint (..)
  )
import Core.Architecture.Cata
  ( cataHanging
  , cataWorkflow
  )
import qualified Core.App as App
import Effects.EffectTheory
  ( EffectTheory (..)
  )
import Effects.Names
  ( ProfileName (Production)
  )
import Interpreter.Runtime.Algebra
  ( runtimeAlgebra
  )
import Interpreter.Runtime.Hanging.FreeMonoid
  ( runHanging
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
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
  _ <- cataWorkflow runtimeAlgebra appArchitecture runtime
  pure ()

runBlueprint :: AppBlueprint -> IO ()
runBlueprint =
  runBlueprintWith emptyRuntime

runBlueprintWith :: Runtime -> AppBlueprint -> IO ()
runBlueprintWith runtime blueprint = do
  appRuntime <- cataWorkflow runtimeAlgebra (blueprintApp blueprint) runtime
  _ <- runHanging (cataHanging runtimeAlgebra (blueprintHanging blueprint)) appRuntime
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
      runBlueprint (App.appPlanBlueprint appPlan)
