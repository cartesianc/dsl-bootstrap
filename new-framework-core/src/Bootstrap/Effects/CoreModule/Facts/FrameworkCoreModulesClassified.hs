module Bootstrap.Effects.CoreModule.Facts.FrameworkCoreModulesClassified
  ( frameworkCoreModulesClassifiedFact
  ) where

import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , fact
  , make
  , needs
  )
import qualified Bootstrap.Effect as Effect

frameworkCoreModulesClassifiedFact :: EffectSection
frameworkCoreModulesClassifiedFact =
  fact FrameworkCoreModulesClassifiedFact
    [ needs PackageModulesDiscoveredFact
    , Effect.take PackageModuleCatalog
    , make FrameworkCoreModuleCatalog
    ]
