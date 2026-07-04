module Framework.Architecture.Concern
  ( ArchitectureConcernEvidencePayload (..)
  , ArchitectureConcernEvidenceStatus (..)
  , ArchitectureSemanticRisk (..)
  , architectureConcernEvidence
  , architectureConcernEvidencePayloadPassed
  , architectureConcernClaimManifestEvidenceClaimName
  , architectureConcernCoreClaimNames
  , architectureConcernEvidenceArtifactSummary
  , architectureConcernEvidenceClaimNames
  , architectureSemanticRiskArtifactSummary
  , architectureSemanticRiskItemNames
  , architectureSemanticRiskItems
  , architectureSemanticRiskReviewClaimName
  , renderArchitectureConcernEvidencePayload
  , renderArchitectureConcernEvidencePayloadsJson
  , renderArchitectureConcernEvidenceStatus
  , renderArchitectureSemanticRisk
  ) where

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

data ArchitectureSemanticRisk = ArchitectureSemanticRisk
  { architectureSemanticRiskName :: String
  , architectureSemanticRiskArea :: String
  , architectureSemanticRiskLevel :: String
  , architectureSemanticRiskReviewAction :: String
  }
  deriving (Eq, Show)

architectureConcernCoreClaimNames :: [String]
architectureConcernCoreClaimNames =
  [ "session1-runtime-diagnosis-payload-ir"
  , "session1-runtime-diagnosis-implementation-boundary"
  , "session1-runtime-implementation-module-coverage"
  , "session1-ast-core-cabal-claim-link"
  , "session1-runtime-backend-parity-payloads"
  , "session2-effect-system-scope-boundary"
  , "session2-workflow-concurrency-claim-manifest"
  , "session1-business-syntax-claim-manifest"
  , "session2-capability-private-fact-authoring"
  , "session3-business-facade-boundary"
  , "session3-trustbase-machine-readable-gates"
  , "session3-runtime-hot-path-guard"
  , "session123-schema-catalog-coverage"
  , "session123-report-json-renderer-coverage"
  , architectureSemanticRiskReviewClaimName
  ]

architectureConcernEvidenceClaimNames :: [String]
architectureConcernEvidenceClaimNames =
  architectureConcernCoreClaimNames ++ [architectureConcernClaimManifestEvidenceClaimName]

architectureConcernClaimManifestEvidenceClaimName :: String
architectureConcernClaimManifestEvidenceClaimName =
  "architecture-concern-claim-manifest"

architectureConcernEvidenceArtifactSummary :: String
architectureConcernEvidenceArtifactSummary =
  "architecture concern evidence payload claims: "
    ++ joinWith ", " architectureConcernEvidenceClaimNames

architectureConcernEvidence ::
  String ->
  Bool ->
  String ->
  String ->
  String ->
  String ->
  String ->
  ArchitectureConcernEvidencePayload
architectureConcernEvidence claim passed expected observed artifact risk nextAction =
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

architectureSemanticRiskReviewClaimName :: String
architectureSemanticRiskReviewClaimName =
  "session123-semantic-risk-review"

architectureSemanticRiskItems :: [ArchitectureSemanticRisk]
architectureSemanticRiskItems =
  [ ArchitectureSemanticRisk
      "effect-system-boundary-semantics"
      "EffectSystemBoundary imports, private facts, exports, and pipeline contract semantics"
      "high:semantic-review-required"
      "review before changing EffectSystem visibility, export closure, private fact behavior, or pipeline contract rules"
  , ArchitectureSemanticRisk
      "capability-lowering-semantics"
      "Framework.Business capability, privateFact, handler binding, transform, and lowering behavior"
      "high:semantic-review-required"
      "review before changing capability lowering, privateFact export behavior, or authoring surface compatibility"
  , ArchitectureSemanticRisk
      "runtime-diagnosis-root-cause-semantics"
      "runtime diagnosis root-cause propagation and diagnosis implementation ownership"
      "high:semantic-review-required"
      "review before changing runtime diagnosis causality, root-cause attribution, or implementation module ownership"
  , ArchitectureSemanticRisk
      "runtime-policy-algebra"
      "retry, idempotency, error dispatch, backend parity, and concurrency policy algebra"
      "high:semantic-review-required"
      "review before splitting, renaming, or changing runtime policy facts, artifacts, or witness payload meanings"
  , ArchitectureSemanticRisk
      "typed-runtime-hot-path-dependencies"
      "typed runtime hot-path dependency boundary and execution weight"
      "high:semantic-review-required"
      "review before adding report, evidence, fixed-point, TrustBase, registry, or artifact gate dependencies to runtime hot path"
  ]

architectureSemanticRiskItemNames :: [String]
architectureSemanticRiskItemNames =
  map architectureSemanticRiskName architectureSemanticRiskItems

architectureSemanticRiskArtifactSummary :: String
architectureSemanticRiskArtifactSummary =
  "architecture semantic risk manifest: "
    ++ joinWith ", " architectureSemanticRiskItemNames

renderArchitectureSemanticRisk :: ArchitectureSemanticRisk -> String
renderArchitectureSemanticRisk risk =
  architectureSemanticRiskName risk
    ++ " ["
    ++ architectureSemanticRiskLevel risk
    ++ "]: "
    ++ architectureSemanticRiskArea risk

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
