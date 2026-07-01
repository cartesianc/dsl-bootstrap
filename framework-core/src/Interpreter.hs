module Interpreter
  ( Runtime (..)
  , interpreter
  , runApp
  , runAppWith
  , runBlueprint
  , runBlueprintWithEffects
  , runBlueprintWith
  ) where

import AST.AppBlueprint
  ( AppBlueprint
  )
import qualified Core.App as App
import Effects.EffectTheory
  ( EffectTheory
  )
import Interpreter.Runtime.Algebra
  ( algebra
  )
import Interpreter.Runtime.Contextware
  ( contextware
  )
import Interpreter.Runtime
  ( Runtime (..)
  , runApp
  , runAppWith
  , runBlueprint
  , runBlueprintWithEffects
  , runBlueprintWith
  , runBlueprintWithAlgebra
  )
import Interpreter.Runtime.Types
  ( emptyRuntime
  )

interpreter :: AppBlueprint -> EffectTheory -> IO ()
interpreter ast effects =
  case App.app ast effects of
    Left errorReport ->
      putStrLn ("app build failed: " ++ App.renderAppError errorReport)
    Right appPlan ->
      runBlueprintWithAlgebra
        (contextware (App.appPlanEffects appPlan) algebra)
        emptyRuntime
        (App.appPlanBlueprint appPlan)
