module Bootstrap.Effects.CoreExpression.Registration.Effect
  ( coreExpressionEffect
  ) where

import Bootstrap.Effects.CoreExpression.Facts.FrameworkCoreExpression
  ( astStructureExpressedFact
  , boundaryChecksExpressedFact
  , buildAppValidationExpressedFact
  , effectTheoryDslExpressedFact
  , frameworkCoreExpressedFact
  , frameworkCoreNativeValidatedFact
  , hyloRenderingProofSurfaceExpressedFact
  , registryCodegenExpressedFact
  , runtimeFactClosureExpressedFact
  , runtimeInterpreterExpressedFact
  )
import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectUnit
  , effect
  )

coreExpressionEffect :: EffectUnit
coreExpressionEffect =
  effect CoreExpressionEffect
    [ astStructureExpressedFact
    , effectTheoryDslExpressedFact
    , runtimeInterpreterExpressedFact
    , buildAppValidationExpressedFact
    , boundaryChecksExpressedFact
    , hyloRenderingProofSurfaceExpressedFact
    , runtimeFactClosureExpressedFact
    , registryCodegenExpressedFact
    , frameworkCoreNativeValidatedFact
    , frameworkCoreExpressedFact
    ]
