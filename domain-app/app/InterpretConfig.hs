module InterpretConfig
  ( currentInterpreter
  ) where

import AST.AppBlueprint
  ( AppBlueprint
  )
import Effects.EffectTheory
  ( EffectTheory
  )
import Interpreter.Runtime
  ( runBlueprintWithEffects
  )

currentInterpreter :: AppBlueprint -> EffectTheory -> IO ()
currentInterpreter ast effects =
  runBlueprintWithEffects effects ast
