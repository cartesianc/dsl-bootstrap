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
  , runtimeBackendAdapterExpressedFact
  , runtimeBackendParityExpressedFact
  , runtimeConcurrencySemanticsExpressedFact
  , runtimeDiagnosisExpressedFact
  , runtimeExecutionSemanticsExpressedFact
  , runtimeFactClosureExpressedFact
  , runtimeInterpreterExpressedFact
  , runtimePlanBuildExpressedFact
  , runtimeTypesExpressedFact
  , runtimeValidationExpressedFact
  , selfArtifactManifestExpressedFact
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
    , runtimeTypesExpressedFact
    , runtimePlanBuildExpressedFact
    , runtimeValidationExpressedFact
    , runtimeExecutionSemanticsExpressedFact
    , runtimeConcurrencySemanticsExpressedFact
    , runtimeDiagnosisExpressedFact
    , runtimeBackendAdapterExpressedFact
    , runtimeBackendParityExpressedFact
    , runtimeInterpreterExpressedFact
    , buildAppValidationExpressedFact
    , boundaryChecksExpressedFact
    , hyloRenderingProofSurfaceExpressedFact
    , runtimeFactClosureExpressedFact
    , registryCodegenExpressedFact
    , selfArtifactManifestExpressedFact
    , frameworkCoreNativeValidatedFact
    , frameworkCoreExpressedFact
    ]
