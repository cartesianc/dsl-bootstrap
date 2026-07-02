{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Effects.CoreModule.Registration.Effect
  ( coreModuleEffect
  ) where

import Bootstrap.Effects.CoreModule.Facts.CoreHostModulesClassified
  ( coreHostModulesClassifiedFact )
import Bootstrap.Effects.CoreModule.Facts.FrameworkCoreModulesClassified
  ( frameworkCoreModulesClassifiedFact )
import Bootstrap.Effects.CoreModule.Facts.PackageModulesDiscovered
  ( packageModulesDiscoveredFact )
import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , EffectUnit
  , effect
  , externalMake
  , pattern NoInput
  )

coreModuleEffect :: EffectUnit
coreModuleEffect =
  effect CoreModuleEffect
    [ packageModulesDiscoveredFact
    , frameworkCoreModulesClassifiedFact
    , coreHostModulesClassifiedFact
    , readPackageFilesBoundary
    ]

readPackageFilesBoundary :: EffectSection
readPackageFilesBoundary =
  externalMake ReadPackageFiles NoInput PackageModuleCatalog
