module Main
  ( main
  ) where

import Data.List
  ( isInfixOf )
import System.Environment
  ( getArgs )

import Bootstrap.CoreSurface
  ( CoreCapability (..)
  , CoreCapabilityKind (..)
  , CoreSurfaceModule (..)
  , coreSurfaceModules
  )
import Framework.Architecture.Concern
  ( ArchitectureConcernEvidencePayload (..)
  , architectureConcernClaimManifestEvidenceClaimName
  , architectureConcernCoreClaimNames
  , architectureConcernEvidence
  , architectureConcernEvidenceClaimNames
  , architectureConcernEvidencePayloadPassed
  , architectureSemanticRiskItemNames
  , architectureSemanticRiskItems
  , architectureSemanticRiskReviewClaimName
  , renderArchitectureConcernEvidencePayload
  , renderArchitectureConcernEvidencePayloadsJson
  , renderArchitectureSemanticRisk
  )
import Framework.Business.Evidence
  ( businessSyntaxClaimManifestEvidenceClaimName
  , businessSyntaxCoreClaimNames
  , businessSyntaxEvidenceClaimNames
  )
import Framework.Background.ConstraintProof
  ( constraintProofCoreClaimNames
  , constraintProofEvidenceClaimNames
  )
import Framework.FixedPoint
  ( fixedPointDiffCoreClaimNames
  , fixedPointDiffEvidenceClaimNames
  , runtimeBackendParityCoreClaimNames
  , runtimeBackendParityEvidenceClaimNames
  )
import Framework.Frontend.Evidence
  ( FrontendClaimModuleLink (..)
  , frameworkCoreFrontendEvidenceClaimNames
  , frontendClaimModuleLinks
  )
import Framework.RegistryCodegen
  ( registryCodegenCoreClaimNames
  , registryCodegenEvidenceClaimNames
  )
import Framework.Runtime.Concurrency
  ( runtimeConcurrencyCoreClaimNames
  , runtimeConcurrencyEvidenceClaimNames
  )
import Framework.Runtime.Diagnosis
  ( runtimeDiagnosisCoreClaimNames
  , runtimeDiagnosisEvidenceClaimNames
  )
import Framework.Runtime.HotPath
  ( runtimeHotPathCoreClaimNames
  , runtimeHotPathEvidenceClaimNames
  )
import Framework.Runtime.Evidence
  ( runtimeEvidenceCoreClaimNames
  , runtimeEvidenceClaimNames
  )
import Framework.Runtime.Policy
  ( runtimePolicyCoreClaimNames
  , runtimePolicyEvidenceClaimNames
  )
import Framework.TrustBase.Manifest
  ( TrustBaseGatePolicy (..)
  , TrustBaseManifest (..)
  , defaultTrustBaseManifest
  , schemaCatalogCoreClaimNames
  , schemaCatalogEvidenceClaimNames
  , trustBaseManifestEvidenceClaimNames
  , trustBaseManifestRequiredCoreSurfaceModules
  , trustBaseManifestRequiredGatePolicies
  , trustBaseManifestRequiredJsonSchemas
  )
import Framework.Workflow.Semantics
  ( workflowSemanticsCoreClaimNames
  , workflowSemanticsEvidenceClaimNames
  )

main :: IO ()
main = do
  args <- getArgs
  payloads <- architectureConcernEvidencePayloads
  let failedPayloads =
        filter (not . architectureConcernEvidencePayloadPassed) payloads
  case args of
    ["--json"] -> do
      putStrLn (renderArchitectureConcernEvidencePayloadsJson payloads)
      failWhenEvidenceFailed failedPayloads
    _ -> do
      putStrLn "[witness] architecture concern evidence payloads"
      mapM_ putStrLn (concatMap renderPayloadBlock payloads)
      putStrLn
        ( "[witness] "
            ++ statusText payloads
            ++ " architecture concern evidence "
            ++ show (length payloads)
            ++ " payload claims"
        )
      failWhenEvidenceFailed failedPayloads

architectureConcernEvidencePayloads :: IO [ArchitectureConcernEvidencePayload]
architectureConcernEvidencePayloads = do
  checkLibText <- readFile "scripts/check-lib.ps1"
  let payloads =
        corePayloads checkLibText
  pure (payloads ++ [architectureConcernClaimManifestPayload payloads])
  where
    corePayloads checkLibText =
      [ runtimeDiagnosisPayloadIrPayload
      , runtimeDiagnosisImplementationPayload
      , runtimeImplementationModuleCoveragePayload
      , astCoreCabalClaimLinkPayload
      , backendParityPayload
      , effectSystemScopePayload
      , workflowAndConcurrencyManifestPayload
      , runtimeConcurrencyEvidencePayload
      , businessSyntaxClaimManifestPayload
      , capabilityAuthoringSurfacePayload
      , capabilityPrivateFactPayload
      , businessFacadeBoundaryPayload
      , trustBaseMachineReadableGatesPayload
      , selfArtifactHighRiskGateGuardPayload checkLibText
      , runtimeHotPathGuardPayload
      , runtimePolicyEvidencePayload
      , schemaCatalogCoveragePayload
      , reportJsonRendererCoveragePayload
      , semanticRiskReviewPayload
      ]

runtimeDiagnosisPayloadIrPayload :: ArchitectureConcernEvidencePayload
runtimeDiagnosisPayloadIrPayload =
  concernEvidence
    "session1-runtime-diagnosis-payload-ir"
    passed
    "runtime diagnosis evidence has structured claim payloads and schema catalog entry"
    (observedList missing)
    "RuntimeDiagnosisEvidencePayloadCoverageArtifact"
    "low:evidence-schema"
    "keep runtime-diagnosis-evidence.v1 stable; extend payload fields only with schema review"
  where
    expectedClaims =
      [ "runtime-diagnosis-error-handler"
      , "runtime-diagnosis-retry-probe"
      , "runtime-diagnosis-non-idempotent-blocker"
      , "runtime-diagnosis-system-root-cause"
      ]
    missing =
      missingItems
        ( [ "runtime-diagnosis-evidence.v1 schema" | schemaPresent "runtime-diagnosis-evidence.v1" ]
            ++ expectedClaimsPresent expectedClaims runtimeDiagnosisCoreClaimNames
            ++ expectedClaimsPresent ["runtime-diagnosis-claim-manifest"] runtimeDiagnosisEvidenceClaimNames
        )
        ("runtime-diagnosis-evidence.v1 schema" : expectedClaims ++ ["runtime-diagnosis-claim-manifest"])
    passed =
      null missing

runtimeDiagnosisImplementationPayload :: ArchitectureConcernEvidencePayload
runtimeDiagnosisImplementationPayload =
  concernEvidence
    "session1-runtime-diagnosis-implementation-boundary"
    (null missing)
    "Framework.Runtime.Diagnosis implementation boundary is covered by frontend, system root-cause evidence, and CoreSurface capabilities"
    (observedList missing)
    "RuntimeDiagnosisImplementationCoverageArtifact"
    "medium:module-boundary"
    "move runtime diagnosis code only inside Framework.Runtime.Diagnosis or a child module with frontend witness coverage"
  where
    required =
      [ ("runtime diagnosis implementation boundary witness", "framework-core-frontend-runtime-diagnosis-implementation-boundary" `elem` frameworkCoreFrontendEvidenceClaimNames)
      , ("runtime diagnosis system root-cause claim", "runtime-diagnosis-system-root-cause" `elem` runtimeDiagnosisEvidenceClaimNames)
      , ("Framework.Runtime.Diagnosis RuntimeDiagnosisStep type", coreSurfaceTypeCapabilityPresent "Framework.Runtime.Diagnosis" "RuntimeDiagnosisStep")
      , ("Framework.Runtime.Diagnosis RuntimeDiagnosisRootCause type", coreSurfaceTypeCapabilityPresent "Framework.Runtime.Diagnosis" "RuntimeDiagnosisRootCause")
      , ("Framework.Runtime.Diagnosis RuntimeFailureDiagnosis type", coreSurfaceTypeCapabilityPresent "Framework.Runtime.Diagnosis" "RuntimeFailureDiagnosis")
      , ("Framework.Runtime.Diagnosis runtimeDiagnosisStep value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Diagnosis" "runtimeDiagnosisStep")
      , ("Framework.Runtime.Diagnosis runtimeDiagnosisRootCause value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Diagnosis" "runtimeDiagnosisRootCause")
      , ("Framework.Runtime.Diagnosis buildFailureDiagnosisWithSystem value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Diagnosis" "buildFailureDiagnosisWithSystem")
      , ("Framework.Runtime.Diagnosis renderRuntimeFailureDiagnosis value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Diagnosis" "renderRuntimeFailureDiagnosis")
      ]
    missing =
      [ name | (name, present) <- required, not present ]

runtimeImplementationModuleCoveragePayload :: ArchitectureConcernEvidencePayload
runtimeImplementationModuleCoveragePayload =
  concernEvidence
    "session1-runtime-implementation-module-coverage"
    (null missing)
    "runtime implementation split modules are indexed in CoreSurface and TrustBase manifest with representative typed value, handler, state, interpreter, and diagnosis capabilities"
    (observedList missing)
    "RuntimeImplementationModuleCoverageArtifact"
    "low:surface-sync"
    "add runtime child modules to CoreSurface and TrustBase manifest before relying on them as self-expressed architecture boundaries"
  where
    required =
      [ ("Framework.Runtime.Values runtimeValueToSome value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Values" "runtimeValueToSome")
      , ("Framework.Runtime.Values typedValueFor value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Values" "typedValueFor")
      , ("Framework.Runtime.Values sameValueTag value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Values" "sameValueTag")
      , ("Framework.Runtime.Handlers RuntimeEffectEnvironment type", coreSurfaceTypeCapabilityPresent "Framework.Runtime.Handlers" "RuntimeEffectEnvironment")
      , ("Framework.Runtime.Handlers RuntimeHandler type", coreSurfaceTypeCapabilityPresent "Framework.Runtime.Handlers" "RuntimeHandler")
      , ("Framework.Runtime.Handlers handlerFor value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Handlers" "handlerFor")
      , ("Framework.Runtime.Handlers transformFor value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Handlers" "transformFor")
      , ("Framework.Runtime.State emptyRuntime value", coreSurfaceValueCapabilityPresent "Framework.Runtime.State" "emptyRuntime")
      , ("Framework.Runtime.State runtimeSnapshot value", coreSurfaceValueCapabilityPresent "Framework.Runtime.State" "runtimeSnapshot")
      , ("Framework.Runtime.Types Runtime type", coreSurfaceTypeCapabilityPresent "Framework.Runtime.Types" "Runtime")
      , ("Framework.Runtime.Types RuntimeValue type", coreSurfaceTypeCapabilityPresent "Framework.Runtime.Types" "RuntimeValue")
      , ("Framework.Runtime.Interpreter runBlueprintWithEffectEnvironmentResult value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Interpreter" "runBlueprintWithEffectEnvironmentResult")
      , ("Framework.Runtime.Diagnosis buildFailureDiagnosisWithSystem value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Diagnosis" "buildFailureDiagnosisWithSystem")
      ]
        ++ [ ("TrustBase manifest runtime module: " ++ moduleName, moduleName `elem` trustBaseManifestFacadeModules defaultTrustBaseManifest)
           | moduleName <- runtimeImplementationTrustBaseModules
           ]
        ++ [ ("TrustBase required CoreSurface runtime module: " ++ moduleName, moduleName `elem` trustBaseManifestRequiredCoreSurfaceModules)
           | moduleName <- runtimeImplementationTrustBaseModules
           ]
    missing =
      [ name | (name, present) <- required, not present ]

runtimeImplementationTrustBaseModules :: [String]
runtimeImplementationTrustBaseModules =
  [ "Framework.Runtime.Values"
  , "Framework.Runtime.Handlers"
  , "Framework.Runtime.State"
  , "Framework.Runtime.Types"
  , "Framework.Runtime.Interpreter"
  , "Framework.Runtime.Diagnosis"
  ]

astCoreCabalClaimLinkPayload :: ArchitectureConcernEvidencePayload
astCoreCabalClaimLinkPayload =
  concernEvidence
    "session1-ast-core-cabal-claim-link"
    (null missing)
    "AST claim -> CoreSurface module -> cabal exposed-module links are covered by frontend evidence manifest"
    (observedList missing)
    "AstCoreCabalClaimLinkCoverageArtifact"
    "low:surface-sync"
    "add new AST claim links through frontend witness and cabal exposed-module checks"
  where
    required =
      [ ("RuntimeDiagnosisExpressedFact link", frontendClaimModuleLinkPresent "RuntimeDiagnosisExpressedFact" "Framework.Runtime.Diagnosis")
      , ("RuntimeConcurrencySemanticsExpressedFact link", frontendClaimModuleLinkPresent "RuntimeConcurrencySemanticsExpressedFact" "Framework.Runtime.Concurrency")
      , ("RuntimeBackendParityExpressedFact link", frontendClaimModuleLinkPresent "RuntimeBackendParityExpressedFact" "Framework.FixedPoint")
      , ("frontend core surface exposed-module witness", "framework-core-frontend-core-surface-exposed-modules" `elem` frameworkCoreFrontendEvidenceClaimNames)
      , ("frontend claim manifest", "framework-core-frontend-claim-manifest" `elem` frameworkCoreFrontendEvidenceClaimNames)
      , ("Framework.Frontend.Evidence FrameworkCoreFrontendEvidencePayload type", coreSurfaceTypeCapabilityPresent "Framework.Frontend.Evidence" "FrameworkCoreFrontendEvidencePayload")
      , ("Framework.Frontend.Evidence FrameworkCoreFrontendEvidenceStatus type", coreSurfaceTypeCapabilityPresent "Framework.Frontend.Evidence" "FrameworkCoreFrontendEvidenceStatus")
      , ("Framework.Frontend.Evidence frameworkCoreFrontendEvidence value", coreSurfaceValueCapabilityPresent "Framework.Frontend.Evidence" "frameworkCoreFrontendEvidence")
      , ("Framework.Frontend.Evidence renderFrameworkCoreFrontendEvidencePayloadsJson value", coreSurfaceValueCapabilityPresent "Framework.Frontend.Evidence" "renderFrameworkCoreFrontendEvidencePayloadsJson")
      ]
    missing =
      [ name | (name, present) <- required, not present ]

frontendClaimModuleLinkPresent :: String -> String -> Bool
frontendClaimModuleLinkPresent factName moduleName =
  any matches frontendClaimModuleLinks
  where
    matches link =
      show (frontendClaimModuleFact link) == factName
        && frontendClaimModuleName link == moduleName

backendParityPayload :: ArchitectureConcernEvidencePayload
backendParityPayload =
  concernEvidence
    "session1-runtime-backend-parity-payloads"
    (null missing)
    "backend parity is split into plan, fact closure, artifact, and report payload claims"
    (observedList missing)
    "RuntimeBackendParityCoverageArtifact"
    "low:evidence-schema"
    "extend backend parity by adding payload claims before changing fixed-point comparison semantics"
  where
    expectedClaims =
      [ "runtime-backend-parity-plan"
      , "runtime-backend-parity-fact-closure"
      , "runtime-backend-parity-artifact"
      , "runtime-backend-parity-report"
      ]
    missing =
      missingItems runtimeBackendParityCoreClaimNames expectedClaims
        ++ missingItems runtimeBackendParityEvidenceClaimNames ["runtime-backend-parity-claim-manifest"]

effectSystemScopePayload :: ArchitectureConcernEvidencePayload
effectSystemScopePayload =
  concernEvidence
    "session2-effect-system-scope-boundary"
    (null missing)
    "EffectSystemBoundary imports, private facts, exports, contracts, and pipelines have workflow semantics evidence and CoreSurface capability coverage"
    (observedList missing)
    "EffectSystemScopeCoverageArtifact"
    "high:semantic-review-required"
    "review before changing EffectSystem imports, private fact visibility, export closure, or pipeline contract semantics"
  where
    requiredClaims =
      [ "workflow-effect-system-boundary"
      , "workflow-effect-system-scope"
      , "workflow-effect-system-contracts"
      , "workflow-effect-system-pipeline"
      ]
    requiredCapabilities =
      [ ("Framework.Workflow EffectSystemBoundary type", coreSurfaceTypeCapabilityPresent "Framework.Workflow" "EffectSystemBoundary")
      , ("Framework.Workflow EffectSystemBoundaryArtifact type", coreSurfaceTypeCapabilityPresent "Framework.Workflow" "EffectSystemBoundaryArtifact")
      , ("Framework.Workflow EffectSystemBoundaryHandler type", coreSurfaceTypeCapabilityPresent "Framework.Workflow" "EffectSystemBoundaryHandler")
      , ("Framework.Workflow EffectSystemBoundaryPipeline type", coreSurfaceTypeCapabilityPresent "Framework.Workflow" "EffectSystemBoundaryPipeline")
      , ("Framework.Workflow EffectSystemBoundaryPolicy type", coreSurfaceTypeCapabilityPresent "Framework.Workflow" "EffectSystemBoundaryPolicy")
      , ("Framework.Workflow effectSystemFromBoundary value", coreSurfaceValueCapabilityPresent "Framework.Workflow" "effectSystemFromBoundary")
      , ("Framework.Workflow effectSystemRuntimeFacts value", coreSurfaceValueCapabilityPresent "Framework.Workflow" "effectSystemRuntimeFacts")
      , ("Framework.Workflow systemBoundary value", coreSurfaceValueCapabilityPresent "Framework.Workflow" "systemBoundary")
      , ("Framework.Workflow systemBoundaryWithHandlers value", coreSurfaceValueCapabilityPresent "Framework.Workflow" "systemBoundaryWithHandlers")
      , ("Framework.Workflow boundaryArtifact value", coreSurfaceValueCapabilityPresent "Framework.Workflow" "boundaryArtifact")
      , ("Framework.Workflow boundaryHandler value", coreSurfaceValueCapabilityPresent "Framework.Workflow" "boundaryHandler")
      , ("Framework.Workflow boundaryPipeline value", coreSurfaceValueCapabilityPresent "Framework.Workflow" "boundaryPipeline")
      ]
    missing =
      missingItems workflowSemanticsCoreClaimNames requiredClaims
        ++ [ name | (name, present) <- requiredCapabilities, not present ]

workflowAndConcurrencyManifestPayload :: ArchitectureConcernEvidencePayload
workflowAndConcurrencyManifestPayload =
  concernEvidence
    "session2-workflow-concurrency-claim-manifest"
    (null missing)
    "workflow semantics and runtime concurrency evidence expose stable claim manifests"
    (observedList missing)
    "WorkflowConcurrencyClaimManifestCoverageArtifact"
    "low:evidence-manifest"
    "use exported workflow and runtime concurrency claim names before adding new semantics evidence"
  where
    requiredWorkflowClaims =
      [ "workflow-parallel-concurrency"
      , "workflow-race-cancellation"
      , "workflow-effect-system-boundary"
      , "workflow-effect-system-scope"
      , "workflow-effect-system-contracts"
      , "workflow-effect-system-pipeline"
      , "workflow-semantics-claim-manifest"
      ]
    requiredConcurrencyClaims =
      [ "runtime-concurrency-parallel-branches"
      , "runtime-concurrency-parallel-merge-conflict"
      , "runtime-concurrency-race-cancellation"
      , "runtime-concurrency-race-exhausted"
      ]
    missing =
      map ("workflow: " ++) (missingItems workflowSemanticsEvidenceClaimNames requiredWorkflowClaims)
        ++ map ("runtime concurrency: " ++) (missingItems runtimeConcurrencyCoreClaimNames requiredConcurrencyClaims)
        ++ map ("runtime concurrency: " ++) (missingItems runtimeConcurrencyEvidenceClaimNames ["runtime-concurrency-claim-manifest"])

runtimeConcurrencyEvidencePayload :: ArchitectureConcernEvidencePayload
runtimeConcurrencyEvidencePayload =
  concernEvidence
    "session2-runtime-concurrency-evidence-payloads"
    (null missing)
    "runtime concurrency evidence payloads are schema-cataloged, CoreSurface-indexed, and split into parallel/race claims"
    (observedList missing)
    "RuntimeConcurrencyEvidenceCoverageArtifact"
    "low:evidence-schema"
    "keep runtime-concurrency-evidence.v1 synced before changing parallel or race semantics"
  where
    expectedClaims =
      [ "runtime-concurrency-parallel-branches"
      , "runtime-concurrency-parallel-merge-conflict"
      , "runtime-concurrency-race-cancellation"
      , "runtime-concurrency-race-exhausted"
      ]
    required =
      [ ("runtime-concurrency-evidence schema", schemaPresent "runtime-concurrency-evidence.v1")
      , ("TrustBase required CoreSurface module: Framework.Runtime.Concurrency", "Framework.Runtime.Concurrency" `elem` trustBaseManifestRequiredCoreSurfaceModules)
      , ("Framework.Runtime.Concurrency RuntimeConcurrencyEvidencePayload type", coreSurfaceTypeCapabilityPresent "Framework.Runtime.Concurrency" "RuntimeConcurrencyEvidencePayload")
      , ("Framework.Runtime.Concurrency RuntimeConcurrencyEvidenceStatus type", coreSurfaceTypeCapabilityPresent "Framework.Runtime.Concurrency" "RuntimeConcurrencyEvidenceStatus")
      , ("Framework.Runtime.Concurrency runtimeConcurrencyCoreClaimNames value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Concurrency" "runtimeConcurrencyCoreClaimNames")
      , ("Framework.Runtime.Concurrency runtimeConcurrencyEvidenceClaimNames value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Concurrency" "runtimeConcurrencyEvidenceClaimNames")
      , ("Framework.Runtime.Concurrency runtimeConcurrencyEvidencePayloads value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Concurrency" "runtimeConcurrencyEvidencePayloads")
      , ("Framework.Runtime.Concurrency runtimeConcurrencyEvidencePayloadPassed value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Concurrency" "runtimeConcurrencyEvidencePayloadPassed")
      , ("Framework.Runtime.Concurrency renderRuntimeConcurrencyEvidencePayloadsJson value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Concurrency" "renderRuntimeConcurrencyEvidencePayloadsJson")
      , ("runtime concurrency claim manifest", "runtime-concurrency-claim-manifest" `elem` runtimeConcurrencyEvidenceClaimNames)
      ]
        ++ [ ("runtime concurrency claim: " ++ claim, claim `elem` runtimeConcurrencyCoreClaimNames)
           | claim <- expectedClaims
           ]
    missing =
      [ name | (name, present) <- required, not present ]

businessSyntaxClaimManifestPayload :: ArchitectureConcernEvidencePayload
businessSyntaxClaimManifestPayload =
  concernEvidence
    "session1-business-syntax-claim-manifest"
    (null missing)
    "business syntax evidence exposes a stable core claim manifest with self-check payload"
    (observedList missing)
    "BusinessSyntaxClaimManifestCoverageArtifact"
    "low:evidence-manifest"
    "update business syntax claim manifest before adding or removing capability frontend evidence payloads"
  where
    requiredClaims =
      [ "business-syntax-needs-lowering"
      , "business-syntax-external-make-lowering"
      , "business-syntax-transform-lowering"
      , "business-syntax-runtime-pipeline-adapter"
      , "business-syntax-capability-private-fact-boundary"
      , businessSyntaxClaimManifestEvidenceClaimName
      ]
    required =
      [ ("business-syntax schema", schemaPresent "business-syntax-evidence.v1")
      , ("business syntax core claim manifest non-empty", not (null businessSyntaxCoreClaimNames))
      , ("business syntax evidence claim manifest self-check", businessSyntaxClaimManifestEvidenceClaimName `elem` businessSyntaxEvidenceClaimNames)
      ]
        ++ [ ("business syntax claim: " ++ claim, claim `elem` businessSyntaxEvidenceClaimNames)
           | claim <- requiredClaims
           ]
    missing =
      [ name | (name, present) <- required, not present ]

capabilityAuthoringSurfacePayload :: ArchitectureConcernEvidencePayload
capabilityAuthoringSurfacePayload =
  concernEvidence
    "session1-capability-authoring-surface-coverage"
    (null missing)
    "Framework.Business capability authoring surface is indexed in CoreSurface and backed by business syntax evidence"
    (observedList missing)
    "CapabilityAuthoringSurfaceCoverageArtifact"
    "low:public-facade"
    "keep capability authoring API coverage synced before changing capability lowering semantics"
  where
    requiredTypes =
      [ "Capability"
      , "CapabilityClause"
      , "CapabilityPolicy"
      , "CapabilityUse"
      , "EffectTheory"
      , "HandlerBindingSpec"
      , "Pipeline"
      , "TransformBindingSpec"
      ]
    requiredValues =
      [ "capabilitiesEffect"
      , "capability"
      , "capabilityEffectSections"
      , "capabilityEffectSystem"
      , "capabilityEffectSystemBoundary"
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
      , "requires"
      , "retryOnce"
      , "transform"
      , "transformBinding"
      , "theory"
      , "uses"
      ]
    requiredClaims =
      [ "business-syntax-needs-lowering"
      , "business-syntax-take-lowering"
      , "business-syntax-make-lowering"
      , "business-syntax-uses-lowering"
      , "business-syntax-external-make-lowering"
      , "business-syntax-transform-lowering"
      , "business-syntax-handler-binding-alignment"
      , "business-syntax-pipeline-adjacent-transform"
      , "business-syntax-runtime-pipeline-adapter"
      , "business-syntax-capability-system-boundary"
      ]
    required =
      [ ("Framework.Business type: " ++ capability, coreSurfaceTypeCapabilityPresent "Framework.Business" capability)
      | capability <- requiredTypes
      ]
        ++ [ ("Framework.Business value: " ++ capability, coreSurfaceValueCapabilityPresent "Framework.Business" capability)
           | capability <- requiredValues
           ]
        ++ [ ("business syntax evidence claim: " ++ claim, claim `elem` businessSyntaxEvidenceClaimNames)
           | claim <- requiredClaims
           ]
        ++ [ ("business-syntax schema", schemaPresent "business-syntax-evidence.v1")
           ]
    missing =
      [ name | (name, present) <- required, not present ]

capabilityPrivateFactPayload :: ArchitectureConcernEvidencePayload
capabilityPrivateFactPayload =
  concernEvidence
    "session2-capability-private-fact-authoring"
    (null missing)
    "Framework.Business exposes capability privateFact lowering to private EffectSystemBoundary facts"
    (observedList missing)
    "CapabilityPrivateFactCoverageArtifact"
    "high:authoring-semantics"
    "review before changing capability lowering or privateFact export behavior"
  where
    required =
      [ ("Framework.Business privateFact surface", coreSurfaceValueCapabilityPresent "Framework.Business" "privateFact")
      , ("privateFact boundary claim", "business-syntax-capability-private-fact-boundary" `elem` businessSyntaxCoreClaimNames)
      , ("business-syntax schema", schemaPresent "business-syntax-evidence.v1")
      ]
    missing =
      [ name | (name, present) <- required, not present ]

coreSurfaceValueCapabilityPresent :: String -> String -> Bool
coreSurfaceValueCapabilityPresent moduleName capability =
  coreSurfaceCapabilityPresent moduleName ValueCapability capability

coreSurfaceTypeCapabilityPresent :: String -> String -> Bool
coreSurfaceTypeCapabilityPresent moduleName capability =
  coreSurfaceCapabilityPresent moduleName TypeCapability capability

coreSurfaceCapabilityPresent :: String -> CoreCapabilityKind -> String -> Bool
coreSurfaceCapabilityPresent moduleName kind capability =
  any moduleMatches coreSurfaceModules
  where
    moduleMatches currentModule =
      surfaceModuleName currentModule == moduleName
        && any capabilityMatches (surfaceModuleCapabilities currentModule)
    capabilityMatches currentCapability =
      capabilityName currentCapability == capability
        && capabilityKind currentCapability == kind

businessFacadeBoundaryPayload :: ArchitectureConcernEvidencePayload
businessFacadeBoundaryPayload =
  concernEvidence
    "session3-business-facade-boundary"
    (null missing)
    "domain business authoring facade boundary is covered by business syntax evidence manifest"
    (observedList missing)
    "BusinessFacadeBoundaryCoverageArtifact"
    "medium:public-facade"
    "prefer Framework.Business re-exports or wrappers before exposing internal Effect or Runtime modules to domain authoring"
  where
    requiredClaims =
      [ "business-syntax-domain-business-boundary"
      , "business-syntax-domain-effect-vocabulary-boundary"
      , "business-syntax-effects-facade-boundary"
      , "business-syntax-domain-runtime-handler-boundary"
      ]
    required =
      ("business-syntax schema", schemaPresent "business-syntax-evidence.v1")
        : [ ("business facade boundary claim: " ++ claim, claim `elem` businessSyntaxEvidenceClaimNames)
          | claim <- requiredClaims
          ]
        ++ [ ("Framework.Handler SendName type", coreSurfaceTypeCapabilityPresent "Framework.Handler" "SendName")
           , ("Framework.Handler HandlerName type", coreSurfaceTypeCapabilityPresent "Framework.Handler" "HandlerName")
           , ("Framework.Handler TransformName type", coreSurfaceTypeCapabilityPresent "Framework.Handler" "TransformName")
           , ("Framework.Handler TypeName type", coreSurfaceTypeCapabilityPresent "Framework.Handler" "TypeName")
           ]
    missing =
      [ name | (name, present) <- required, not present ]

trustBaseMachineReadableGatesPayload :: ArchitectureConcernEvidencePayload
trustBaseMachineReadableGatesPayload =
  concernEvidence
    "session3-trustbase-machine-readable-gates"
    (null missing)
    "TrustBase manifest records machine-readable schemas, check facades, and witness executable evidence"
    (observedList missing)
    "TrustBaseMachineReadableGateCoverageArtifact"
    "low:manifest"
    "sync TrustBase manifest, check scripts, and schema catalog when adding new evidence outputs"
  where
    required =
      [ ("architecture-concern-witness manifest executable", "architecture-concern-witness" `elem` trustBaseManifestWitnessExecutables defaultTrustBaseManifest)
      , ("trust-base witness executable evidence", "trust-base-witness-executables-present" `elem` trustBaseManifestEvidenceClaimNames)
      , ("trust-base artifact docs excluded evidence", "trust-base-artifact-docs-excluded" `elem` trustBaseManifestEvidenceClaimNames)
      , ("trust-base claim manifest evidence", "trust-base-manifest-claim-manifest" `elem` trustBaseManifestEvidenceClaimNames)
      , ("architecture-concern-evidence schema", schemaPresent "architecture-concern-evidence.v1")
      , ("check-fast gate policy", gatePolicyPresent "check-fast")
      , ("check-semantic gate policy", gatePolicyPresent "check-semantic")
      , ("check-release gate policy", gatePolicyPresent "check-release")
      , ("self-artifact high-risk gate policy", highRiskGatePolicyPresent "check-release-with-self-artifact")
      , ("Framework.SelfArtifact artifactEntryExcluded value", coreSurfaceValueCapabilityPresent "Framework.SelfArtifact" "artifactEntryExcluded")
      , ("Framework.SelfArtifact artifactExcludedDirectoryNames value", coreSurfaceValueCapabilityPresent "Framework.SelfArtifact" "artifactExcludedDirectoryNames")
      , ("Framework.SelfArtifact artifactExcludedEntryNames value", coreSurfaceValueCapabilityPresent "Framework.SelfArtifact" "artifactExcludedEntryNames")
      , ("Framework.SelfArtifact artifactExcludedExtensions value", coreSurfaceValueCapabilityPresent "Framework.SelfArtifact" "artifactExcludedExtensions")
      ]
    missing =
      [ name | (name, present) <- required, not present ]

selfArtifactHighRiskGateGuardPayload :: String -> ArchitectureConcernEvidencePayload
selfArtifactHighRiskGateGuardPayload checkLibText =
  concernEvidence
    "session3-self-artifact-high-risk-gate-guard"
    (null missing)
    "self-artifact-witness is a high-risk release gate that is skipped by default and guarded by a per-HEAD marker"
    (observedList missing)
    "SelfArtifactHighRiskGateGuardArtifact"
    "low:gate-policy"
    "keep self-artifact-witness behind IncludeSelfArtifact and preserve the per-HEAD marker before changing artifact gate execution"
  where
    required =
      [ ("check-release gate is not high-risk", gatePolicyHighRiskFlag "check-release" False)
      , ("check-release-with-self-artifact gate is high-risk", gatePolicyHighRiskFlag "check-release-with-self-artifact" True)
      , ("check-release skips self-artifact by default", gatePolicyCommandPresent "check-release" "# self-artifact-witness skipped; pass -IncludeSelfArtifact to run the high-risk artifact gate once")
      , ("check-release-with-self-artifact lists high-risk marker note", gatePolicyCommandPresent "check-release-with-self-artifact" "# self-artifact-witness high-risk gate; same HEAD may run only once unless marker is reset")
      , ("check-release-with-self-artifact lists self-artifact command", gatePolicyCommandPresent "check-release-with-self-artifact" "stack --work-dir .stack-work-codex exec self-artifact-witness")
      , ("check-lib requires IncludeSelfArtifact", "IncludeSelfArtifact" `isInfixOf` checkLibText)
      , ("check-lib supports ResetSelfArtifactMarker", "ResetSelfArtifactMarker" `isInfixOf` checkLibText)
      , ("check-lib writes per-HEAD marker path", "self-artifact-witness-\" + $head + \".ran" `isInfixOf` checkLibText)
      , ("check-lib blocks repeated self-artifact run", "self-artifact-witness already ran for HEAD" `isInfixOf` checkLibText)
      , ("check-lib records marker after successful gate", "Set-Content -LiteralPath $markerPath" `isInfixOf` checkLibText)
      ]
    missing =
      [ name | (name, present) <- required, not present ]

runtimeHotPathGuardPayload :: ArchitectureConcernEvidencePayload
runtimeHotPathGuardPayload =
  concernEvidence
    "session3-runtime-hot-path-guard"
    (null missing)
    "runtime hot path exposes import and behavior guard claims through the stable claim manifest, with JSON schema in TrustBase catalog"
    (observedList missing)
    "RuntimeHotPathGuardCoverageArtifact"
    "medium:runtime-hot-path"
    "review before adding report, witness, TrustBase, registry, or artifact gate dependencies to typed runtime hot path"
  where
    required =
      [ ("runtime-hot-path-evidence schema", schemaPresent "runtime-hot-path-evidence.v1")
      , ("hot-path import boundary claim", "runtime-hot-path-import-boundary" `elem` runtimeHotPathCoreClaimNames)
      , ("hot-path behavior claim", "runtime-hot-path-executes-minimal-workflow" `elem` runtimeHotPathCoreClaimNames)
      , ("hot-path claim manifest", "runtime-hot-path-claim-manifest" `elem` runtimeHotPathEvidenceClaimNames)
      ]
    missing =
      [ name | (name, present) <- required, not present ]

runtimePolicyEvidencePayload :: ArchitectureConcernEvidencePayload
runtimePolicyEvidencePayload =
  concernEvidence
    "session3-runtime-policy-evidence-payloads"
    (null missing)
    "runtime policy evidence exposes error dispatch, retry, and idempotency payload claims through schema catalog and CoreSurface"
    (observedList missing)
    "RuntimePolicyEvidenceCoverageArtifact"
    "low:evidence-schema"
    "keep policy evidence payload coverage stable; review runtime-policy-algebra before changing policy meanings"
  where
    expectedClaims =
      [ "runtime-policy-error-dispatch"
      , "runtime-policy-retry"
      , "runtime-policy-idempotency"
      ]
    required =
      [ ("runtime-policy-evidence schema", schemaPresent "runtime-policy-evidence.v1")
      , ("Framework.Runtime.Policy RuntimePolicyEvidencePayload type", coreSurfaceTypeCapabilityPresent "Framework.Runtime.Policy" "RuntimePolicyEvidencePayload")
      , ("Framework.Runtime.Policy RuntimePolicyEvidenceStatus type", coreSurfaceTypeCapabilityPresent "Framework.Runtime.Policy" "RuntimePolicyEvidenceStatus")
      , ("Framework.Runtime.Policy runtimePolicyCoreClaimNames value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Policy" "runtimePolicyCoreClaimNames")
      , ("Framework.Runtime.Policy runtimePolicyEvidenceClaimNames value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Policy" "runtimePolicyEvidenceClaimNames")
      , ("Framework.Runtime.Policy renderRuntimePolicyEvidencePayloadsJson value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Policy" "renderRuntimePolicyEvidencePayloadsJson")
      , ("Framework.Runtime.Policy runtimePolicyEvidencePayloads value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Policy" "runtimePolicyEvidencePayloads")
      , ("runtime policy claim manifest", "runtime-policy-claim-manifest" `elem` runtimePolicyEvidenceClaimNames)
      ]
        ++ [ ("runtime policy claim: " ++ claim, claim `elem` runtimePolicyCoreClaimNames)
           | claim <- expectedClaims
           ]
    missing =
      [ name | (name, present) <- required, not present ]

schemaCatalogCoveragePayload :: ArchitectureConcernEvidencePayload
schemaCatalogCoveragePayload =
  concernEvidence
    "session123-schema-catalog-coverage"
    (null missing)
    "TrustBase schema catalog includes every currently published evidence/report schema needed by session concern coverage"
    (observedList missing)
    "SchemaCatalogCoverageArtifact"
    "low:schema-catalog"
    "add every new machine-readable output to TrustBase schema catalog and schema-catalog-witness"
  where
    requiredSchemas =
      [ "framework-core-report.v1"
      , "domain-report.v1"
      , "fixed-point-report.v1"
      , "fixed-point-summary.v1"
      , "framework-core-frontend-evidence.v1"
      , "trust-base-manifest.v2"
      , "trust-base-manifest-evidence.v1"
      , "schema-catalog-evidence.v1"
      , "constraint-proof-evidence.v1"
      , "business-syntax-evidence.v1"
      , "runtime-evidence.v1"
      , "runtime-hot-path-evidence.v1"
      , "runtime-policy-evidence.v1"
      , "runtime-diagnosis-evidence.v1"
      , "registry-codegen-evidence.v1"
      , "workflow-semantics-evidence.v1"
      , "runtime-concurrency-evidence.v1"
      , "architecture-concern-evidence.v1"
      ]
    required =
      [ ("schema catalog entry: " ++ schemaName, schemaPresent schemaName)
      | schemaName <- requiredSchemas
      ]
        ++
      [ ("Framework.TrustBase.Manifest SchemaCatalogEvidencePayload type", coreSurfaceTypeCapabilityPresent "Framework.TrustBase.Manifest" "SchemaCatalogEvidencePayload")
      , ("Framework.TrustBase.Manifest SchemaCatalogEvidenceStatus type", coreSurfaceTypeCapabilityPresent "Framework.TrustBase.Manifest" "SchemaCatalogEvidenceStatus")
      , ("Framework.TrustBase.Manifest schemaCatalogClaimManifestPayload value", coreSurfaceValueCapabilityPresent "Framework.TrustBase.Manifest" "schemaCatalogClaimManifestPayload")
      , ("Framework.TrustBase.Manifest schemaCatalogCoreClaimNames value", coreSurfaceValueCapabilityPresent "Framework.TrustBase.Manifest" "schemaCatalogCoreClaimNames")
      , ("Framework.TrustBase.Manifest schemaCatalogEvidence value", coreSurfaceValueCapabilityPresent "Framework.TrustBase.Manifest" "schemaCatalogEvidence")
      , ("Framework.TrustBase.Manifest schemaCatalogEvidenceArtifactSummary value", coreSurfaceValueCapabilityPresent "Framework.TrustBase.Manifest" "schemaCatalogEvidenceArtifactSummary")
      , ("Framework.TrustBase.Manifest schemaCatalogEvidenceClaimNames value", coreSurfaceValueCapabilityPresent "Framework.TrustBase.Manifest" "schemaCatalogEvidenceClaimNames")
      , ("Framework.TrustBase.Manifest schemaCatalogEvidencePayloadPassed value", coreSurfaceValueCapabilityPresent "Framework.TrustBase.Manifest" "schemaCatalogEvidencePayloadPassed")
      , ("Framework.TrustBase.Manifest renderSchemaCatalogEvidencePayloadsJson value", coreSurfaceValueCapabilityPresent "Framework.TrustBase.Manifest" "renderSchemaCatalogEvidencePayloadsJson")
      , ("schema catalog framework-core report claim", "schema-catalog-output:framework-core-report.v1" `elem` schemaCatalogCoreClaimNames)
      , ("schema catalog constraint proof claim", "schema-catalog-output:constraint-proof-evidence.v1" `elem` schemaCatalogCoreClaimNames)
      , ("schema catalog registry codegen claim", "schema-catalog-output:registry-codegen-evidence.v1" `elem` schemaCatalogCoreClaimNames)
      , ("schema catalog claim manifest", "schema-catalog-claim-manifest" `elem` schemaCatalogEvidenceClaimNames)
      , ("Framework.Background.ConstraintProof ConstraintProofEvidencePayload type", coreSurfaceTypeCapabilityPresent "Framework.Background.ConstraintProof" "ConstraintProofEvidencePayload")
      , ("Framework.Background.ConstraintProof ConstraintProofEvidenceStatus type", coreSurfaceTypeCapabilityPresent "Framework.Background.ConstraintProof" "ConstraintProofEvidenceStatus")
      , ("Framework.Background.ConstraintProof constraintProofCoreClaimNames value", coreSurfaceValueCapabilityPresent "Framework.Background.ConstraintProof" "constraintProofCoreClaimNames")
      , ("Framework.Background.ConstraintProof constraintProofEvidenceClaimNames value", coreSurfaceValueCapabilityPresent "Framework.Background.ConstraintProof" "constraintProofEvidenceClaimNames")
      , ("Framework.Background.ConstraintProof renderConstraintProofEvidencePayloadsJson value", coreSurfaceValueCapabilityPresent "Framework.Background.ConstraintProof" "renderConstraintProofEvidencePayloadsJson")
      , ("constraint proof IR claim", "constraint-ir-built" `elem` constraintProofCoreClaimNames)
      , ("constraint proof SMT claim", "constraint-proof-smt-results" `elem` constraintProofCoreClaimNames)
      , ("constraint proof claim manifest", "constraint-proof-claim-manifest" `elem` constraintProofEvidenceClaimNames)
      , ("Framework.Runtime.Evidence runtimeEvidenceCoreClaimNames value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Evidence" "runtimeEvidenceCoreClaimNames")
      , ("Framework.Runtime.Evidence runtimeEvidenceClaimNames value", coreSurfaceValueCapabilityPresent "Framework.Runtime.Evidence" "runtimeEvidenceClaimNames")
      , ("runtime evidence plan build claim", "runtime-plan-build-evidence" `elem` runtimeEvidenceCoreClaimNames)
      , ("runtime evidence claim manifest", "runtime-evidence-claim-manifest" `elem` runtimeEvidenceClaimNames)
      , ("Framework.RegistryCodegen registryCodegenCoreClaimNames value", coreSurfaceValueCapabilityPresent "Framework.RegistryCodegen" "registryCodegenCoreClaimNames")
      , ("Framework.RegistryCodegen registryCodegenEvidenceClaimNames value", coreSurfaceValueCapabilityPresent "Framework.RegistryCodegen" "registryCodegenEvidenceClaimNames")
      , ("Framework.RegistryCodegen registryCodegenClaimManifestPayload value", coreSurfaceValueCapabilityPresent "Framework.RegistryCodegen" "registryCodegenClaimManifestPayload")
      , ("Framework.RegistryCodegen renderRegistryCodegenEvidencePayload value", coreSurfaceValueCapabilityPresent "Framework.RegistryCodegen" "renderRegistryCodegenEvidencePayload")
      , ("Framework.RegistryCodegen renderRegistryCodegenEvidencePayloadsJson value", coreSurfaceValueCapabilityPresent "Framework.RegistryCodegen" "renderRegistryCodegenEvidencePayloadsJson")
      , ("registry codegen plugins claim", "registry-codegen-plugins" `elem` registryCodegenCoreClaimNames)
      , ("registry codegen effects claim", "registry-codegen-effects" `elem` registryCodegenCoreClaimNames)
      , ("registry codegen claim manifest", "registry-codegen-claim-manifest" `elem` registryCodegenEvidenceClaimNames)
      ]
    missing =
      [ name | (name, present) <- required, not present ]

reportJsonRendererCoveragePayload :: ArchitectureConcernEvidencePayload
reportJsonRendererCoveragePayload =
  concernEvidence
    "session123-report-json-renderer-coverage"
    (null missing)
    "framework-core, domain, and fixed-point report JSON renderers are schema-cataloged and indexed in CoreSurface"
    (observedList missing)
    "ReportJsonRendererCoverageArtifact"
    "low:report-schema"
    "keep report JSON renderer capability coverage synced with TrustBase schema catalog entries"
  where
    required =
      [ ("framework-core-report.v1 schema", schemaPresent "framework-core-report.v1")
      , ("domain-report.v1 schema", schemaPresent "domain-report.v1")
      , ("fixed-point-report.v1 schema", schemaPresent "fixed-point-report.v1")
      , ("fixed-point-summary.v1 schema", schemaPresent "fixed-point-summary.v1")
      , ("Bootstrap.Report FrameworkCoreReport type", coreSurfaceTypeCapabilityPresent "Bootstrap.Report" "FrameworkCoreReport")
      , ("Bootstrap.Report renderFrameworkCoreReportJson value", coreSurfaceValueCapabilityPresent "Bootstrap.Report" "renderFrameworkCoreReportJson")
      , ("Bootstrap.Report buildFrameworkCoreReport value", coreSurfaceValueCapabilityPresent "Bootstrap.Report" "buildFrameworkCoreReport")
      , ("Framework.Domain DomainReport type", coreSurfaceTypeCapabilityPresent "Framework.Domain" "DomainReport")
      , ("Framework.Domain renderDomainReportJson value", coreSurfaceValueCapabilityPresent "Framework.Domain" "renderDomainReportJson")
      , ("Framework.Domain buildDomainReport value", coreSurfaceValueCapabilityPresent "Framework.Domain" "buildDomainReport")
      , ("Framework.FixedPoint FixedPointReport type", coreSurfaceTypeCapabilityPresent "Framework.FixedPoint" "FixedPointReport")
      , ("Framework.FixedPoint renderFixedPointReportJson value", coreSurfaceValueCapabilityPresent "Framework.FixedPoint" "renderFixedPointReportJson")
      , ("Framework.FixedPoint renderFixedPointReportSummaryJson value", coreSurfaceValueCapabilityPresent "Framework.FixedPoint" "renderFixedPointReportSummaryJson")
      , ("Framework.FixedPoint buildFixedPointReport value", coreSurfaceValueCapabilityPresent "Framework.FixedPoint" "buildFixedPointReport")
      , ("Framework.FixedPoint fixedPointDiffCoreClaimNames value", coreSurfaceValueCapabilityPresent "Framework.FixedPoint" "fixedPointDiffCoreClaimNames")
      , ("Framework.FixedPoint fixedPointDiffEvidenceClaimNames value", coreSurfaceValueCapabilityPresent "Framework.FixedPoint" "fixedPointDiffEvidenceClaimNames")
      , ("fixed-point diff status claim", "fixed-point-diff-status" `elem` fixedPointDiffCoreClaimNames)
      , ("fixed-point diff claim manifest", "fixed-point-diff-claim-manifest" `elem` fixedPointDiffEvidenceClaimNames)
      ]
    missing =
      [ name | (name, present) <- required, not present ]

semanticRiskReviewPayload :: ArchitectureConcernEvidencePayload
semanticRiskReviewPayload =
  concernEvidence
    architectureSemanticRiskReviewClaimName
    (null missing)
    "architecture-changing follow-up tasks are explicitly classified in the semantic risk manifest"
    observed
    "ArchitectureSemanticRiskReviewArtifact"
    "high:semantic-review-required"
    "pause for review before editing any listed semantic boundary; evidence/schema-only changes can proceed as low-risk work"
  where
    requiredRiskItems =
      [ "effect-system-boundary-semantics"
      , "capability-lowering-semantics"
      , "runtime-diagnosis-root-cause-semantics"
      , "runtime-policy-algebra"
      , "typed-runtime-hot-path-dependencies"
      ]
    missing =
      missingItems architectureSemanticRiskItemNames requiredRiskItems
    observed =
      if null missing
        then "semantic risk items: " ++ joinWith "; " (map renderArchitectureSemanticRisk architectureSemanticRiskItems)
        else observedList missing

architectureConcernClaimManifestPayload :: [ArchitectureConcernEvidencePayload] -> ArchitectureConcernEvidencePayload
architectureConcernClaimManifestPayload payloads =
  concernEvidence
    architectureConcernClaimManifestEvidenceClaimName
    manifestSynced
    "architecture concern executable claims match exported claim manifest"
    observed
    "ArchitectureConcernClaimManifestArtifact"
    "low:evidence-manifest"
    "update Framework.Architecture.Concern before adding or removing architecture concern evidence payloads"
  where
    actualCoreClaimNames =
      map architectureConcernEvidenceClaim payloads
    actualEvidenceClaimNames =
      actualCoreClaimNames ++ [architectureConcernClaimManifestEvidenceClaimName]
    manifestSynced =
      actualCoreClaimNames == architectureConcernCoreClaimNames
        && actualEvidenceClaimNames == architectureConcernEvidenceClaimNames
    observed =
      if manifestSynced
        then "claim manifest synced: " ++ show (length actualCoreClaimNames) ++ " core claims"
        else "expected " ++ show architectureConcernEvidenceClaimNames ++ "; actual " ++ show actualEvidenceClaimNames

expectedClaimsPresent :: [String] -> [String] -> [String]
expectedClaimsPresent expected actual =
  [ claim | claim <- expected, claim `elem` actual ]

schemaPresent :: String -> Bool
schemaPresent schemaName =
  any (schemaCatalogEntryHas schemaName) trustBaseManifestRequiredJsonSchemas

schemaCatalogEntryHas :: String -> String -> Bool
schemaCatalogEntryHas schemaName entry =
  (schemaName ++ " <- ") `isInfixOf` entry

gatePolicyPresent :: String -> Bool
gatePolicyPresent policyName =
  any ((== policyName) . trustBaseGatePolicyName) trustBaseManifestRequiredGatePolicies

gatePolicyHighRiskFlag :: String -> Bool -> Bool
gatePolicyHighRiskFlag policyName expected =
  any matches trustBaseManifestRequiredGatePolicies
  where
    matches policy =
      trustBaseGatePolicyName policy == policyName
        && trustBaseGatePolicyHighRisk policy == expected

gatePolicyCommandPresent :: String -> String -> Bool
gatePolicyCommandPresent policyName command =
  any matches trustBaseManifestRequiredGatePolicies
  where
    matches policy =
      trustBaseGatePolicyName policy == policyName
        && command `elem` trustBaseGatePolicyCommands policy

highRiskGatePolicyPresent :: String -> Bool
highRiskGatePolicyPresent policyName =
  any matches trustBaseManifestRequiredGatePolicies
  where
    matches policy =
      trustBaseGatePolicyName policy == policyName
        && trustBaseGatePolicyHighRisk policy

missingItems :: [String] -> [String] -> [String]
missingItems actual expected =
  [ item | item <- expected, item `notElem` actual ]

concernEvidence :: String -> Bool -> String -> String -> String -> String -> String -> ArchitectureConcernEvidencePayload
concernEvidence =
  architectureConcernEvidence

observedList :: [String] -> String
observedList [] =
  "all concern coverage evidence present"
observedList missing =
  "missing: " ++ joinWith ", " missing

renderPayloadBlock :: ArchitectureConcernEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderArchitectureConcernEvidencePayload payload)
    ++ [""]

failWhenEvidenceFailed :: [ArchitectureConcernEvidencePayload] -> IO ()
failWhenEvidenceFailed [] =
  pure ()
failWhenEvidenceFailed failedPayloads =
  ioError
    ( userError
        ( "[witness] architecture concern evidence failed\n"
            ++ unlines (concatMap renderPayloadBlock failedPayloads)
        )
    )

statusText :: [ArchitectureConcernEvidencePayload] -> String
statusText payloads =
  if all architectureConcernEvidencePayloadPassed payloads
    then "ok"
    else "failed"

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
