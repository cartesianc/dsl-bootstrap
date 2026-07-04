module Bootstrap.CoreSurface
  ( CoreCapability (..)
  , CoreCapabilityKind (..)
  , CoreSurfaceSlice (..)
  , CoreSurfaceModule (..)
  , coreSurfaceApp
  , coreSurfaceCapabilities
  , coreSurfaceCapabilityCount
  , coreSurfaceEffect
  , coreSurfaceFacts
  , coreSurfaceAstType
  , coreSurfaceCatalogType
  , coreSurfaceEffectTheoryType
  , coreSurfaceFormalizationType
  , coreSurfaceModuleCount
  , coreSurfaceModules
  , coreSurfaceSlices
  ) where

import Bootstrap.Vocabulary
import qualified Bootstrap.Effect as Effect
import Bootstrap.Workflow
  ( App
  , EffectSystemName (..)
  , WorkflowFact (..)
  , chain
  , factItems
  , effectSystem
  , parallel
  , run
  )

data CoreCapabilityKind
  = TypeCapability
  | ValueCapability
  | PatternCapability
  | ModuleCapability
  | RelationCapability
  deriving (Eq, Show)

data CoreCapability = CoreCapability
  { capabilityName :: String
  , capabilityKind :: CoreCapabilityKind
  , capabilityPurpose :: String
  }
  deriving (Eq, Show)

data CoreSurfaceModule = CoreSurfaceModule
  { surfaceModuleName :: String
  , surfaceModulePurpose :: String
  , surfaceModuleCapabilities :: [CoreCapability]
  , surfaceModuleSlice :: Maybe String
  , surfaceModuleRole :: Maybe String
  , surfaceModulePhase :: Maybe String
  , surfaceModuleDependsOn :: [String]
  }
  deriving (Eq, Show)

data CoreSurfaceSlice = CoreSurfaceSlice
  { coreSurfaceSliceName :: String
  , coreSurfaceSliceRole :: String
  , coreSurfaceSlicePhase :: String
  , coreSurfaceSliceModules :: [String]
  , coreSurfaceSliceDependsOn :: [String]
  , coreSurfaceSlicePurpose :: String
  }
  deriving (Eq, Show)

coreSurfaceModules :: [CoreSurfaceModule]
coreSurfaceModules =
  mergeSurfaceModules
    ( explicitCoreSurfaceModules
        ++ coreBoundaryModuleSurfaces
        ++ supplementalCoreModuleSurfaces
    )

explicitCoreSurfaceModules :: [CoreSurfaceModule]
explicitCoreSurfaceModules =
  [ astFacade
  , workflowFacade
  , workflowSemanticsFacade
  , effectFacade
  , businessFacade
  , businessEvidenceFacade
  , handlerFacade
  , bootstrapReportFacade
  , domainReportFacade
  , trustBaseFacade
  , trustBaseManifestFacade
  , fixedPointFacade
  , frontendEvidenceFacade
  , architectureConcernFacade
  , hyloFacade
  , backgroundAppBuild
  , backgroundBootstrapBoundary
  , backgroundFrontendBoundary
  , backgroundLanguage
  , backgroundElaboration
  , backgroundConstraintProof
  , backgroundEffectSemantics
  , backgroundWorkflowEff
  , backgroundWorkflowRender
  , backgroundRuntime
  , runtimeValuesFacade
  , runtimeHandlersFacade
  , runtimeInterpreterFacade
  , runtimeConcurrencyFacade
  , runtimeDiagnosisFacade
  , runtimeEvidenceFacade
  , runtimeHotPathFacade
  , runtimePolicyFacade
  , runtimeStateFacade
  , runtimeTypesFacade
  , backgroundRuntimeDiagnosis
  , registryCodegenFacade
  , selfArtifactFacade
  ]

coreBoundaryModuleSurfaces :: [CoreSurfaceModule]
coreBoundaryModuleSurfaces =
  concatMap coreSliceModuleSurfaces coreSurfaceSlices

coreSliceModuleSurfaces :: CoreSurfaceSlice -> [CoreSurfaceModule]
coreSliceModuleSurfaces currentSlice =
  [ moduleSurfaceWithRelations
      currentModuleName
      ("framework-core slice module: " ++ coreSurfaceSlicePurpose currentSlice)
      (coreSliceCapabilities currentSlice currentModuleName)
      (Just sliceName)
      (Just roleName)
      (Just phaseName)
      dependencyNames
  | currentModuleName <- expandCoreSliceModules (coreSurfaceSliceModules currentSlice)
  ]
  where
    sliceName =
      coreSurfaceSliceName currentSlice
    roleName =
      coreSurfaceSliceRole currentSlice
    phaseName =
      coreSurfaceSlicePhase currentSlice
    dependencyNames =
      coreSurfaceSliceDependsOn currentSlice

coreSliceCapabilities :: CoreSurfaceSlice -> String -> [CoreCapability]
coreSliceCapabilities _ currentModuleName =
  [moduleCapability ("module:" ++ currentModuleName)]

coreSurfaceSlices :: [CoreSurfaceSlice]
coreSurfaceSlices =
  [ CoreSurfaceSlice
      { coreSurfaceSliceName = "CoreSyntax"
      , coreSurfaceSliceRole = "pure-core"
      , coreSurfaceSlicePhase = "minimal-core-freeze"
      , coreSurfaceSliceModules =
          [ "Core.Architecture"
          , "Core.Architecture.Internal"
          , "Core.Architecture.Cata.Types"
          ]
      , coreSurfaceSliceDependsOn = []
      , coreSurfaceSlicePurpose = "workflow and hanging AST vocabulary"
      }
  , CoreSurfaceSlice
      { coreSurfaceSliceName = "CoreLanguageSpec"
      , coreSurfaceSliceRole = "pure-core"
      , coreSurfaceSlicePhase = "minimal-core-freeze"
      , coreSurfaceSliceModules =
          [ "Core.Language"
          , "Core.Language.Spec"
          , "Core.Language.Validation"
          , "Core.Language.Constraint"
          , "Core.Language.Elaboration"
          ]
      , coreSurfaceSliceDependsOn = []
      , coreSurfaceSlicePurpose = "frontend keyword contracts, argument shapes, parent contexts, lowering targets, and elaborator bindings"
      }
  , CoreSurfaceSlice
      { coreSurfaceSliceName = "CoreRecursion"
      , coreSurfaceSliceRole = "pure-core"
      , coreSurfaceSlicePhase = "minimal-core-freeze"
      , coreSurfaceSliceModules =
          [ "Core.Architecture.Cata"
          , "Core.Architecture.Recursion"
          , "Core.Workflow.Eff"
          , "Core.Workflow.Semantics"
          , "Core.Workflow.Semantics.Render"
          ]
      , coreSurfaceSliceDependsOn = ["CoreSyntax"]
      , coreSurfaceSlicePurpose = "fold/unfold compatible workflow lowering and interpretation algebra surface"
      }
  , CoreSurfaceSlice
      { coreSurfaceSliceName = "CoreHylo"
      , coreSurfaceSliceRole = "pure-core"
      , coreSurfaceSlicePhase = "minimal-core-freeze"
      , coreSurfaceSliceModules =
          [ "Core.App.Ana"
          ]
      , coreSurfaceSliceDependsOn = ["CoreSyntax", "CoreEffectTheory"]
      , coreSurfaceSlicePurpose = "seed and coalgebra entry for restoring or generating app/effect declarations"
      }
  , CoreSurfaceSlice
      { coreSurfaceSliceName = "CoreEffectTheory"
      , coreSurfaceSliceRole = "pure-core"
      , coreSurfaceSlicePhase = "minimal-core-freeze"
      , coreSurfaceSliceModules =
          [ "Effects.EffectTheory"
          , "Effects.Names"
          , "Core.Effect.Semantics"
          ]
      , coreSurfaceSliceDependsOn = []
      , coreSurfaceSlicePurpose = "effect declarations, take/make/transform semantics, canonical boundaries, and send/transform contracts"
      }
  , CoreSurfaceSlice
      { coreSurfaceSliceName = "CoreAppBuild"
      , coreSurfaceSliceRole = "pure-core"
      , coreSurfaceSlicePhase = "minimal-core-freeze"
      , coreSurfaceSliceModules =
          [ "Core.Validation"
          , "Core.App.ClaimScope"
          , "Core.App"
          ]
      , coreSurfaceSliceDependsOn = ["CoreSyntax", "CoreEffectTheory"]
      , coreSurfaceSlicePurpose = "build AppPlan from blueprint and effect theory, including AST and effect completeness checks"
      }
  , CoreSurfaceSlice
      { coreSurfaceSliceName = "CoreConstraintIR"
      , coreSurfaceSliceRole = "pure-core"
      , coreSurfaceSlicePhase = "minimal-core-freeze"
      , coreSurfaceSliceModules =
          [ "Core.Effect.Constraint"
          ]
      , coreSurfaceSliceDependsOn = ["CoreSyntax", "CoreEffectTheory", "CoreAppBuild"]
      , coreSurfaceSlicePurpose = "constraint facts and local validation evidence extracted from AppPlan"
      }
  , CoreSurfaceSlice
      { coreSurfaceSliceName = "CoreProofBoundary"
      , coreSurfaceSliceRole = "verification-backend"
      , coreSurfaceSlicePhase = "minimal-core-freeze"
      , coreSurfaceSliceModules =
          [ "Core.App.Boundary"
          ]
      , coreSurfaceSliceDependsOn = ["CoreAppBuild", "CoreConstraintIR", "CoreHylo"]
      , coreSurfaceSlicePurpose = "minimal core report that joins AppPlan and Constraint IR for proof and bootstrap"
      }
  , CoreSurfaceSlice
      { coreSurfaceSliceName = "CoreSmtBackend"
      , coreSurfaceSliceRole = "verification-backend"
      , coreSurfaceSlicePhase = "smt-backend"
      , coreSurfaceSliceModules =
          [ "Core.Effect.Constraint.SMT"
          ]
      , coreSurfaceSliceDependsOn = ["CoreProofBoundary"]
      , coreSurfaceSlicePurpose = "SMT/proof backend adapter over the minimal core report"
      }
  , CoreSurfaceSlice
      { coreSurfaceSliceName = "CoreFrontendFacade"
      , coreSurfaceSliceRole = "frontend-facade"
      , coreSurfaceSlicePhase = "minimal-core-freeze"
      , coreSurfaceSliceModules =
          [ "Framework.Ast"
          , "Framework.Workflow"
          , "Framework.Effect"
          , "Framework.Business"
          , "Framework.Hylo"
          ]
      , coreSurfaceSliceDependsOn = ["CoreSyntax", "CoreLanguageSpec", "CoreEffectTheory", "CoreHylo"]
      , coreSurfaceSlicePurpose = "public frontend import surface for AST, effect, business, workflow, and hylo declarations"
      }
  , CoreSurfaceSlice
      { coreSurfaceSliceName = "CoreFrontendBoundary"
      , coreSurfaceSliceRole = "verification-backend"
      , coreSurfaceSlicePhase = "minimal-core-freeze"
      , coreSurfaceSliceModules =
          [ "Core.Boundary.Frontend"
          ]
      , coreSurfaceSliceDependsOn = ["CoreFrontendFacade"]
      , coreSurfaceSlicePurpose = "frontend import boundary IR and checker for the public facade"
      }
  , CoreSurfaceSlice
      { coreSurfaceSliceName = "CoreRuntimeAdapter"
      , coreSurfaceSliceRole = "runtime-backend"
      , coreSurfaceSlicePhase = "self-bootstrap"
      , coreSurfaceSliceModules =
          [ "Bootstrap.Runtime"
          , "Bootstrap.Runtime.BootstrapHandlers"
          , "Bootstrap.Runtime.Boundary"
          , "Bootstrap.Runtime.Build"
          , "Bootstrap.Runtime.Contract"
          , "Bootstrap.Runtime.Interpreter"
          , "Bootstrap.Runtime.SourceGraph"
          , "Bootstrap.Runtime.Types"
          , "Framework.Handler"
          , "Framework.Runtime"
          , "Framework.Runtime.Interpreter"
          , "Framework.Runtime.Diagnosis"
          , "Framework.Runtime.Handlers"
          , "Framework.Runtime.HotPath"
          , "Framework.Runtime.Policy"
          , "Framework.Runtime.State"
          , "Framework.Runtime.Values"
          , "Framework.TrustBase"
          , "Framework.Background.RuntimeDiagnosis"
          ]
      , coreSurfaceSliceDependsOn = ["CoreRecursion", "CoreEffectTheory", "CoreAppBuild"]
      , coreSurfaceSlicePurpose = "single runtime semantics exposed through bootstrap, handler, trust-base, and typed backend adapters"
      }
  ]

expandCoreSliceModules :: [String] -> [String]
expandCoreSliceModules =
  concatMap expandCoreSliceModule

expandCoreSliceModule :: String -> [String]
expandCoreSliceModule "Interpreter.Runtime.Workflow.*" =
  runtimeWorkflowModules
expandCoreSliceModule currentModule =
  [currentModule]

runtimeWorkflowModules :: [String]
runtimeWorkflowModules =
  [ "Interpreter.Runtime.Workflow.Choice"
  , "Interpreter.Runtime.Workflow.FreeAlternative"
  , "Interpreter.Runtime.Workflow.FreeApplicative"
  , "Interpreter.Runtime.Workflow.FreeMonad"
  , "Interpreter.Runtime.Workflow.Node"
  , "Interpreter.Runtime.Workflow.Wait"
  ]

supplementalCoreModuleSurfaces :: [CoreSurfaceModule]
supplementalCoreModuleSurfaces =
  map (uncurry supplementalCoreModule)
    [ ("AST.AppBlueprint", "AST data structure")
    , ("AST.Facts", "AST data structure")
    , ("AST.Interceptors", "AST data structure")
    , ("AST.Names", "AST data structure")
    , ("AST.Vocabulary", "AST data structure")
    , ("Core.Bootstrap", "boundary checks")
    , ("Core.ImportGraph", "boundary checks")
    , ("Bootstrap.RegistryCodegen", "framework-core frontend codegen source")
    , ("Framework.Background", "background compatibility facade expressed as a target module")
    , ("FrameworkCore.BaseApp", "framework-core readable frontend")
    , ("FrameworkCore.CurrentApp", "framework-core readable frontend")
    , ("FrameworkCore.CurrentAst", "framework-core readable frontend")
    , ("FrameworkCore.CurrentEffects", "framework-core readable frontend")
    , ("FrameworkCore.CurrentInterpreter", "framework-core readable frontend")
    , ("Interpreter", "legacy interpreter facade")
    , ("Interpreter.Contextware", "legacy interpreter facade")
    , ("Interpreter.EffectAlgebra", "legacy interpreter facade")
    , ("Interpreter.FAlgebra", "legacy interpreter facade")
    , ("Interpreter.RecursionModel", "legacy interpreter facade")
    , ("Interpreter.Types", "legacy interpreter facade")
    , ("Interpreter.WorkflowAlgebra", "legacy interpreter facade")
    , ("Bootstrap.Report", "runtime evidence and framework-core report")
    , ("Framework.Domain", "domain runtime backend selection and reporting")
    , ("Interpreter.View.Algebra", "hylo/rendering/proof surface")
    , ("Interpreter.View.Hanging.FreeMonoid", "hylo/rendering/proof surface")
    , ("Interpreter.View.Program", "hylo/rendering/proof surface")
    , ("Interpreter.View.Workflow.Choice", "hylo/rendering/proof surface")
    , ("Interpreter.View.Workflow.FreeAlternative", "hylo/rendering/proof surface")
    , ("Interpreter.View.Workflow.FreeApplicative", "hylo/rendering/proof surface")
    , ("Interpreter.View.Workflow.FreeMonad", "hylo/rendering/proof surface")
    , ("Interpreter.View.Workflow.Wait", "hylo/rendering/proof surface")
    ]

supplementalCoreModule :: String -> String -> CoreSurfaceModule
supplementalCoreModule currentModuleName currentGroup =
  moduleSurfaceWithRelations
    currentModuleName
    ("framework-core supplemental module group: " ++ currentGroup)
    [moduleCapability ("module:" ++ currentModuleName)]
    (Just currentGroup)
    Nothing
    Nothing
    []

coreSurfaceCapabilities :: [(CoreSurfaceModule, CoreCapability)]
coreSurfaceCapabilities =
  [ (currentModule, currentCapability)
  | currentModule <- coreSurfaceModules
  , currentCapability <- surfaceModuleCapabilities currentModule
  ]

coreSurfaceModuleCount :: Int
coreSurfaceModuleCount =
  length coreSurfaceModules

coreSurfaceCapabilityCount :: Int
coreSurfaceCapabilityCount =
  length coreSurfaceCapabilities

coreSurfaceFacts :: [WorkflowFact]
coreSurfaceFacts =
  [CoreSurfaceCatalogLoadedFact]
    ++ map coreSurfaceModuleFact coreSurfaceModules
    ++ map (uncurry coreSurfaceCapabilityFact) coreSurfaceCapabilities
    ++ [ CoreSurfaceAstFormalizedFact
       , CoreSurfaceEffectTheoryFormalizedFact
       , CoreSurfaceFormalizedFact
       ]

coreSurfaceApp :: App
coreSurfaceApp =
  chain
    [ factNode [CoreSurfaceCatalogLoadedFact]
    , parallel (map coreSurfaceModuleApp coreSurfaceModules)
    , factNode [CoreSurfaceAstFormalizedFact]
    , factNode [CoreSurfaceEffectTheoryFormalizedFact]
    , factNode [CoreSurfaceFormalizedFact]
    ]

coreSurfaceModuleApp :: CoreSurfaceModule -> App
coreSurfaceModuleApp currentModule =
  chain
    [ factNode [coreSurfaceModuleFact currentModule]
    , parallel
        (map (factNode . (: []) . coreSurfaceCapabilityFact currentModule) (surfaceModuleCapabilities currentModule))
    ]

coreSurfaceEffect :: Effect.EffectUnit
coreSurfaceEffect =
  Effect.effect
    CoreSurfaceEffect
    ( coreSurfaceCatalogSection
        ++ coreSurfaceModuleSections
        ++ coreSurfaceCapabilitySections
        ++ coreSurfaceCompletionSections
        ++ coreSurfaceSendSections
    )

coreSurfaceCatalogSection :: [Effect.EffectSection]
coreSurfaceCatalogSection =
  [ Effect.fact
      CoreSurfaceCatalogLoadedFact
      [ Effect.uses LoadCoreSurfaceCatalog
      , Effect.make coreSurfaceCatalogType
      ]
  ]

coreSurfaceModuleSections :: [Effect.EffectSection]
coreSurfaceModuleSections =
  [ Effect.fact
      (coreSurfaceModuleFact currentModule)
      [ Effect.needs CoreSurfaceCatalogLoadedFact
      , Effect.uses FormalizeCoreSurfaceModule
      , Effect.take coreSurfaceCatalogType
      , Effect.make (coreSurfaceModuleAstType currentModule)
      ]
  | currentModule <- coreSurfaceModules
  ]

coreSurfaceCapabilitySections :: [Effect.EffectSection]
coreSurfaceCapabilitySections =
  [ Effect.fact
      (coreSurfaceCapabilityFact currentModule currentCapability)
      [ Effect.needs (coreSurfaceModuleFact currentModule)
      , Effect.uses FormalizeCoreSurfaceCapability
      , Effect.take (coreSurfaceModuleAstType currentModule)
      , Effect.make (coreSurfaceCapabilityAstType currentModule currentCapability)
      ]
  | (currentModule, currentCapability) <- coreSurfaceCapabilities
  ]

coreSurfaceCompletionSections :: [Effect.EffectSection]
coreSurfaceCompletionSections =
  [ Effect.fact
      CoreSurfaceAstFormalizedFact
      ( map (Effect.needs . uncurry coreSurfaceCapabilityFact) coreSurfaceCapabilities
          ++ map (Effect.take . uncurry coreSurfaceCapabilityAstType) coreSurfaceCapabilities
          ++ [ Effect.uses ComposeCoreSurfaceAst
             , Effect.make coreSurfaceAstType
             ]
      )
  , Effect.fact
      CoreSurfaceEffectTheoryFormalizedFact
      [ Effect.needs CoreSurfaceAstFormalizedFact
      , Effect.uses CompileCoreSurfaceEffectTheory
      , Effect.take coreSurfaceAstType
      , Effect.make coreSurfaceEffectTheoryType
      ]
  , Effect.fact
      CoreSurfaceFormalizedFact
      [ Effect.needs CoreSurfaceEffectTheoryFormalizedFact
      , Effect.take coreSurfaceEffectTheoryType
      , Effect.make coreSurfaceFormalizationType
      ]
  ]

coreSurfaceSendSections :: [Effect.EffectSection]
coreSurfaceSendSections =
  [ Effect.externalMake LoadCoreSurfaceCatalog Effect.NoInput coreSurfaceCatalogType
  , Effect.externalMake FormalizeCoreSurfaceModule coreSurfaceCatalogType Effect.Unit
  , Effect.externalMake FormalizeCoreSurfaceCapability Effect.NoInput Effect.Unit
  , Effect.externalMake ComposeCoreSurfaceAst Effect.NoInput coreSurfaceAstType
  , Effect.externalMake CompileCoreSurfaceEffectTheory coreSurfaceAstType coreSurfaceEffectTheoryType
  , Effect.idempotent LoadCoreSurfaceCatalog
  , Effect.idempotent FormalizeCoreSurfaceModule
  , Effect.idempotent FormalizeCoreSurfaceCapability
  , Effect.idempotent ComposeCoreSurfaceAst
  , Effect.idempotent CompileCoreSurfaceEffectTheory
  ]

coreSurfaceModuleFact :: CoreSurfaceModule -> WorkflowFact
coreSurfaceModuleFact currentModule =
  WorkflowFact ("CoreSurfaceModuleFormalized:" ++ surfaceModuleName currentModule)

coreSurfaceCapabilityFact :: CoreSurfaceModule -> CoreCapability -> WorkflowFact
coreSurfaceCapabilityFact currentModule currentCapability =
  WorkflowFact
    ( "CoreSurfaceCapabilityFormalized:"
        ++ surfaceModuleName currentModule
        ++ ":"
        ++ capabilityName currentCapability
    )

coreSurfaceCatalogType :: Effect.TypeName
coreSurfaceCatalogType =
  Effect.TypeName "CoreSurfaceCatalog"

coreSurfaceAstType :: Effect.TypeName
coreSurfaceAstType =
  Effect.TypeName "CoreSurfaceAst"

coreSurfaceEffectTheoryType :: Effect.TypeName
coreSurfaceEffectTheoryType =
  Effect.TypeName "CoreSurfaceEffectTheory"

coreSurfaceFormalizationType :: Effect.TypeName
coreSurfaceFormalizationType =
  Effect.TypeName "CoreSurfaceFormalization"

coreSurfaceModuleAstType :: CoreSurfaceModule -> Effect.TypeName
coreSurfaceModuleAstType currentModule =
  Effect.TypeName ("CoreSurfaceModuleAst:" ++ surfaceModuleName currentModule)

coreSurfaceCapabilityAstType :: CoreSurfaceModule -> CoreCapability -> Effect.TypeName
coreSurfaceCapabilityAstType currentModule currentCapability =
  Effect.TypeName
    ( "CoreSurfaceCapabilityAst:"
        ++ surfaceModuleName currentModule
        ++ ":"
        ++ capabilityName currentCapability
    )

factNode :: [WorkflowFact] -> App
factNode currentFacts =
  run
    ( effectSystem
        (EffectSystemName (show currentFacts))
        (factItems currentFacts)
    )

astFacade :: CoreSurfaceModule
astFacade =
  moduleSurface
    "Framework.Ast"
    "frontend AST facade for app blueprints, workflow structure, hanging hooks, facts, and names"
    (surfaceModuleCapabilities workflowFacade)

workflowFacade :: CoreSurfaceModule
workflowFacade =
  moduleSurface
    "Framework.Workflow"
    "frontend workflow AST vocabulary and constructors"
    ( map typeCapability
        [ "AppBlueprint"
        , "App"
        , "AppHanging"
        , "WorkflowFact"
        , "Interceptor"
        , "EffectSystemName"
        , "EffectSystem"
        , "EffectSystemBoundaryArtifact"
        , "EffectSystemBoundary"
        , "EffectSystemBoundaryHandler"
        , "EffectSystemBoundaryPipeline"
        , "EffectSystemBoundaryPolicy"
        , "EffectSystemBoundarySend"
        , "EffectSystemBoundaryTransform"
        , "Chain"
        , "Parallel"
        , "Middleware"
        , "Fallback"
        , "Race"
        , "Choice"
        , "Callback"
        , "Wait"
        , "Suspense"
        , "Loop"
        , "FactExpr"
        , "Hanging"
        , "HangingAction"
        , "ChoiceKey"
        , "Requirement"
        , "Workflow"
        ]
        ++ map valueCapability
          [ "freeChain"
          , "freeParallel"
          , "freeFallback"
          , "freeRace"
          , "freeChoice"
          , "freeWait"
          , "freeHanging"
          , "freeRequirement"
          , "chainItems"
          , "parallelItems"
          , "fallbackItems"
          , "raceItems"
          , "choiceItems"
          , "hangingItems"
          , "requirementItems"
          , "factItems"
          , "factAll"
          , "factAny"
          , "effectSystem"
          , "effectSystemBoundary"
          , "effectSystemBoundaryExplicit"
          , "effectSystemBoundaryHandlerName"
          , "effectSystemBoundaryHandlerSend"
          , "effectSystemBoundaryHandlers"
          , "effectSystemBoundaryPipelineArtifacts"
          , "effectSystemBoundaryPipelineName"
          , "effectSystemBoundaryPolicies"
          , "effectSystemBoundaryPipelines"
          , "effectSystemBoundarySends"
          , "effectSystemBoundaryTransforms"
          , "effectSystemFromBoundary"
          , "effectSystemRuntimeFacts"
          , "boundaryArtifact"
          , "boundaryHandler"
          , "boundaryIdempotent"
          , "boundaryPipeline"
          , "boundaryRetryOnce"
          , "boundarySend"
          , "boundaryTransform"
          , "run"
          , "chain"
          , "parallel"
          , "middleware"
          , "fallback"
          , "race"
          , "choice"
          , "callback"
          , "wait"
          , "hanging"
          , "suspense"
          , "systemBoundary"
          , "systemBoundaryWithContracts"
          , "systemBoundaryWithHandlers"
          , "systemBoundaryWithPipelines"
          , "systemBoundaryWithPolicies"
          , "loop"
          ]
    )

workflowSemanticsFacade :: CoreSurfaceModule
workflowSemanticsFacade =
  moduleSurface
    "Framework.Workflow.Semantics"
    "machine-readable workflow semantics evidence payload model"
    ( map typeCapability
        [ "WorkflowSemanticsEvidencePayload"
        , "WorkflowSemanticsEvidenceStatus"
        ]
        ++ map valueCapability
          [ "renderWorkflowSemanticsEvidencePayload"
          , "renderWorkflowSemanticsEvidencePayloadsJson"
          , "renderWorkflowSemanticsEvidenceStatus"
          , "workflowSemanticsCoreClaimNames"
          , "workflowSemanticsEvidenceClaimNames"
          , "workflowSemanticsEvidencePayloadPassed"
          ]
    )

effectFacade :: CoreSurfaceModule
effectFacade =
  moduleSurface
    "Framework.Effect"
    "frontend effect theory vocabulary and producer declarations"
    ( map typeCapability
        [ "EffectSection"
        , "EffectSystemClause"
        , "EffectSystemHandler"
        , "EffectSystemPipeline"
        , "EffectTheory"
        , "EffectUnit"
        , "ExternalTakeBoundary"
        , "ExternalTakeClaim"
        , "FactClaim"
        , "FactProducer"
        , "IdempotencyPolicy"
        , "ProducerStep"
        , "RetryPolicy"
        , "SendBoundary"
        , "SendPolicy"
        , "SendSignature"
        , "WorkflowFact"
        , "EffectName"
        , "HandlerName"
        , "SendName"
        , "TransformName"
        , "TypeName"
        ]
        ++ map valueCapability
          [ "effect"
          , "error"
          , "effectSystem"
          , "effectUnitBoundary"
          , "effectUnitProducedFacts"
          , "effectUnitSystem"
          , "exports"
          , "externalMake"
          , "externalTake"
          , "handler"
          , "idempotent"
          , "imports"
          , "make"
          , "needs"
          , "onFailure"
          , "pipeline"
          , "privateFacts"
          , "retry"
          , "take"
          , "theory"
          , "transform"
          , "uses"
          ]
        ++ map patternCapability
          [ "ErrorInput"
          , "NoInput"
          , "Unit"
          ]
    )

businessFacade :: CoreSurfaceModule
businessFacade =
  moduleSurface
    "Framework.Business"
    "frontend business capability, pipeline, policy, handler binding, and transform binding syntax"
    ( map typeCapability
        [ "BusinessShapeIssue"
        , "Capability"
        , "CapabilityClause"
        , "CapabilityPolicy"
        , "CapabilityUse"
        , "HandlerBindingSpec"
        , "Pipeline"
        , "TransformBindingSpec"
        ]
        ++ map valueCapability
          [ "businessShapePassed"
          , "capabilitiesEffect"
          , "capability"
          , "capabilityEffectSections"
          , "capabilityEffectSystem"
          , "capabilityEffectSystemBoundary"
          , "checkBusinessShape"
          , "handler"
          , "handlerBinding"
          , "idempotentPolicy"
          , "input"
          , "onError"
          , "output"
          , "pipeline"
          , "pipelineTransformCandidates"
          , "privateFact"
          , "policy"
          , "produces"
          , "renderBusinessShapeIssue"
          , "requires"
          , "retryOnce"
          , "transform"
          , "transformBinding"
          , "uses"
          ]
    )

businessEvidenceFacade :: CoreSurfaceModule
businessEvidenceFacade =
  moduleSurface
    "Framework.Business.Evidence"
    "business capability frontend evidence payload model and claim manifest"
    ( map typeCapability
        [ "BusinessSyntaxEvidencePayload"
        , "BusinessSyntaxEvidenceStatus"
        ]
        ++ map valueCapability
        [ "businessSyntaxClaimManifestEvidenceClaimName"
        , "businessSyntaxCoreClaimNames"
        , "businessSyntaxEvidence"
        , "businessSyntaxEvidenceArtifactSummary"
        , "businessSyntaxEvidenceClaimNames"
        , "businessSyntaxEvidencePayloadPassed"
        , "renderBusinessSyntaxEvidencePayloadsJson"
        , "renderBusinessSyntaxEvidenceStatus"
        ]
    )

handlerFacade :: CoreSurfaceModule
handlerFacade =
  moduleSurface
    "Framework.Handler"
    "handler implementation facade for typed values, handlers, transforms, and registries"
    ( map typeCapability
        [ "ErrorInputValue"
        , "HandlerBinding"
        , "HandlerName"
        , "HandlerInput"
        , "HandlerRegistry"
        , "HandlerResult"
        , "NoInputValue"
        , "Runtime"
        , "RuntimeEffectEnvironment"
        , "RuntimeHandler"
        , "RuntimeTransform"
        , "RuntimeTypedValue"
        , "RuntimeValue"
        , "SendName"
        , "SomeRuntimeValue"
        , "TransformBinding"
        , "TransformName"
        , "TransformRegistry"
        , "TypeName"
        , "UnitValue"
        , "ValueTag"
        ]
        ++ map valueCapability
          [ "emptyHandlerRegistry"
          , "emptyTransformRegistry"
          , "handlerFor"
          , "handlerInputFromTypedValues"
          , "handlerInputFromValues"
          , "runtimeEffectEnvironment"
          , "runtimeEffectEnvironmentWithTransforms"
          , "runtimeTransformInput"
          , "runtimeTransformOutput"
          , "runtimeTypedValueText"
          , "runtimeTypedValueToRuntimeValue"
          , "runtimeTypedValueType"
          , "runtimeValueToSome"
          , "sameValueTag"
          , "someRuntimeValueText"
          , "someRuntimeValueToRuntimeValue"
          , "someRuntimeValueType"
          , "transformFor"
          , "typedValueFor"
          , "typedValueFromSome"
          , "valueTagTypeName"
          ]
    )

bootstrapReportFacade :: CoreSurfaceModule
bootstrapReportFacade =
  moduleSurface
    "Bootstrap.Report"
    "framework-core report model and machine-readable JSON renderer"
    ( map typeCapability
        [ "ConstraintReport"
        , "FactClosureReport"
        , "FrameworkCoreReport"
        , "FrameworkCoreReportStatus"
        , "HandlerCoverage"
        ]
        ++ map valueCapability
          [ "buildFrameworkCoreReport"
          , "frameworkCoreReportPassed"
          , "printFrameworkCoreReport"
          , "renderConstraintReport"
          , "renderFactClosureReport"
          , "renderFrameworkCoreReport"
          , "renderFrameworkCoreReportJson"
          , "renderHandlerCoverage"
          ]
    )

domainReportFacade :: CoreSurfaceModule
domainReportFacade =
  moduleSurface
    "Framework.Domain"
    "domain runtime backend selection, report model, and machine-readable JSON renderer"
    ( map typeCapability
        [ "DomainEffectHandlerRegistration"
        , "DomainHandlerCoverage"
        , "DomainReport"
        , "DomainReportStatus"
        , "DomainRegistration"
        , "DomainRuntimeBackend"
        , "DomainSemanticCheck"
        , "DomainSemanticEvidence"
        , "DomainSemanticEvidencePayload"
        , "DomainSemanticEvidenceStatus"
        ]
        ++ map valueCapability
          [ "buildDomainReport"
          , "domain"
          , "domainEvidenceFailed"
          , "domainEvidenceFailedWithPayload"
          , "domainEvidencePassed"
          , "domainEvidencePassedWithPayload"
          , "domainReportSemanticEvidencePassed"
          , "domainSemanticEvidencePassed"
          , "domainWithRuntime"
          , "domainWithRuntimeAndEvidence"
          , "frameworkCoreDomain"
          , "frameworkCoreFacadeDomain"
          , "renderDomainReport"
          , "renderDomainReportJson"
          , "runDomain"
          ]
    )

trustBaseFacade :: CoreSurfaceModule
trustBaseFacade =
  moduleSurface
    "Framework.TrustBase"
    "framework self-iteration facade for bootstrap runtime, evidence, diagnosis, reports, codegen, fixed point, and artifact gates"
    ( map typeCapability
        [ "TrustBaseRuntimeEffectEnvironment"
        , "NativeAppPlan"
        , "NativeConstraint"
        , "NativeFactRule"
        , "NativeRuntime"
        , "RuntimeArtifact"
        , "SendContract"
        , "Runtime"
        , "RuntimeResult"
        , "RuntimeFailureDiagnosis"
        , "RuntimeDiagnosisNode"
        , "RuntimeDiagnosisProbe"
        , "RuntimeDiagnosisRootCause"
        , "RuntimeDiagnosisStep"
        , "RuntimeDiagnosisEvidencePayload"
        , "RuntimeDiagnosisEvidenceStatus"
        , "RuntimeConcurrencyEvidencePayload"
        , "RuntimeConcurrencyEvidenceStatus"
        , "RuntimeEvidencePayload"
        , "RuntimeEvidenceStatus"
        , "RuntimeHotPathEvidencePayload"
        , "RuntimeHotPathEvidenceStatus"
        , "RuntimePolicyEvidencePayload"
        , "RuntimePolicyEvidenceStatus"
        , "DomainRegistration"
        , "DomainSemanticCheck"
        , "DomainSemanticEvidence"
        , "FixedPointReport"
        , "FixedPointDiffEvidencePayload"
        , "FixedPointDiffEvidenceStatus"
        , "RuntimeBackendParityEvidencePayload"
        , "RuntimeBackendParityEvidenceStatus"
        , "ArtifactManifest"
        , "TrustBaseManifest"
        , "TrustBaseManifestEvidencePayload"
        , "TrustBaseManifestEvidenceStatus"
        , "SchemaCatalogEvidencePayload"
        , "SchemaCatalogEvidenceStatus"
        , "TrustBaseGatePolicy"
        , "WorkflowSemanticsEvidencePayload"
        , "WorkflowSemanticsEvidenceStatus"
        , "GeneratedSource"
        ]
        ++ map valueCapability
          [ "bootstrapRuntimeEffectEnvironment"
          , "buildApp"
          , "buildNativeApp"
          , "runNativeBlueprintWithEffectEnvironment"
          , "runNativeBlueprintWithEffectEnvironmentResult"
          , "runBlueprintWithEffectEnvironment"
          , "runBlueprintWithEffectEnvironmentResult"
          , "runBlueprintWithEffectEnvironmentRuntimeResult"
          , "buildFailureDiagnosis"
          , "buildFailureDiagnosisWithSystem"
          , "renderRuntimeDiagnosisEvidencePayload"
          , "renderRuntimeDiagnosisEvidencePayloadsJson"
          , "runtimeDiagnosisEvidenceArtifactSummary"
          , "runtimeDiagnosisEvidenceClaimNames"
          , "runtimeDiagnosisEvidencePayloadPassed"
          , "domainEvidencePassed"
          , "domainEvidenceFailed"
          , "renderRuntimeConcurrencyEvidencePayload"
          , "renderRuntimeConcurrencyEvidencePayloadsJson"
          , "renderRuntimeConcurrencyEvidenceStatus"
          , "runtimeConcurrencyEvidenceArtifactSummary"
          , "runtimeConcurrencyEvidenceClaimNames"
          , "runtimeConcurrencyEvidencePayloadPassed"
          , "runtimeConcurrencyEvidencePayloads"
          , "renderRuntimeEvidencePayload"
          , "renderRuntimeEvidencePayloadsJson"
          , "renderRuntimeEvidenceStatus"
          , "runtimeEvidenceArtifactSummary"
          , "runtimeEvidenceClaimNames"
          , "runtimeEvidencePayloadPassed"
          , "runtimeEvidencePayloads"
          , "renderRuntimeHotPathEvidencePayload"
          , "renderRuntimeHotPathEvidencePayloadsJson"
          , "renderRuntimeHotPathEvidenceStatus"
          , "runtimeHotPathEvidenceArtifactSummary"
          , "runtimeHotPathEvidenceClaimNames"
          , "runtimeHotPathEvidencePayloadPassed"
          , "runtimeHotPathEvidencePayloads"
          , "renderRuntimePolicyEvidencePayload"
          , "renderRuntimePolicyEvidencePayloadsJson"
          , "renderRuntimePolicyEvidenceStatus"
          , "runtimePolicyEvidenceArtifactSummary"
          , "runtimePolicyEvidenceClaimNames"
          , "runtimePolicyEvidencePayloadPassed"
          , "runtimePolicyEvidencePayloads"
          , "diffGeneratedLines"
          , "generatedLinesMatch"
          , "buildFixedPointReport"
          , "fixedPointDiffEvidencePayloadPassed"
          , "fixedPointDiffEvidencePayloads"
          , "renderFixedPointDiffEvidencePayload"
          , "renderFixedPointDiffEvidenceStatus"
          , "renderFixedPointReportJson"
          , "renderFixedPointReportSummaryJson"
          , "renderRuntimeBackendParityEvidencePayload"
          , "renderRuntimeBackendParityEvidenceStatus"
          , "runtimeBackendParityEvidenceArtifactSummary"
          , "runtimeBackendParityEvidenceClaimNames"
          , "runtimeBackendParityEvidencePayloadPassed"
          , "runtimeBackendParityEvidencePayloads"
          , "runSelfArtifactGate"
          , "defaultTrustBaseManifest"
          , "renderTrustBaseManifest"
          , "renderTrustBaseManifestEvidencePayload"
          , "renderTrustBaseManifestEvidencePayloadsJson"
          , "renderTrustBaseManifestEvidenceStatus"
          , "renderTrustBaseManifestJson"
          , "trustBaseManifestEvidenceArtifactSummary"
          , "trustBaseManifestEvidenceClaimNames"
          , "trustBaseManifestEvidencePayloadPassed"
          , "renderSchemaCatalogEvidencePayload"
          , "renderSchemaCatalogEvidencePayloadsJson"
          , "renderSchemaCatalogEvidenceStatus"
          , "schemaCatalogEvidence"
          , "schemaCatalogEvidencePayloadPassed"
          , "trustBaseManifestRequiredCoreSurfaceModules"
          , "trustBaseManifestRequiredGatePolicies"
          , "trustBaseManifestRequiredJsonSchemas"
          , "renderWorkflowSemanticsEvidencePayload"
          , "renderWorkflowSemanticsEvidencePayloadsJson"
          , "workflowSemanticsCoreClaimNames"
          , "workflowSemanticsEvidenceClaimNames"
          , "workflowSemanticsEvidencePayloadPassed"
          ]
    )

trustBaseManifestFacade :: CoreSurfaceModule
trustBaseManifestFacade =
  moduleSurface
    "Framework.TrustBase.Manifest"
    "machine-readable trust base boundary, gate inventory, and artifact manifest summary"
    ( map typeCapability
        [ "TrustBaseManifest"
        , "TrustBaseManifestEvidencePayload"
        , "TrustBaseManifestEvidenceStatus"
        , "SchemaCatalogEvidencePayload"
        , "SchemaCatalogEvidenceStatus"
        , "TrustBaseGatePolicy"
        ]
        ++ map valueCapability
          [ "defaultTrustBaseManifest"
          , "renderTrustBaseManifest"
          , "renderTrustBaseManifestEvidencePayload"
          , "renderTrustBaseManifestEvidencePayloadsJson"
          , "renderTrustBaseManifestEvidenceStatus"
          , "renderTrustBaseManifestJson"
          , "renderSchemaCatalogEvidencePayload"
          , "renderSchemaCatalogEvidencePayloadsJson"
          , "renderSchemaCatalogEvidenceStatus"
          , "schemaCatalogEvidence"
          , "schemaCatalogEvidencePayloadPassed"
          , "trustBaseManifestEvidenceArtifactSummary"
          , "trustBaseManifestEvidenceClaimNames"
          , "trustBaseManifestEvidencePayloadPassed"
          , "trustBaseManifestRequiredCoreSurfaceModules"
          , "trustBaseManifestRequiredGatePolicies"
          , "trustBaseManifestRequiredJsonSchemas"
          ]
    )

fixedPointFacade :: CoreSurfaceModule
fixedPointFacade =
  moduleSurface
    "Framework.FixedPoint"
    "fixed-point report, diff evidence, and runtime backend parity payload model"
    ( map typeCapability
        [ "EvidenceDiff"
        , "FixedPointReport"
        , "FixedPointDiffEvidencePayload"
        , "FixedPointDiffEvidenceStatus"
        , "FixedPointStatus"
        , "RuntimeBackendParityEvidencePayload"
        , "RuntimeBackendParityEvidenceStatus"
        , "StageEvidence"
        ]
        ++ map valueCapability
          [ "buildFixedPointReport"
          , "fixedPointDiffEvidencePayloadPassed"
          , "fixedPointDiffEvidencePayloads"
          , "fixedPointPassed"
          , "renderFixedPointDiffEvidencePayload"
          , "renderFixedPointDiffEvidenceStatus"
          , "renderFixedPointReport"
          , "renderFixedPointReportJson"
          , "renderFixedPointReportSummaryJson"
          , "renderRuntimeBackendParityEvidencePayload"
          , "renderRuntimeBackendParityEvidenceStatus"
          , "runtimeBackendParityEvidenceArtifactSummary"
          , "runtimeBackendParityEvidenceClaimNames"
          , "runtimeBackendParityEvidencePayloadPassed"
          , "runtimeBackendParityEvidencePayloads"
          ]
    )

frontendEvidenceFacade :: CoreSurfaceModule
frontendEvidenceFacade =
  moduleSurface
    "Framework.Frontend.Evidence"
    "machine-readable frontend claim/module link manifest and evidence claim names"
    ( map typeCapability
        [ "FrontendClaimModuleLink"
        , "FrameworkCoreFrontendEvidencePayload"
        , "FrameworkCoreFrontendEvidenceStatus"
        ]
        ++ map valueCapability
          [ "frameworkCoreFrontendCoreClaimNames"
          , "frameworkCoreFrontendEvidence"
          , "frameworkCoreFrontendEvidenceClaimNames"
          , "frameworkCoreFrontendEvidencePayloadPassed"
          , "frontendClaimModuleLinkEvidenceClaimName"
          , "frontendClaimModuleLinks"
          , "renderFrameworkCoreFrontendEvidencePayload"
          , "renderFrameworkCoreFrontendEvidencePayloadsJson"
          , "renderFrameworkCoreFrontendEvidenceStatus"
          ]
    )

architectureConcernFacade :: CoreSurfaceModule
architectureConcernFacade =
  moduleSurface
    "Framework.Architecture.Concern"
    "architecture concern and semantic risk evidence manifest"
    ( map typeCapability
        [ "ArchitectureConcernEvidencePayload"
        , "ArchitectureConcernEvidenceStatus"
        , "ArchitectureSemanticRisk"
        ]
        ++ map valueCapability
          [ "architectureConcernClaimManifestEvidenceClaimName"
          , "architectureConcernEvidence"
          , "architectureConcernEvidencePayloadPassed"
          , "architectureConcernCoreClaimNames"
          , "architectureConcernEvidenceArtifactSummary"
          , "architectureConcernEvidenceClaimNames"
          , "architectureSemanticRiskArtifactSummary"
          , "architectureSemanticRiskItemNames"
          , "architectureSemanticRiskItems"
          , "architectureSemanticRiskReviewClaimName"
          , "renderArchitectureConcernEvidencePayload"
          , "renderArchitectureConcernEvidencePayloadsJson"
          , "renderArchitectureConcernEvidenceStatus"
          , "renderArchitectureSemanticRisk"
          ]
    )

hyloFacade :: CoreSurfaceModule
hyloFacade =
  moduleSurface
    "Framework.Hylo"
    "seed, ana, and hylo entry points for materializing apps and effects"
    ( map typeCapability
        [ "AppMaterialized"
        , "AppModel"
        , "AppSeed"
        , "AppFoldAlgebra"
        , "AppFoldAlgebraM"
        , "AppUnfoldAlgebra"
        , "AppUnfoldAlgebraM"
        , "EffectTheoryUnfoldAlgebra"
        , "EffectTheoryUnfoldAlgebraM"
        , "EffectSectionSeed"
        , "EffectTheorySeed"
        , "EffectUnitSeed"
        , "FactExprSeed"
        , "HangingCoalgebra"
        , "HangingCoalgebraM"
        , "HangingLayer"
        , "HangingSeed"
        , "ProducerStepSeed"
        , "WorkflowCoalgebra"
        , "WorkflowCoalgebraM"
        , "WorkflowLayer"
        , "WorkflowSeed"
        ]
        ++ map valueCapability
          [ "anaAppBlueprint"
          , "anaAppBlueprintWith"
          , "anaAppBlueprintWithM"
          , "anaEffectTheory"
          , "anaHangingWith"
          , "anaHangingWithM"
          , "anaWorkflowWith"
          , "anaWorkflowWithM"
          , "hyloAppBlueprint"
          , "hyloAppModel"
          , "hyloAppModelM"
          , "hyloAppWith"
          , "hyloAppWithM"
          , "hyloEffectTheory"
          , "hangingSeedCoalgebra"
          , "materializeAppModel"
          , "workflowSeedCoalgebra"
          ]
    )

backgroundAppBuild :: CoreSurfaceModule
backgroundAppBuild =
  moduleSurface
    "Framework.Background.AppBuild"
    "minimal app building, planning, and bootstrap reporting"
    ( map typeCapability
        [ "AppError"
        , "AppPlan"
        , "MinimalCoreReport"
        , "MinimalCoreStatus"
        ]
        ++ map valueCapability
          [ "app"
          , "buildApp"
          , "buildMinimalCoreReport"
          , "checkMinimalCore"
          , "checkMinimalCoreModel"
          , "minimalCorePassed"
          , "minimalCoreStatus"
          , "renderAppError"
          , "renderMinimalCoreReport"
          ]
    )

backgroundBootstrapBoundary :: CoreSurfaceModule
backgroundBootstrapBoundary =
  moduleSurface
    "Framework.Background.BootstrapBoundary"
    "core slice declarations and phase boundary validation"
    ( map typeCapability
        [ "BootstrapPhase"
        , "CoreBoundary"
        , "CoreBoundaryError"
        , "CoreSlice"
        , "CoreSliceName"
        , "CoreSliceRole"
        ]
        ++ map valueCapability
          [ "checkCoreBoundary"
          , "checkCoreBoundaryWithImportGraph"
          , "coreBoundaryPassed"
          , "coreSlicesForPhase"
          , "defaultCoreBoundary"
          , "renderBootstrapPhase"
          , "renderCoreBoundary"
          , "renderCoreBoundaryError"
          , "renderCoreSlice"
          , "renderCoreSliceName"
          , "renderCoreSliceRole"
          ]
    )

backgroundFrontendBoundary :: CoreSurfaceModule
backgroundFrontendBoundary =
  moduleSurface
    "Framework.Background.FrontendBoundary"
    "package import graph and frontend boundary policy validation"
    ( map typeCapability
        [ "ConstraintError"
        , "ConstraintFact"
        , "FrontendBoundaryError"
        , "FrontendBoundaryPolicy"
        , "FrontendBoundaryRules"
        , "FrontendImport"
        , "ImportGraph"
        , "ImportModule"
        , "ImportPackage"
        , "ModuleImport"
        , "ModulePattern"
        , "PackageImportError"
        , "PackageImportPolicy"
        , "RuleId"
        , "WorkflowScope"
        ]
        ++ map valueCapability
          [ "checkConstraintFacts"
          , "checkDefaultPackageImportGraph"
          , "checkFrontendBoundary"
          , "checkFrontendBoundaryWith"
          , "checkFrontendImports"
          , "checkFrontendImportsWithRules"
          , "checkPackageImportGraph"
          , "constraintsFromAppPlan"
          , "defaultFrontendBoundaryPolicy"
          , "defaultFrontendBoundaryRules"
          , "defaultPackageImportPolicy"
          , "extractFrontendImports"
          , "extractImportGraph"
          , "frontendBoundaryPolicyRules"
          , "matchesModulePattern"
          , "readPackageImportGraph"
          , "renderConstraintError"
          , "renderConstraintFacts"
          , "renderFrontendBoundaryError"
          , "renderFrontendImport"
          , "renderModuleImport"
          , "renderPackageImportError"
          ]
    )

backgroundLanguage :: CoreSurfaceModule
backgroundLanguage =
  moduleSurface
    "Framework.Background.Language"
    "frontend language keyword, syntax, and validation contracts"
    ( map typeCapability
        [ "ArgumentCardinality"
        , "ArgumentSpec"
        , "KeywordName"
        , "KeywordSpec"
        , "LanguageConstraintError"
        , "LanguageConstraintFact"
        , "LanguageError"
        , "LanguageSpec"
        , "LoweringTarget"
        , "SyntaxKind"
        ]
        ++ map valueCapability
          [ "checkDefaultLanguageConstraints"
          , "checkDefaultLanguageSpec"
          , "checkLanguageConstraints"
          , "checkLanguageSpec"
          , "defaultLanguageConstraints"
          , "defaultLanguageSpec"
          , "keyword"
          , "keywordNameText"
          , "languageConstraintsFromSpec"
          , "languageSpecValid"
          , "many"
          , "optional"
          , "renderLanguageConstraintError"
          , "renderLanguageConstraintFact"
          , "renderLanguageConstraintFacts"
          , "renderLanguageError"
          , "required"
          ]
    )

backgroundElaboration :: CoreSurfaceModule
backgroundElaboration =
  moduleSurface
    "Framework.Background.Elaboration"
    "language-to-core elaboration contracts and binding validation"
    ( map typeCapability
        [ "ElaborationConstraintFact"
        , "ElaborationContract"
        , "ElaborationError"
        , "ElaboratorBinding"
        , "ElaboratorImplementation"
        ]
        ++ map valueCapability
          [ "checkDefaultElaborationContract"
          , "checkElaborationContract"
          , "defaultElaborationConstraints"
          , "defaultElaborationContract"
          , "elaborationConstraintsFromSpec"
          , "elaborationContractValid"
          , "elaborator"
          , "renderElaborationConstraintFact"
          , "renderElaborationConstraintFacts"
          , "renderElaborationError"
          ]
    )

backgroundConstraintProof :: CoreSurfaceModule
backgroundConstraintProof =
  moduleSurface
    "Framework.Background.ConstraintProof"
    "constraint IR, SMT propositions, solver adapters, and proof rendering"
    ( map typeCapability
        [ "SmtBackend"
        , "SmtEvidence"
        , "SmtProposition"
        , "SmtResult"
        , "SmtSolver"
        , "SmtStatus"
        ]
        ++ map valueCapability
          [ "availableSmtSolver"
          , "cvc5Solver"
          , "defaultSmtPropositions"
          , "proveMinimalCore"
          , "proveMinimalCoreWith"
          , "proveMinimalCoreWithAvailableSolver"
          , "proveMinimalCoreWithSolver"
          , "renderSmtEvidence"
          , "renderSmtResult"
          , "renderSmtResults"
          , "renderSmtSolver"
          , "smtLibForProposition"
          , "smtPassed"
          , "z3Solver"
          ]
    )

backgroundEffectSemantics :: CoreSurfaceModule
backgroundEffectSemantics =
  moduleSurface
    "Framework.Background.EffectSemantics"
    "effect contracts, boundary extraction, and take/make semantics"
    ( map typeCapability
        [ "BoundarySource"
        , "EffectBoundary"
        , "EffectSemantics"
        , "FactContract"
        , "FactSource"
        , "IdempotencyPolicy"
        , "PipeTake"
        , "ProducerRequirement"
        , "RetryPolicy"
        , "SendContract"
        , "SendUse"
        , "TakeMakeRule"
        , "TakeMakeSource"
        , "TransformContract"
        , "TransformUse"
        ]
        ++ map valueCapability
          [ "effectSemantics"
          , "effectBoundariesForFact"
          , "factContractFor"
          , "sendContractFor"
          , "takeMakeRuleFor"
          , "takeMakeRulesFor"
          , "transformContractFor"
          ]
    )

backgroundWorkflowEff :: CoreSurfaceModule
backgroundWorkflowEff =
  moduleSurface
    "Framework.Background.WorkflowEff"
    "workflow free-effect compilation and interpretation"
    ( map typeCapability
        [ "WorkflowEff"
        , "WorkflowEffAlgebra"
        , "WorkflowOp"
        ]
        ++ map valueCapability
          [ "appendWorkflowEff"
          , "compileHangingEff"
          , "compileWorkflowEff"
          , "interpretHangingEff"
          , "interpretWorkflowEff"
          ]
    )

backgroundWorkflowRender :: CoreSurfaceModule
backgroundWorkflowRender =
  moduleSurface
    "Framework.Background.WorkflowRender"
    "workflow and blueprint tree rendering through the public background facade"
    ( map valueCapability
        [ "printBlueprintProgram"
        , "renderBlueprintProgram"
        , "renderHangingProgram"
        , "renderWorkflowProgram"
        ]
    )

backgroundRuntime :: CoreSurfaceModule
backgroundRuntime =
  moduleSurface
    "Framework.Background.Runtime"
    "runtime environments, handlers, transforms, values, and app execution"
    ( map typeCapability
        [ "HangingProgram"
        , "HangingProgramAction"
        , "HandlerBinding"
        , "HandlerInput"
        , "HandlerRegistry"
        , "HandlerResult"
        , "ErrorInputValue"
        , "NoInputValue"
        , "RuntimeHandler"
        , "RuntimeCallback"
        , "RuntimeCallbackEvent"
        , "RuntimeComponentEvent"
        , "RuntimeComponentStatus"
        , "RuntimeEnv"
        , "RuntimeError"
        , "RuntimeEffectEnvironment"
        , "RuntimeFactClaim"
        , "RuntimeFactFailure"
        , "RuntimeFactStatus"
        , "RuntimeM"
        , "RuntimeMiddlewareEvent"
        , "RuntimeResult"
        , "RuntimeState"
        , "RuntimeSuspenseEvent"
        , "RuntimeTransform"
        , "RuntimeTypedValue"
        , "RuntimeValue"
        , "SomeRuntimeValue"
        , "TransformBinding"
        , "TransformRegistry"
        , "UnitValue"
        , "ValueTag"
        , "WorkflowProgram"
        , "Runtime"
        ]
        ++ map valueCapability
          [ "applyRuntimeTransform"
          , "askRuntimeEnv"
          , "contextware"
          , "contextwareWithEffectEnvironment"
          , "defaultHandlerRegistry"
          , "defaultRuntimeEffectEnvironment"
          , "defaultRuntimeEnv"
          , "defaultTransformRegistry"
          , "emptyHandlerRegistry"
          , "emptyRuntime"
          , "emptyTransformRegistry"
          , "getRuntimeState"
          , "handlerFor"
          , "handlerInputFromTypedValues"
          , "handlerInputFromValues"
          , "interpretHangingProgram"
          , "interpretWorkflowProgram"
          , "liftRuntimeIO"
          , "lowerHanging"
          , "lowerWorkflow"
          , "modifyRuntimeState"
          , "putRuntimeState"
          , "renderRuntimeError"
          , "runApp"
          , "runAppWith"
          , "runBlueprint"
          , "runBlueprintWith"
          , "runBlueprintWithAlgebra"
          , "runBlueprintWithEffectEnvironment"
          , "runBlueprintWithEffectEnvironmentResult"
          , "runBlueprintWithEffects"
          , "runHandler"
          , "runHanging"
          , "runRuntimeM"
          , "runRuntimeMOrThrow"
          , "runtimeAlgebra"
          , "runtimeEffectEnvironment"
          , "runtimeEffectEnvironmentWithTransforms"
          , "runtimeEnv"
          , "runtimeTransformInput"
          , "runtimeTransformOutput"
          , "runtimeTypedValueText"
          , "runtimeTypedValueToRuntimeValue"
          , "runtimeTypedValueType"
          , "runtimeValueToSome"
          , "sameValueTag"
          , "someRuntimeValueText"
          , "someRuntimeValueToRuntimeValue"
          , "someRuntimeValueType"
          , "throwRuntimeError"
          , "traceRuntimeM"
          , "transformFor"
          , "typedValueFor"
          , "typedValueFromSome"
          , "valueTagTypeName"
          , "withRuntimeCallbacks"
          , "withRuntimeEnv"
          , "withRuntimeMiddleware"
        ]
    )

backgroundRuntimeDiagnosis :: CoreSurfaceModule
backgroundRuntimeDiagnosis =
  moduleSurface
    "Framework.Background.RuntimeDiagnosis"
    "background compatibility facade for runtime diagnosis"
    ( map typeCapability
        [ "RuntimeFailureDiagnosis"
        , "RuntimeDiagnosisEvidencePayload"
        , "RuntimeDiagnosisEvidenceStatus"
        , "RuntimeDiagnosisNode"
        , "RuntimeDiagnosisNodeKind"
        , "RuntimeDiagnosisProbe"
        , "RuntimeDiagnosisProbeStatus"
        , "RuntimeDiagnosisRootCause"
        , "RuntimeDiagnosisStep"
        , "RuntimeDiagnosisBlocker"
        ]
        ++ map valueCapability
        [ "buildFailureDiagnosis"
        , "buildFailureDiagnosisWithSystem"
        , "completeDiagnosisProbe"
        , "diagnosisProbePairs"
        , "recordRuntimeDiagnosis"
        , "runtimeDiagnosisRootCause"
        , "runtimeDiagnosisStep"
        , "renderRuntimeDiagnosisEvidencePayload"
        , "renderRuntimeDiagnosisEvidencePayloadsJson"
        , "renderRuntimeDiagnosisEvidenceStatus"
        , "runtimeDiagnosisEvidenceArtifactSummary"
        , "runtimeDiagnosisEvidenceClaimNames"
        , "runtimeDiagnosisEvidencePayloadPassed"
        , "renderRuntimeFailureDiagnosis"
        ]
    )

runtimeInterpreterFacade :: CoreSurfaceModule
runtimeInterpreterFacade =
  moduleSurface
    "Framework.Runtime.Interpreter"
    "typed RuntimeM interpreter implementation behind the Framework.Runtime compatibility facade"
    ( map typeCapability
        [ "RuntimeEnv"
        , "RuntimeCallback"
        , "RuntimeError"
        , "RuntimeResult"
        , "RuntimeM"
        , "RuntimeState"
        ]
        ++ map valueCapability
          [ "applyRuntimeTransform"
          , "defaultRuntimeEnv"
          , "getRuntimeState"
          , "liftRuntimeIO"
          , "modifyRuntimeState"
          , "putRuntimeState"
          , "renderRuntimeError"
          , "renderRuntimeSnapshot"
          , "runBlueprintWithEffectEnvironment"
          , "runBlueprintWithEffectEnvironmentResult"
          , "runBlueprintWithEffectEnvironmentRuntimeResult"
          , "runRuntimeM"
          , "runRuntimeMOrThrow"
          , "runtimeEnv"
          , "runtimeSnapshot"
          , "throwRuntimeError"
          , "traceRuntimeM"
          , "withRuntimeCallbacks"
          , "withRuntimeEnv"
          , "withRuntimeMiddleware"
          ]
    )

runtimeValuesFacade :: CoreSurfaceModule
runtimeValuesFacade =
  moduleSurface
    "Framework.Runtime.Values"
    "typed runtime value conversion and lookup helpers"
    ( map valueCapability
        [ "runtimeTypedValueToRuntimeValue"
        , "runtimeValueToSome"
        , "sameValueTag"
        , "someRuntimeValueToRuntimeValue"
        , "typedValueFor"
        , "typedValueFromSome"
        ]
    )

runtimeHandlersFacade :: CoreSurfaceModule
runtimeHandlersFacade =
  moduleSurface
    "Framework.Runtime.Handlers"
    "typed runtime handler and transform registries"
    ( map typeCapability
        [ "HandlerBinding"
        , "HandlerInput"
        , "HandlerRegistry"
        , "HandlerResult"
        , "RuntimeEffectEnvironment"
        , "RuntimeHandler"
        , "RuntimeTransform"
        , "TransformBinding"
        , "TransformRegistry"
        ]
        ++ map valueCapability
          [ "emptyHandlerRegistry"
          , "emptyTransformRegistry"
          , "handlerFor"
          , "handlerInputFromTypedValues"
          , "handlerInputFromValues"
          , "runtimeEffectEnvironment"
          , "runtimeEffectEnvironmentWithTransforms"
          , "runtimeTransformInput"
          , "runtimeTransformOutput"
          , "transformFor"
          ]
    )

runtimeConcurrencyFacade :: CoreSurfaceModule
runtimeConcurrencyFacade =
  moduleSurface
    "Framework.Runtime.Concurrency"
    "runtime concurrency evidence payload model derived from workflow semantics claims"
    ( map typeCapability
        [ "RuntimeConcurrencyEvidencePayload"
        , "RuntimeConcurrencyEvidenceStatus"
        ]
        ++ map valueCapability
          [ "renderRuntimeConcurrencyEvidencePayload"
          , "renderRuntimeConcurrencyEvidencePayloadsJson"
          , "renderRuntimeConcurrencyEvidenceStatus"
          , "runtimeConcurrencyEvidenceArtifactSummary"
          , "runtimeConcurrencyEvidenceClaimNames"
          , "runtimeConcurrencyEvidencePayloadPassed"
          , "runtimeConcurrencyEvidencePayloads"
          ]
    )

runtimeDiagnosisFacade :: CoreSurfaceModule
runtimeDiagnosisFacade =
  moduleSurface
    "Framework.Runtime.Diagnosis"
    "runtime diagnosis model, probes, blockers, and rendering"
    ( map typeCapability
        [ "RuntimeFailureDiagnosis"
        , "RuntimeDiagnosisEvidencePayload"
        , "RuntimeDiagnosisEvidenceStatus"
        , "RuntimeDiagnosisNode"
        , "RuntimeDiagnosisNodeKind"
        , "RuntimeDiagnosisProbe"
        , "RuntimeDiagnosisProbeStatus"
        , "RuntimeDiagnosisRootCause"
        , "RuntimeDiagnosisStep"
        , "RuntimeDiagnosisBlocker"
        ]
        ++ map valueCapability
          [ "buildFailureDiagnosis"
          , "buildFailureDiagnosisWithSystem"
          , "completeDiagnosisProbe"
          , "diagnosisProbePairs"
          , "recordRuntimeDiagnosis"
          , "runtimeDiagnosisRootCause"
          , "runtimeDiagnosisStep"
          , "renderRuntimeDiagnosisEvidencePayload"
          , "renderRuntimeDiagnosisEvidencePayloadsJson"
          , "renderRuntimeDiagnosisEvidenceStatus"
          , "runtimeDiagnosisEvidenceArtifactSummary"
          , "runtimeDiagnosisEvidenceClaimNames"
          , "runtimeDiagnosisEvidencePayloadPassed"
          , "renderRuntimeFailureDiagnosis"
        ]
    )

runtimeEvidenceFacade :: CoreSurfaceModule
runtimeEvidenceFacade =
  moduleSurface
    "Framework.Runtime.Evidence"
    "top-level runtime evidence payload model over framework-core report facts and artifacts"
    ( map typeCapability
        [ "RuntimeEvidencePayload"
        , "RuntimeEvidenceStatus"
        ]
        ++ map valueCapability
          [ "renderRuntimeEvidencePayload"
          , "renderRuntimeEvidencePayloadsJson"
          , "renderRuntimeEvidenceStatus"
          , "runtimeEvidenceArtifactSummary"
          , "runtimeEvidenceClaimNames"
          , "runtimeEvidencePayloadPassed"
          , "runtimeEvidencePayloads"
          ]
    )

runtimeHotPathFacade :: CoreSurfaceModule
runtimeHotPathFacade =
  moduleSurface
    "Framework.Runtime.HotPath"
    "runtime hot-path evidence payload model for typed runtime import and execution guards"
    ( map typeCapability
        [ "RuntimeHotPathEvidencePayload"
        , "RuntimeHotPathEvidenceStatus"
        ]
        ++ map valueCapability
          [ "renderRuntimeHotPathEvidencePayload"
          , "renderRuntimeHotPathEvidencePayloadsJson"
          , "renderRuntimeHotPathEvidenceStatus"
          , "runtimeHotPathEvidenceArtifactSummary"
          , "runtimeHotPathEvidenceClaimNames"
          , "runtimeHotPathEvidencePayloadPassed"
          , "runtimeHotPathEvidencePayloads"
          ]
    )

runtimePolicyFacade :: CoreSurfaceModule
runtimePolicyFacade =
  moduleSurface
    "Framework.Runtime.Policy"
    "runtime policy evidence payload model for error dispatch, retry, and idempotency claims"
    ( map typeCapability
        [ "RuntimePolicyEvidencePayload"
        , "RuntimePolicyEvidenceStatus"
        ]
        ++ map valueCapability
          [ "renderRuntimePolicyEvidencePayload"
          , "renderRuntimePolicyEvidencePayloadsJson"
          , "renderRuntimePolicyEvidenceStatus"
          , "runtimePolicyEvidenceArtifactSummary"
          , "runtimePolicyEvidenceClaimNames"
          , "runtimePolicyEvidencePayloadPassed"
          , "runtimePolicyEvidencePayloads"
          ]
    )

runtimeStateFacade :: CoreSurfaceModule
runtimeStateFacade =
  moduleSurface
    "Framework.Runtime.State"
    "runtime state seed and snapshot projection helpers"
    ( map valueCapability
        [ "emptyRuntime"
        , "runtimeSnapshot"
        , "renderRuntimeSnapshot"
        ]
    )

runtimeTypesFacade :: CoreSurfaceModule
runtimeTypesFacade =
  moduleSurface
    "Framework.Runtime.Types"
    "shared typed runtime records, claims, values, and diagnosis data types"
    ( map typeCapability
        [ "Runtime"
        , "RuntimeSnapshot"
        , "RuntimeError"
        , "RuntimeFactClaim"
        , "RuntimeFactFailure"
        , "RuntimeFactStatus"
        , "RuntimeFailureDiagnosis"
        , "RuntimeDiagnosisBlocker"
        , "RuntimeDiagnosisNode"
        , "RuntimeDiagnosisNodeKind"
        , "RuntimeDiagnosisProbe"
        , "RuntimeDiagnosisProbeStatus"
        , "RuntimeDiagnosisRootCause"
        , "RuntimeDiagnosisStep"
        , "RuntimeValue"
        , "RuntimeTypedValue"
        , "SomeRuntimeValue"
        , "ValueTag"
        ]
        ++ map valueCapability
          [ "runtimeTypedValueText"
          , "runtimeTypedValueType"
          , "someRuntimeValueText"
          , "someRuntimeValueType"
          , "valueTagTypeName"
          ]
    )

registryCodegenFacade :: CoreSurfaceModule
registryCodegenFacade =
  moduleSurface
    "Framework.RegistryCodegen"
    "pure registry and codegen rendering for frontend plugin/effect registries"
    ( map typeCapability
        [ "EffectRegistryBinding"
        , "GeneratedSource"
        , "PluginRegistryBinding"
        ]
        ++ map valueCapability
          [ "diffGeneratedLines"
          , "frameworkCoreFrontendSources"
          , "generatedLinesMatch"
          , "registryCodegenEvidenceClaimNames"
          , "registryCodegenEvidenceStatus"
          , "renderRegistryCodegenEvidencePayload"
          , "renderRegistryCodegenEvidencePayloadsJson"
          , "renderEffectsTheoryModule"
          , "renderFrameworkCoreBaseAppModule"
          , "renderFrameworkCoreCurrentAppModule"
          , "renderFrameworkCoreCurrentAstModule"
          , "renderFrameworkCoreCurrentEffectsModule"
          , "renderFrameworkCoreCurrentInterpreterModule"
          , "renderPluginsModule"
          ]
    )

selfArtifactFacade :: CoreSurfaceModule
selfArtifactFacade =
  moduleSurface
    "Framework.SelfArtifact"
    "self artifact manifest materialization and isolated stage gate execution"
    ( map typeCapability
        [ "ArtifactCommand"
        , "ArtifactCommandResult"
        , "ArtifactManifest"
        , "ArtifactSource"
        ]
        ++ map valueCapability
          [ "defaultSelfArtifactManifest"
          , "materializeSelfArtifact"
          , "renderArtifactCommand"
          , "renderArtifactCommandResult"
          , "renderArtifactManifest"
          , "runArtifactCommand"
          , "runSelfArtifactGate"
          ]
    )

moduleSurface :: String -> String -> [CoreCapability] -> CoreSurfaceModule
moduleSurface name purpose capabilities =
  moduleSurfaceWithRelations name purpose capabilities Nothing Nothing Nothing []

moduleSurfaceWithRelations ::
  String ->
  String ->
  [CoreCapability] ->
  Maybe String ->
  Maybe String ->
  Maybe String ->
  [String] ->
  CoreSurfaceModule
moduleSurfaceWithRelations name purpose capabilities slice role phase dependencies =
  CoreSurfaceModule
    { surfaceModuleName = name
    , surfaceModulePurpose = purpose
    , surfaceModuleCapabilities = capabilities
    , surfaceModuleSlice = slice
    , surfaceModuleRole = role
    , surfaceModulePhase = phase
    , surfaceModuleDependsOn = dependencies
    }

typeCapability :: String -> CoreCapability
typeCapability name =
  capability TypeCapability name "type-level surface"

valueCapability :: String -> CoreCapability
valueCapability name =
  capability ValueCapability name "value-level operation"

patternCapability :: String -> CoreCapability
patternCapability name =
  capability PatternCapability name "pattern-level alias"

moduleCapability :: String -> CoreCapability
moduleCapability name =
  capability ModuleCapability name "framework-core module identity"

capability :: CoreCapabilityKind -> String -> String -> CoreCapability
capability kind name purpose =
  CoreCapability
    { capabilityName = name
    , capabilityKind = kind
    , capabilityPurpose = purpose
    }

mergeSurfaceModules :: [CoreSurfaceModule] -> [CoreSurfaceModule]
mergeSurfaceModules =
  foldl mergeOneSurfaceModule []

mergeOneSurfaceModule :: [CoreSurfaceModule] -> CoreSurfaceModule -> [CoreSurfaceModule]
mergeOneSurfaceModule [] currentModule =
  [currentModule]
mergeOneSurfaceModule (existingModule : rest) currentModule
  | surfaceModuleName existingModule == surfaceModuleName currentModule =
      mergeSurfaceModule existingModule currentModule : rest
  | otherwise =
      existingModule : mergeOneSurfaceModule rest currentModule

mergeSurfaceModule :: CoreSurfaceModule -> CoreSurfaceModule -> CoreSurfaceModule
mergeSurfaceModule existingModule currentModule =
  existingModule
    { surfaceModulePurpose =
        mergeText (surfaceModulePurpose existingModule) (surfaceModulePurpose currentModule)
    , surfaceModuleCapabilities =
        uniqueCapabilities (surfaceModuleCapabilities existingModule ++ surfaceModuleCapabilities currentModule)
    , surfaceModuleSlice =
        firstJust (surfaceModuleSlice existingModule) (surfaceModuleSlice currentModule)
    , surfaceModuleRole =
        firstJust (surfaceModuleRole existingModule) (surfaceModuleRole currentModule)
    , surfaceModulePhase =
        firstJust (surfaceModulePhase existingModule) (surfaceModulePhase currentModule)
    , surfaceModuleDependsOn =
        uniqueStrings (surfaceModuleDependsOn existingModule ++ surfaceModuleDependsOn currentModule)
    }

mergeText :: String -> String -> String
mergeText left right
  | left == right =
      left
  | otherwise =
      left ++ "; " ++ right

firstJust :: Maybe item -> Maybe item -> Maybe item
firstJust left right =
  case left of
    Just _ ->
      left
    Nothing ->
      right

uniqueCapabilities :: [CoreCapability] -> [CoreCapability]
uniqueCapabilities =
  foldl appendUniqueCapability []

appendUniqueCapability :: [CoreCapability] -> CoreCapability -> [CoreCapability]
appendUniqueCapability items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

uniqueStrings :: [String] -> [String]
uniqueStrings =
  foldl appendUniqueString []

appendUniqueString :: [String] -> String -> [String]
appendUniqueString items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]
