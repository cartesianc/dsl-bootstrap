module FrameworkCore.BaseApp
  ( FrameworkCoreInterpreter (..)
  , FrameworkCoreTrustBase (..)
  , baseApp
  , currentTrustBase
  ) where

import Framework.Ast
  ( AppBlueprint )
import Framework.Effect
  ( EffectTheory
  )
import Framework.TrustBase
  ( TrustBaseRuntimeEffectEnvironment
  , bootstrapRuntimeEffectEnvironment
  )

data FrameworkCoreTrustBase = FrameworkCoreTrustBase
  { trustBaseName :: String
  , trustBaseRuntime :: TrustBaseRuntimeEffectEnvironment
  }

data FrameworkCoreInterpreter = FrameworkCoreInterpreter
  { frameworkCoreInterpreterName :: String
  , runFrameworkCoreInterpreter :: FrameworkCoreTrustBase -> AppBlueprint -> EffectTheory -> IO ()
  }

currentTrustBase :: FrameworkCoreTrustBase
currentTrustBase =
  FrameworkCoreTrustBase
    { trustBaseName = "bootstrap-kernel"
    , trustBaseRuntime = bootstrapRuntimeEffectEnvironment
    }

baseApp :: FrameworkCoreTrustBase -> FrameworkCoreInterpreter -> AppBlueprint -> EffectTheory -> IO ()
baseApp trustBase interpreter ast effects =
  runFrameworkCoreInterpreter interpreter trustBase ast effects
