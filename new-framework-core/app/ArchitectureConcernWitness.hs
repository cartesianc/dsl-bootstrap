module Main
  ( main
  ) where

import Data.List
  ( isInfixOf )
import System.Environment
  ( getArgs )

import Framework.FixedPoint
  ( runtimeBackendParityEvidenceClaimNames )
import Framework.Runtime.Diagnosis
  ( runtimeDiagnosisEvidenceClaimNames )
import Framework.TrustBase.Manifest
  ( TrustBaseGatePolicy (..)
  , TrustBaseManifest (..)
  , defaultTrustBaseManifest
  , trustBaseManifestRequiredGatePolicies
  , trustBaseManifestRequiredJsonSchemas
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
  cabalText <- readFile "new-framework-core/new-framework-core.cabal"
  frontendWitnessSource <- readFile "new-framework-core/app/FrameworkCoreFrontendWitness.hs"
  businessWitnessSource <- readFile "domain-app/app/BusinessSyntaxWitness.hs"
  workflowWitnessSource <- readFile "new-framework-core/app/WorkflowSemanticsWitness.hs"
  runtimeDiagnosisSource <- readFile "new-framework-core/src/Framework/Runtime/Diagnosis.hs"
  runtimeHotPathSource <- readFile "new-framework-core/src/Framework/Runtime/HotPath.hs"
  domainBusinessSource <- readFile "domain-app/src/Domain/Business.hs"
  effectVocabularySource <- readFile "domain-app/src/Domain/EffectVocabulary.hs"
  pure
    [ runtimeDiagnosisPayloadIrPayload
    , runtimeDiagnosisImplementationPayload runtimeDiagnosisSource frontendWitnessSource
    , astCoreCabalClaimLinkPayload cabalText frontendWitnessSource
    , backendParityPayload
    , effectSystemScopePayload workflowWitnessSource
    , capabilityPrivateFactPayload businessWitnessSource
    , businessFacadeBoundaryPayload domainBusinessSource effectVocabularySource
    , trustBaseMachineReadableGatesPayload cabalText
    , runtimeHotPathGuardPayload runtimeHotPathSource
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

runtimeDiagnosisImplementationPayload :: String -> String -> ArchitectureConcernEvidencePayload
runtimeDiagnosisImplementationPayload diagnosisSource frontendWitnessSource =
  concernEvidence
    "session1-runtime-diagnosis-implementation-boundary"
    (null missing)
    "Framework.Runtime.Diagnosis owns diagnosis implementation and frontend witness checks that boundary"
    (observedList missing)
    "RuntimeDiagnosisImplementationCoverageArtifact"
    "medium:module-boundary"
    "move runtime diagnosis code only inside Framework.Runtime.Diagnosis or a child module with frontend witness coverage"
  where
    required =
      [ ("buildFailureDiagnosisWithSystem", "buildFailureDiagnosisWithSystem ::" `isInfixOf` diagnosisSource)
      , ("diagnosisNodesFrom", "diagnosisNodesFrom ::" `isInfixOf` diagnosisSource)
      , ("runtimeDiagnosisRootCause", "runtimeDiagnosisRootCause ::" `isInfixOf` diagnosisSource)
      , ("runtime diagnosis implementation boundary witness", "framework-core-frontend-runtime-diagnosis-implementation-boundary" `isInfixOf` frontendWitnessSource)
      ]
    missing =
      [ name | (name, present) <- required, not present ]

astCoreCabalClaimLinkPayload :: String -> String -> ArchitectureConcernEvidencePayload
astCoreCabalClaimLinkPayload cabalText frontendWitnessSource =
  concernEvidence
    "session1-ast-core-cabal-claim-link"
    (null missing)
    "AST claim -> CoreSurface module -> cabal exposed-module links are checked by frontend witness"
    (observedList missing)
    "AstCoreCabalClaimLinkCoverageArtifact"
    "low:surface-sync"
    "add new AST claim links through frontend witness and cabal exposed-module checks"
  where
    required =
      [ ("RuntimeDiagnosisExpressedFact link", "ClaimModuleLink RuntimeDiagnosisExpressedFact \"Framework.Runtime.Diagnosis\"" `isInfixOf` frontendWitnessSource)
      , ("RuntimeConcurrencySemanticsExpressedFact link", "ClaimModuleLink RuntimeConcurrencySemanticsExpressedFact \"Framework.Runtime.Concurrency\"" `isInfixOf` frontendWitnessSource)
      , ("RuntimeBackendParityExpressedFact link", "ClaimModuleLink RuntimeBackendParityExpressedFact \"Framework.FixedPoint\"" `isInfixOf` frontendWitnessSource)
      , ("Framework.Runtime.Diagnosis exposed", "Framework.Runtime.Diagnosis" `isInfixOf` cabalText)
      , ("Framework.Runtime.Concurrency exposed", "Framework.Runtime.Concurrency" `isInfixOf` cabalText)
      , ("Framework.FixedPoint exposed", "Framework.FixedPoint" `isInfixOf` cabalText)
      ]
    missing =
      [ name | (name, present) <- required, not present ]

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

effectSystemScopePayload :: String -> ArchitectureConcernEvidencePayload
effectSystemScopePayload workflowWitnessSource =
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
      [ claim | claim <- requiredClaims, not (claim `isInfixOf` workflowWitnessSource) ]

capabilityPrivateFactPayload :: String -> ArchitectureConcernEvidencePayload
capabilityPrivateFactPayload businessWitnessSource =
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
      [ ("privateFact import", "privateFact" `isInfixOf` businessWitnessSource)
      , ("privateFact boundary payload", "business-syntax-capability-private-fact-boundary" `isInfixOf` businessWitnessSource)
      , ("business-syntax schema", schemaPresent "business-syntax-evidence.v1")
      ]
    missing =
      [ name | (name, present) <- required, not present ]

businessFacadeBoundaryPayload :: String -> String -> ArchitectureConcernEvidencePayload
businessFacadeBoundaryPayload domainBusinessSource effectVocabularySource =
  concernEvidence
    "session3-business-facade-boundary"
    (null missing)
    "domain business authoring imports Framework.Business without direct Framework.Effect, Framework.Runtime, or Bootstrap dependency"
    (observedList missing)
    "BusinessFacadeBoundaryCoverageArtifact"
    "medium:public-facade"
    "prefer Framework.Business re-exports or wrappers before exposing internal Effect or Runtime modules to domain authoring"
  where
    required =
      [ ("Domain.Business imports Framework.Business", "import Framework.Business" `isInfixOf` domainBusinessSource)
      , ("Domain.Business avoids Framework.Effect", not ("import Framework.Effect" `isInfixOf` domainBusinessSource))
      , ("Domain.EffectVocabulary imports Framework.Business", "import Framework.Business" `isInfixOf` effectVocabularySource)
      , ("Domain.EffectVocabulary avoids Framework.Effect", not ("import Framework.Effect" `isInfixOf` effectVocabularySource))
      , ("Domain.EffectVocabulary avoids Framework.Runtime", not ("import Framework.Runtime" `isInfixOf` effectVocabularySource))
      , ("Domain.EffectVocabulary avoids Bootstrap", not ("import Bootstrap." `isInfixOf` effectVocabularySource))
      ]
    missing =
      [ name | (name, present) <- required, not present ]

trustBaseMachineReadableGatesPayload :: String -> ArchitectureConcernEvidencePayload
trustBaseMachineReadableGatesPayload cabalText =
  concernEvidence
    "session3-trustbase-machine-readable-gates"
    (null missing)
    "TrustBase manifest records machine-readable schemas, check facades, and architecture concern witness executable"
    (observedList missing)
    "TrustBaseMachineReadableGateCoverageArtifact"
    "low:manifest"
    "sync TrustBase manifest, check scripts, and schema catalog when adding new evidence outputs"
  where
    required =
      [ ("architecture-concern-witness cabal executable", "executable architecture-concern-witness" `isInfixOf` cabalText)
      , ("architecture-concern-witness manifest executable", "architecture-concern-witness" `elem` trustBaseManifestWitnessExecutables defaultTrustBaseManifest)
      , ("architecture-concern-evidence schema", schemaPresent "architecture-concern-evidence.v1")
      , ("check-fast gate policy", gatePolicyPresent "check-fast")
      , ("check-semantic gate policy", gatePolicyPresent "check-semantic")
      , ("check-release gate policy", gatePolicyPresent "check-release")
      , ("self-artifact high-risk gate policy", highRiskGatePolicyPresent "check-release-with-self-artifact")
      ]
    missing =
      [ name | (name, present) <- required, not present ]

runtimeHotPathGuardPayload :: String -> ArchitectureConcernEvidencePayload
runtimeHotPathGuardPayload runtimeHotPathSource =
  concernEvidence
    "session3-runtime-hot-path-guard"
    (null missing)
    "runtime hot path has import and behavior guard payloads, with JSON schema in TrustBase catalog"
    (observedList missing)
    "RuntimeHotPathGuardCoverageArtifact"
    "medium:runtime-hot-path"
    "review before adding report, witness, TrustBase, registry, or artifact gate dependencies to typed runtime hot path"
  where
    required =
      [ ("runtime-hot-path-evidence schema", schemaPresent "runtime-hot-path-evidence.v1")
      , ("hot-path import boundary payload", "runtime-hot-path-import-boundary" `isInfixOf` runtimeHotPathSource)
      , ("hot-path behavior payload", "runtime-hot-path-executes-minimal-workflow" `isInfixOf` runtimeHotPathSource)
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
    "session123-semantic-risk-review"
    True
    "architecture-changing follow-up tasks are explicitly classified before implementation"
    ( "semantic review required for EffectSystem boundary semantics, capability lowering semantics, "
        ++ "runtime diagnosis root-cause propagation, runtime policy algebra, and typed runtime hot-path dependencies"
    )
    "ArchitectureSemanticRiskReviewArtifact"
    "high:semantic-review-required"
    "pause for review before editing any listed semantic boundary; evidence/schema-only changes can proceed as low-risk work"

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
