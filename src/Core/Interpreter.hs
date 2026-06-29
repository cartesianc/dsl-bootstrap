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
import Effects.Names
  ( ProfileName (Production)
  )
import Interpreter.Runtime.Algebra
  ( algebra
  )
import Interpreter.Runtime.Contextware
  ( contextware
  )
import Interpreter.Runtime.RecursionModel
  ( cata
  )
import Interpreter.Runtime
  ( Runtime (..)
  , runApp
  , runAppWith
  , runBlueprint
  , runBlueprintWithEffects
  , runBlueprintWith
  )

interpreter :: AppBlueprint -> EffectTheory -> IO ()
interpreter ast effects =
  case App.app ast effects Production of
    Left errorReport ->
      putStrLn ("app build failed: " ++ App.renderAppError errorReport)
    Right appPlan ->
      cata (contextware (App.appPlanEffects appPlan) algebra) (App.appPlanBlueprint appPlan)
