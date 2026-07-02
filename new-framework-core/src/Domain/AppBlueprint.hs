module Domain.AppBlueprint
  ( frameworkCoreApp
  , frameworkCoreBlueprint
  , frameworkCoreHooks
  ) where

import Blueprint
import Domain.Vocabulary
import Framework.Workflow
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
    FrameworkCoreFlow
    [ parallel
        ValidateStaticContractsFlow
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
  fact [AstStructureExpressedFact]

expressEffectTheoryDsl :: App
expressEffectTheoryDsl =
  fact [EffectTheoryDslExpressedFact]

expressRuntimeBranch :: App
expressRuntimeBranch =
  chain
    RuntimeBranchExpressionFlow
    [ parallel
        ValidateRuntimeFlow
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
  fact [RuntimeTypesExpressedFact]

expressRuntimePlanBuild :: App
expressRuntimePlanBuild =
  fact [RuntimePlanBuildExpressedFact]

expressRuntimeValidation :: App
expressRuntimeValidation =
  fact [RuntimeValidationExpressedFact]

expressRuntimeExecutionSemantics :: App
expressRuntimeExecutionSemantics =
  fact [RuntimeExecutionSemanticsExpressedFact]

expressRuntimeConcurrencySemantics :: App
expressRuntimeConcurrencySemantics =
  fact [RuntimeConcurrencySemanticsExpressedFact]

expressRuntimeDiagnosis :: App
expressRuntimeDiagnosis =
  fact [RuntimeDiagnosisExpressedFact]

expressRuntimeBackendAdapter :: App
expressRuntimeBackendAdapter =
  fact [RuntimeBackendAdapterExpressedFact]

expressRuntimeBackendParity :: App
expressRuntimeBackendParity =
  fact [RuntimeBackendParityExpressedFact]

expressRuntimeInterpreter :: App
expressRuntimeInterpreter =
  wait
    (allOf runtimeInterpreterInputs)
    (fact [RuntimeInterpreterExpressedFact])

expressBuildAppValidation :: App
expressBuildAppValidation =
  fact [BuildAppValidationExpressedFact]

expressBoundaryChecks :: App
expressBoundaryChecks =
  fact [BoundaryChecksExpressedFact]

expressHyloRenderingProofSurface :: App
expressHyloRenderingProofSurface =
  fact [HyloRenderingProofSurfaceExpressedFact]

expressRuntimeFactClosure :: App
expressRuntimeFactClosure =
  wait
    (allOf runtimeClosureInputs)
    (fact [RuntimeFactClosureExpressedFact])

expressRegistryCodegen :: App
expressRegistryCodegen =
  fact [RegistryCodegenExpressedFact]

expressSelfArtifactManifest :: App
expressSelfArtifactManifest =
  fact [SelfArtifactManifestExpressedFact]

validateFrameworkCoreNative :: App
validateFrameworkCoreNative =
  wait
    (allOf expressedFacts)
    (fact [FrameworkCoreNativeValidatedFact])

assertFrameworkCoreExpressed :: App
assertFrameworkCoreExpressed =
  wait
    (allOf (FrameworkCoreNativeValidatedFact : expressedFacts))
    (fact [FrameworkCoreExpressedFact])

publishBootstrapReport :: App
publishBootstrapReport =
  wait
    (allOf reportInputs)
    ( chain
        PublishBootstrapReportFlow
        [fact [FrameworkCoreReportPublishedFact]]
    )

frameworkCoreHooks :: AppHanging
frameworkCoreHooks =
  hanging
    [ middleware FrameworkCoreTraceMiddleware frameworkCoreApp
    ]

expressedFacts :: [WorkflowFact]
expressedFacts =
  [ AstStructureExpressedFact
  , EffectTheoryDslExpressedFact
  , RuntimeTypesExpressedFact
  , RuntimePlanBuildExpressedFact
  , RuntimeValidationExpressedFact
  , RuntimeExecutionSemanticsExpressedFact
  , RuntimeConcurrencySemanticsExpressedFact
  , RuntimeDiagnosisExpressedFact
  , RuntimeBackendAdapterExpressedFact
  , RuntimeBackendParityExpressedFact
  , RuntimeInterpreterExpressedFact
  , BuildAppValidationExpressedFact
  , BoundaryChecksExpressedFact
  , HyloRenderingProofSurfaceExpressedFact
  , RuntimeFactClosureExpressedFact
  , RegistryCodegenExpressedFact
  , SelfArtifactManifestExpressedFact
  ]

runtimeInterpreterInputs :: [WorkflowFact]
runtimeInterpreterInputs =
  [ RuntimeTypesExpressedFact
  , RuntimeExecutionSemanticsExpressedFact
  , RuntimeConcurrencySemanticsExpressedFact
  , RuntimeDiagnosisExpressedFact
  , RuntimeBackendAdapterExpressedFact
  , RuntimeBackendParityExpressedFact
  ]

runtimeClosureInputs :: [WorkflowFact]
runtimeClosureInputs =
  [ RuntimePlanBuildExpressedFact
  , RuntimeValidationExpressedFact
  , RuntimeExecutionSemanticsExpressedFact
  ]

reportInputs :: [WorkflowFact]
reportInputs =
  [ FrameworkCoreNativeValidatedFact
  , FrameworkCoreExpressedFact
  ]
