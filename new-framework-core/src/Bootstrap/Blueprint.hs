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
  , expressRuntimeFactClosure
  , expressRuntimeInterpreter
  , expressSelfArtifactManifest
  , publishBootstrapReport
  , validateFrameworkCoreNative
  ) where

import Bootstrap.Vocabulary
import Bootstrap.Workflow
  ( App
  , AppBlueprint (..)
  , AppHanging
  , FactExpr
  , WorkflowFact
  , chain
  , fact
  , factAll
  , factItems
  , hanging
  , middleware
  , parallel
  , wait
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
    FrameworkCoreFlow
    [ parallel
        ValidateStaticContractsFlow
        [ expressAstStructure
        , expressEffectTheoryDsl
        , expressRuntimeInterpreter
        , expressBuildAppValidation
        , expressBoundaryChecks
        , expressHyloRenderingProofSurface
        , expressRuntimeFactClosure
        , expressRegistryCodegen
        , expressSelfArtifactManifest
        ]
    , validateFrameworkCoreNative
    , assertFrameworkCoreExpressed
    , publishBootstrapReport
    ]

expressAstStructure :: App
expressAstStructure =
  factNode [AstStructureExpressedFact]

expressEffectTheoryDsl :: App
expressEffectTheoryDsl =
  factNode [EffectTheoryDslExpressedFact]

expressRuntimeInterpreter :: App
expressRuntimeInterpreter =
  factNode [RuntimeInterpreterExpressedFact]

expressBuildAppValidation :: App
expressBuildAppValidation =
  factNode [BuildAppValidationExpressedFact]

expressBoundaryChecks :: App
expressBoundaryChecks =
  factNode [BoundaryChecksExpressedFact]

expressHyloRenderingProofSurface :: App
expressHyloRenderingProofSurface =
  factNode [HyloRenderingProofSurfaceExpressedFact]

expressRuntimeFactClosure :: App
expressRuntimeFactClosure =
  factNode [RuntimeFactClosureExpressedFact]

expressRegistryCodegen :: App
expressRegistryCodegen =
  factNode [RegistryCodegenExpressedFact]

expressSelfArtifactManifest :: App
expressSelfArtifactManifest =
  factNode [SelfArtifactManifestExpressedFact]

validateFrameworkCoreNative :: App
validateFrameworkCoreNative =
  wait
    (allFacts expressedFacts)
    (factNode [FrameworkCoreNativeValidatedFact])

assertFrameworkCoreExpressed :: App
assertFrameworkCoreExpressed =
  wait
    (allFacts (FrameworkCoreNativeValidatedFact : expressedFacts))
    (factNode [FrameworkCoreExpressedFact])

publishBootstrapReport :: App
publishBootstrapReport =
  wait
    (allFacts reportInputs)
    ( chain
        PublishBootstrapReportFlow
        [factNode [FrameworkCoreReportPublishedFact]]
    )

coreBootstrapHanging :: AppHanging
coreBootstrapHanging =
  hanging
    [ middleware FrameworkCoreTraceMiddleware coreBootstrapApp
    ]

expressedFacts :: [WorkflowFact]
expressedFacts =
  [ AstStructureExpressedFact
  , EffectTheoryDslExpressedFact
  , RuntimeInterpreterExpressedFact
  , BuildAppValidationExpressedFact
  , BoundaryChecksExpressedFact
  , HyloRenderingProofSurfaceExpressedFact
  , RuntimeFactClosureExpressedFact
  , RegistryCodegenExpressedFact
  , SelfArtifactManifestExpressedFact
  ]

reportInputs :: [WorkflowFact]
reportInputs =
  [ FrameworkCoreNativeValidatedFact
  , FrameworkCoreExpressedFact
  ]

factNode :: [WorkflowFact] -> App
factNode =
  fact . factItems

allFacts :: [WorkflowFact] -> FactExpr WorkflowFact
allFacts =
  factAll . map (factItems . (: []))
