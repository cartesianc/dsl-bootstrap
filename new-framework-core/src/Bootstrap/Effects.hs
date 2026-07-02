module Bootstrap.Effects
  ( coreArtifactEffect
  , coreBootstrapEffects
  , coreBoundaryEffect
  , coreExpressionEffect
  , coreLanguageEffect
  , coreModuleEffect
  , coreProofEffect
  , coreRegistryEffect
  , coreReportEffect
  , coreRuntimeEffect
  , coreSurfaceEffect
  ) where

import Bootstrap.Effects.CoreBoundary.Registration.Effect
  ( coreBoundaryEffect )
import Bootstrap.Effects.CoreArtifact.Registration.Effect
  ( coreArtifactEffect )
import Bootstrap.Effects.CoreExpression.Registration.Effect
  ( coreExpressionEffect )
import Bootstrap.Effects.CoreLanguage.Registration.Effect
  ( coreLanguageEffect )
import Bootstrap.Effects.CoreModule.Registration.Effect
  ( coreModuleEffect )
import Bootstrap.Effects.CoreProof.Registration.Effect
  ( coreProofEffect )
import Bootstrap.Effects.CoreRegistry.Registration.Effect
  ( coreRegistryEffect )
import Bootstrap.Effects.CoreReport.Registration.Effect
  ( coreReportEffect )
import Bootstrap.Effects.CoreRuntime.Registration.Effect
  ( coreRuntimeEffect )
import Bootstrap.Effects.CoreSurface.Registration.Effect
  ( coreSurfaceEffect )
import Bootstrap.Effect
  ( EffectTheory
  , theory
  )

coreBootstrapEffects :: EffectTheory
coreBootstrapEffects =
  theory
    [ coreModuleEffect
    , coreSurfaceEffect
    , coreBoundaryEffect
    , coreLanguageEffect
    , coreProofEffect
    , coreRegistryEffect
    , coreArtifactEffect
    , coreRuntimeEffect
    , coreExpressionEffect
    , coreReportEffect
    ]
