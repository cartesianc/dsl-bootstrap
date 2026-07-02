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
        , expressRuntimeInterpreter
        , expressBuildAppValidation
        , expressBoundaryChecks
        , expressHyloRenderingProofSurface
        , expressRuntimeFactClosure
        , expressRegistryCodegen
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

expressRuntimeInterpreter :: App
expressRuntimeInterpreter =
  fact [RuntimeInterpreterExpressedFact]

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
  fact [RuntimeFactClosureExpressedFact]

expressRegistryCodegen :: App
expressRegistryCodegen =
  fact [RegistryCodegenExpressedFact]

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
  , RuntimeInterpreterExpressedFact
  , BuildAppValidationExpressedFact
  , BoundaryChecksExpressedFact
  , HyloRenderingProofSurfaceExpressedFact
  , RuntimeFactClosureExpressedFact
  , RegistryCodegenExpressedFact
  ]

reportInputs :: [WorkflowFact]
reportInputs =
  [ FrameworkCoreNativeValidatedFact
  , FrameworkCoreExpressedFact
  ]
