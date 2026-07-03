module Domain.AppBlueprint
  ( frameworkCoreApp
  , frameworkCoreBlueprint
  , frameworkCoreHooks
  ) where

import Blueprint
import Domain.Vocabulary
import Framework.Ast
  ( App
  , AppBlueprint (..)
  , AppHanging
  )

frameworkCoreBlueprint :: AppBlueprint
frameworkCoreBlueprint =
  AppBlueprint
    { blueprintApp = frameworkCoreApp
    , blueprintHanging = frameworkCoreHooks
    }

frameworkCoreApp :: App
frameworkCoreApp =
  chain
    [ parallel
        [ expressAstStructure
        , expressEffectTheoryDsl
        , expressRuntimeBranch
        , expressBuildAppValidation
        , expressBoundaryChecks
        , expressHyloRenderingProofSurface
        , expressRegistryCodegen
        , expressSelfArtifactManifest
        ]
    , validateFrameworkCoreNative
    , assertFrameworkCoreExpressed
    , publishBootstrapReport
    ]

expressAstStructure :: App
expressAstStructure =
  systemNode AstStructureExpressedFact

expressEffectTheoryDsl :: App
expressEffectTheoryDsl =
  systemNode EffectTheoryDslExpressedFact

expressRuntimeBranch :: App
expressRuntimeBranch =
  chain
    [ parallel
        [ expressRuntimeTypes
        , expressRuntimePlanBuild
        , expressRuntimeValidation
        , expressRuntimeExecutionSemantics
        , expressRuntimeConcurrencySemantics
        , expressRuntimeDiagnosis
        , expressRuntimeBackendAdapter
        , expressRuntimeBackendParity
        ]
    , expressRuntimeInterpreter
    , expressRuntimeFactClosure
    ]

expressRuntimeTypes :: App
expressRuntimeTypes =
  systemNode RuntimeTypesExpressedFact

expressRuntimePlanBuild :: App
expressRuntimePlanBuild =
  systemNode RuntimePlanBuildExpressedFact

expressRuntimeValidation :: App
expressRuntimeValidation =
  systemNode RuntimeValidationExpressedFact

expressRuntimeExecutionSemantics :: App
expressRuntimeExecutionSemantics =
  systemNode RuntimeExecutionSemanticsExpressedFact

expressRuntimeConcurrencySemantics :: App
expressRuntimeConcurrencySemantics =
  systemNode RuntimeConcurrencySemanticsExpressedFact

expressRuntimeDiagnosis :: App
expressRuntimeDiagnosis =
  systemNode RuntimeDiagnosisExpressedFact

expressRuntimeBackendAdapter :: App
expressRuntimeBackendAdapter =
  systemNode RuntimeBackendAdapterExpressedFact

expressRuntimeBackendParity :: App
expressRuntimeBackendParity =
  systemNode RuntimeBackendParityExpressedFact

expressRuntimeInterpreter :: App
expressRuntimeInterpreter =
  systemNode RuntimeInterpreterExpressedFact

expressBuildAppValidation :: App
expressBuildAppValidation =
  systemNode BuildAppValidationExpressedFact

expressBoundaryChecks :: App
expressBoundaryChecks =
  systemNode BoundaryChecksExpressedFact

expressHyloRenderingProofSurface :: App
expressHyloRenderingProofSurface =
  systemNode HyloRenderingProofSurfaceExpressedFact

expressRuntimeFactClosure :: App
expressRuntimeFactClosure =
  systemNode RuntimeFactClosureExpressedFact

expressRegistryCodegen :: App
expressRegistryCodegen =
  systemNode RegistryCodegenExpressedFact

expressSelfArtifactManifest :: App
expressSelfArtifactManifest =
  systemNode SelfArtifactManifestExpressedFact

validateFrameworkCoreNative :: App
validateFrameworkCoreNative =
  systemNode FrameworkCoreNativeValidatedFact

assertFrameworkCoreExpressed :: App
assertFrameworkCoreExpressed =
  systemNode FrameworkCoreExpressedFact

publishBootstrapReport :: App
publishBootstrapReport =
  systemNode FrameworkCoreReportPublishedFact

frameworkCoreHooks :: AppHanging
frameworkCoreHooks =
  hanging
    [ middleware FrameworkCoreTraceMiddleware frameworkCoreApp
    ]

systemNode :: WorkflowFact -> App
systemNode currentFact =
  run
    ( effectSystem
        (EffectSystemName (show currentFact))
        [currentFact]
    )
