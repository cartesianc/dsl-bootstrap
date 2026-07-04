module Framework.Architecture.Concern
  ( ArchitectureSemanticRisk (..)
  , architectureConcernClaimManifestEvidenceClaimName
  , architectureConcernCoreClaimNames
  , architectureConcernEvidenceArtifactSummary
  , architectureConcernEvidenceClaimNames
  , architectureSemanticRiskArtifactSummary
  , architectureSemanticRiskItemNames
  , architectureSemanticRiskItems
  , architectureSemanticRiskReviewClaimName
  , renderArchitectureSemanticRisk
  ) where

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

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
