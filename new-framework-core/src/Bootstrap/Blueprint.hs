module Bootstrap.Blueprint
  ( assertFrameworkCoreExpressed
  , coreBootstrapApp
  , coreBootstrapBlueprint
  , coreBootstrapHanging
  , expressAstStructure
  , expressBoundaryChecks
  , expressBuildAppValidation
  , expressEffectTheoryDsl
  , expressHyloRenderingProofSurface
  , expressRegistryCodegen
  , expressRuntimeBackendAdapter
  , expressRuntimeBackendParity
  , expressRuntimeBranch
  , expressRuntimeConcurrencySemantics
  , expressRuntimeDiagnosis
  , expressRuntimeExecutionSemantics
  , expressRuntimeFactClosure
  , expressRuntimeInterpreter
  , expressRuntimePlanBuild
  , expressRuntimeTypes
  , expressRuntimeValidation
  , expressSelfArtifactManifest
  , publishBootstrapReport
  , validateFrameworkCoreNative
  ) where

import Bootstrap.Vocabulary
import Bootstrap.Workflow
  ( App
  , AppBlueprint (..)
  , AppHanging
  , EffectSystemName (..)
  , WorkflowFact
  , chain
  , factItems
  , hanging
  , middleware
  , parallel
  , effectSystem
  , run
  )

coreBootstrapBlueprint :: AppBlueprint
coreBootstrapBlueprint =
  AppBlueprint
    { blueprintApp = coreBootstrapApp
    , blueprintHanging = coreBootstrapHanging
    }

coreBootstrapApp :: App
coreBootstrapApp =
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

coreBootstrapHanging :: AppHanging
coreBootstrapHanging =
  hanging
    [ middleware FrameworkCoreTraceMiddleware coreBootstrapApp
    ]

systemNode :: WorkflowFact -> App
systemNode currentFact =
  run
    ( effectSystem
        (EffectSystemName (show currentFact))
        (factItems [currentFact])
    )
