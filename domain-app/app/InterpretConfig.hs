module InterpretConfig
  ( currentInterpreter
  ) where

import Domain.Runtime
  ( domainRuntimeEffectEnvironment
  )
import Framework.Ast
  ( AppBlueprint
  )
import Framework.Business
  ( EffectTheory
  )
import Framework.App
  ( runApp
  )

currentInterpreter :: AppBlueprint -> EffectTheory -> IO ()
currentInterpreter ast effects =
  runApp domainRuntimeEffectEnvironment effects ast
