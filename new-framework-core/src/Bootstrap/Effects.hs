module Bootstrap.Effects
  ( coreBootstrapEffects
  , coreBoundaryEffect
  , coreExpressionEffect
  , coreLanguageEffect
  , coreModuleEffect
  , coreProofEffect
  , coreReportEffect
  , coreRuntimeEffect
  , coreSurfaceEffect
  ) where

import Bootstrap.Effects.CoreBoundary.Registration.Effect
  ( coreBoundaryEffect )
import Bootstrap.Effects.CoreExpression.Registration.Effect
  ( coreExpressionEffect )
import Bootstrap.Effects.CoreLanguage.Registration.Effect
  ( coreLanguageEffect )
import Bootstrap.Effects.CoreModule.Registration.Effect
  ( coreModuleEffect )
import Bootstrap.Effects.CoreProof.Registration.Effect
  ( coreProofEffect )
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
    , coreRuntimeEffect
    , coreExpressionEffect
    , coreReportEffect
    ]
