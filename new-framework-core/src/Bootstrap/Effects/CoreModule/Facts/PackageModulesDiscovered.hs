module Bootstrap.Effects.CoreModule.Facts.PackageModulesDiscovered
  ( packageModulesDiscoveredFact
  ) where

import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , fact
  , make
  , uses
  )

packageModulesDiscoveredFact :: EffectSection
packageModulesDiscoveredFact =
  fact PackageModulesDiscoveredFact
    [ uses ReadPackageFiles
    , make PackageModuleCatalog
    ]
