module InterpretConfig
  ( currentInterpreter
  ) where

import Domain.Runtime
  ( domainRuntimeEffectEnvironment
  )
import Framework.Workflow
  ( AppBlueprint
  )
import Framework.Effect
  ( EffectTheory
  )
import Framework.Background
  ( runBlueprintWithEffectEnvironment
  )

currentInterpreter :: AppBlueprint -> EffectTheory -> IO ()
currentInterpreter ast effects =
  runBlueprintWithEffectEnvironment domainRuntimeEffectEnvironment effects ast
