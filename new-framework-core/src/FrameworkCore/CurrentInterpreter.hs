module FrameworkCore.CurrentInterpreter
  ( currentInterpreter
  ) where

import Framework.Ast
  ( AppBlueprint
  )
import Framework.Effect
  ( EffectTheory
  )
import Framework.TrustBase
  ( runNativeBlueprintWithEffectEnvironment
  )
import FrameworkCore.BaseApp
  ( FrameworkCoreInterpreter (..)
  , FrameworkCoreTrustBase (..)
  )

currentInterpreter :: FrameworkCoreInterpreter
currentInterpreter =
  FrameworkCoreInterpreter
    { frameworkCoreInterpreterName = "bootstrap-native-runtime"
    , runFrameworkCoreInterpreter = runWithTrustBase
    }

runWithTrustBase :: FrameworkCoreTrustBase -> AppBlueprint -> EffectTheory -> IO ()
runWithTrustBase trustBase ast effects =
  runNativeBlueprintWithEffectEnvironment (trustBaseRuntime trustBase) effects ast
