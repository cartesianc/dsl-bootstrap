module Main
  ( main
  ) where

import Data.List
  ( isInfixOf )
import System.Environment
  ( getArgs )

import Bootstrap.CoreSurface
  ( CoreCapability (..)
  , CoreSurfaceModule (..)
  , coreSurfaceModules
  )
import Framework.Architecture.Concern
  ( architectureConcernClaimManifestEvidenceClaimName
  , architectureConcernCoreClaimNames
  , architectureConcernEvidenceClaimNames
  , architectureSemanticRiskItemNames
  , architectureSemanticRiskItems
  , architectureSemanticRiskReviewClaimName
  , renderArchitectureSemanticRisk
  )
import Framework.Business.Evidence
  ( businessSyntaxClaimManifestEvidenceClaimName
  , businessSyntaxCoreClaimNames
  , businessSyntaxEvidenceClaimNames
  )
import Framework.FixedPoint
  ( runtimeBackendParityEvidenceClaimNames )
import Framework.Frontend.Evidence
  ( FrontendClaimModuleLink (..)
  , frameworkCoreFrontendEvidenceClaimNames
  , frontendClaimModuleLinks
  )
import Framework.Runtime.Concurrency
  ( runtimeConcurrencyEvidenceClaimNames )
import Framework.Runtime.Diagnosis
  ( runtimeDiagnosisEvidenceClaimNames )
import Framework.Runtime.HotPath
  ( runtimeHotPathEvidenceClaimNames )
import Framework.TrustBase.Manifest
  ( TrustBaseGatePolicy (..)
  , TrustBaseManifest (..)
  , defaultTrustBaseManifest
  , trustBaseManifestEvidenceClaimNames
  , trustBaseManifestRequiredGatePolicies
  , trustBaseManifestRequiredJsonSchemas
  )
import Framework.Workflow.Semantics
  ( workflowSemanticsCoreClaimNames
  , workflowSemanticsEvidenceClaimNames
  )

data ArchitectureConcernEvidencePayload = ArchitectureConcernEvidencePayload
  { architectureConcernEvidenceClaim :: String
  , architectureConcernEvidenceStatus :: ArchitectureConcernEvidenceStatus
  , architectureConcernEvidenceExpected :: String
  , architectureConcernEvidenceObserved :: String
  , architectureConcernEvidenceArtifact :: String
  , architectureConcernEvidenceRisk :: String
  , architectureConcernEvidenceNextAction :: String
  }
  deriving (Eq, Show)

data ArchitectureConcernEvidenceStatus
  = ArchitectureConcernEvidencePassed
  | ArchitectureConcernEvidenceFailed
  deriving (Eq, Show)

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
  pure (corePayloads ++ [architectureConcernClaimManifestPayload corePayloads])
  where
    corePayloads =
      [ runtimeDiagnosisPayloadIrPayload
      , runtimeDiagnosisImplementationPayload
      , astCoreCabalClaimLinkPayload
      , backendParityPayload
      , effectSystemScopePayload
      , workflowAndConcurrencyManifestPayload
      , businessSyntaxClaimManifestPayload
      , capabilityPrivateFactPayload
      , businessFacadeBoundaryPayload
      , trustBaseMachineReadableGatesPayload
      , runtimeHotPathGuardPayload
      , schemaCatalogCoveragePayload
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
            ++ expectedClaimsPresent expectedClaims runtimeDiagnosisEvidenceClaimNames
        )
        ("runtime-diagnosis-evidence.v1 schema" : expectedClaims)
    passed =
      null missing

runtimeDiagnosisImplementationPayload :: ArchitectureConcernEvidencePayload
runtimeDiagnosisImplementationPayload =
  concernEvidence
    "session1-runtime-diagnosis-implementation-boundary"
    (null missing)
    "Framework.Runtime.Diagnosis implementation boundary is covered by frontend and diagnosis evidence manifests"
    (observedList missing)
    "RuntimeDiagnosisImplementationCoverageArtifact"
    "medium:module-boundary"
    "move runtime diagnosis code only inside Framework.Runtime.Diagnosis or a child module with frontend witness coverage"
  where
    required =
      [ ("runtime diagnosis implementation boundary witness", "framework-core-frontend-runtime-diagnosis-implementation-boundary" `elem` frameworkCoreFrontendEvidenceClaimNames)
      , ("runtime diagnosis system root-cause claim", "runtime-diagnosis-system-root-cause" `elem` runtimeDiagnosisEvidenceClaimNames)
      ]
    missing =
      [ name | (name, present) <- required, not present ]

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
      missingItems runtimeBackendParityEvidenceClaimNames expectedClaims

effectSystemScopePayload :: ArchitectureConcernEvidencePayload
effectSystemScopePayload =
  concernEvidence
    "session2-effect-system-scope-boundary"
    (null missing)
    "EffectSystemBoundary imports, private facts, exports, contracts, and pipelines have workflow semantics evidence"
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
    missing =
      missingItems workflowSemanticsCoreClaimNames requiredClaims

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
        ++ map ("runtime concurrency: " ++) (missingItems runtimeConcurrencyEvidenceClaimNames requiredConcurrencyClaims)

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
  any moduleMatches coreSurfaceModules
  where
    moduleMatches currentModule =
      surfaceModuleName currentModule == moduleName
        && any ((== capability) . capabilityName) (surfaceModuleCapabilities currentModule)

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
      ]
    required =
      ("business-syntax schema", schemaPresent "business-syntax-evidence.v1")
        : [ ("business facade boundary claim: " ++ claim, claim `elem` businessSyntaxEvidenceClaimNames)
          | claim <- requiredClaims
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
      , ("architecture-concern-evidence schema", schemaPresent "architecture-concern-evidence.v1")
      , ("check-fast gate policy", gatePolicyPresent "check-fast")
      , ("check-semantic gate policy", gatePolicyPresent "check-semantic")
      , ("check-release gate policy", gatePolicyPresent "check-release")
      , ("self-artifact high-risk gate policy", highRiskGatePolicyPresent "check-release-with-self-artifact")
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
      , ("hot-path import boundary claim", "runtime-hot-path-import-boundary" `elem` runtimeHotPathEvidenceClaimNames)
      , ("hot-path behavior claim", "runtime-hot-path-executes-minimal-workflow" `elem` runtimeHotPathEvidenceClaimNames)
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
    missing =
      [ schemaName | schemaName <- requiredSchemas, not (schemaPresent schemaName) ]

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
concernEvidence claim passed expected observed artifact risk nextAction =
  ArchitectureConcernEvidencePayload
    { architectureConcernEvidenceClaim = claim
    , architectureConcernEvidenceStatus =
        if passed
          then ArchitectureConcernEvidencePassed
          else ArchitectureConcernEvidenceFailed
    , architectureConcernEvidenceExpected = expected
    , architectureConcernEvidenceObserved = observed
    , architectureConcernEvidenceArtifact = artifact
    , architectureConcernEvidenceRisk = risk
    , architectureConcernEvidenceNextAction = nextAction
    }

architectureConcernEvidencePayloadPassed :: ArchitectureConcernEvidencePayload -> Bool
architectureConcernEvidencePayloadPassed payload =
  architectureConcernEvidenceStatus payload == ArchitectureConcernEvidencePassed

observedList :: [String] -> String
observedList [] =
  "all concern coverage evidence present"
observedList missing =
  "missing: " ++ joinWith ", " missing

renderPayloadBlock :: ArchitectureConcernEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderArchitectureConcernEvidencePayload payload)
    ++ [""]

renderArchitectureConcernEvidencePayload :: ArchitectureConcernEvidencePayload -> [String]
renderArchitectureConcernEvidencePayload payload =
  [ "claim: " ++ architectureConcernEvidenceClaim payload
  , "status: " ++ renderArchitectureConcernEvidenceStatus (architectureConcernEvidenceStatus payload)
  , "expected: " ++ architectureConcernEvidenceExpected payload
  , "observed: " ++ architectureConcernEvidenceObserved payload
  , "artifact: " ++ architectureConcernEvidenceArtifact payload
  , "risk: " ++ architectureConcernEvidenceRisk payload
  , "nextAction: " ++ architectureConcernEvidenceNextAction payload
  ]

renderArchitectureConcernEvidenceStatus :: ArchitectureConcernEvidenceStatus -> String
renderArchitectureConcernEvidenceStatus ArchitectureConcernEvidencePassed =
  "passed"
renderArchitectureConcernEvidenceStatus ArchitectureConcernEvidenceFailed =
  "failed"

renderArchitectureConcernEvidencePayloadsJson :: [ArchitectureConcernEvidencePayload] -> String
renderArchitectureConcernEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "architecture-concern-evidence.v1")
    , jsonField "status" (jsonString status)
    , jsonField "payloads" (jsonArray (map architectureConcernEvidencePayloadJson payloads))
    ]
  where
    status =
      if all architectureConcernEvidencePayloadPassed payloads
        then "passed"
        else "failed"

architectureConcernEvidencePayloadJson :: ArchitectureConcernEvidencePayload -> String
architectureConcernEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (architectureConcernEvidenceClaim payload))
    , jsonField "status" (jsonString (renderArchitectureConcernEvidenceStatus (architectureConcernEvidenceStatus payload)))
    , jsonField "expected" (jsonString (architectureConcernEvidenceExpected payload))
    , jsonField "observed" (jsonString (architectureConcernEvidenceObserved payload))
    , jsonField "artifact" (jsonString (architectureConcernEvidenceArtifact payload))
    , jsonField "risk" (jsonString (architectureConcernEvidenceRisk payload))
    , jsonField "nextAction" (jsonString (architectureConcernEvidenceNextAction payload))
    ]

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

jsonObject :: [String] -> String
jsonObject fields =
  "{" ++ joinWith "," fields ++ "}"

jsonField :: String -> String -> String
jsonField name value =
  jsonString name ++ ":" ++ value

jsonArray :: [String] -> String
jsonArray values =
  "[" ++ joinWith "," values ++ "]"

jsonString :: String -> String
jsonString value =
  "\"" ++ concatMap jsonChar value ++ "\""

jsonChar :: Char -> String
jsonChar currentChar =
  case currentChar of
    '"' ->
      "\\\""
    '\\' ->
      "\\\\"
    '\n' ->
      "\\n"
    '\r' ->
      "\\r"
    '\t' ->
      "\\t"
    _ ->
      [currentChar]

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
