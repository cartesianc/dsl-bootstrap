module InterpretConfig
  ( InterpretConfig (..)
  , currentInterpreter
  , interpretConfig
  , recursionScheme
  ) where

import AST.AppBlueprint
  ( AppBlueprint
  )
import qualified Core.App as App
import Effects.EffectTheory
  ( EffectTheory (..)
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
import Interpreter.Runtime.Trace
  ( traceRuntime
  )
import Interpreter.Runtime.Types
  ( RuntimeContextware
  , RuntimeFAlgebra
  , RuntimeRecursionModel
  )

data InterpretConfig = InterpretConfig
  { interpretRecursionModel :: RuntimeRecursionModel
  , interpretContextware :: RuntimeContextware
  , interpretFAlgebra :: RuntimeFAlgebra
  }

currentInterpreter :: AppBlueprint -> EffectTheory -> IO ()
currentInterpreter ast effects =
  case App.app ast effects Production of
    Left errorReport ->
      putStrLn ("app build failed: " ++ App.renderAppError errorReport)
    Right appPlan -> do
      traceRuntime
        ( "app built with "
            ++ show (length (App.appPlanFacts appPlan))
            ++ " facts and "
            ++ show (length (App.appPlanSendBoundaries appPlan))
            ++ " send boundaries"
        )
      recursionScheme
        cata
        contextware
        algebra
        (App.appPlanBlueprint appPlan)
        (App.appPlanEffects appPlan)

interpretConfig :: InterpretConfig
interpretConfig =
  InterpretConfig
    { interpretRecursionModel = cata
    , interpretContextware = contextware
    , interpretFAlgebra = algebra
    }

recursionScheme ::
  RuntimeRecursionModel ->
  RuntimeContextware ->
  RuntimeFAlgebra ->
  AppBlueprint ->
  EffectTheory ->
  IO ()
recursionScheme recursionModel currentContextware fAlgebra ast effects = do
  traceRuntime ("effect theory loaded " ++ show (length (theoryUnits effects)) ++ " units")
  recursionModel (currentContextware effects fAlgebra) ast
