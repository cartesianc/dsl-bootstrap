module InterpretConfig
  ( currentInterpreter
  ) where

import Domain.Runtime
  ( domainRuntimeEffectEnvironment
  )
import Framework.Ast
  ( AppBlueprint
  )
import Framework.Effect
  ( EffectTheory
  )
import Framework.TrustBase
  ( runBlueprintWithEffectEnvironment
  )

currentInterpreter :: AppBlueprint -> EffectTheory -> IO ()
currentInterpreter ast effects =
  runBlueprintWithEffectEnvironment domainRuntimeEffectEnvironment effects ast
