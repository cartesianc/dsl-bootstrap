module Bootstrap.Effects.CoreModule.Facts.CoreHostModulesClassified
  ( coreHostModulesClassifiedFact
  ) where

import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , fact
  , make
  , needs
  )
import qualified Bootstrap.Effect as Effect

coreHostModulesClassifiedFact :: EffectSection
coreHostModulesClassifiedFact =
  fact CoreHostModulesClassifiedFact
    [ needs PackageModulesDiscoveredFact
    , Effect.take PackageModuleCatalog
    , make CoreHostModuleCatalog
    ]
