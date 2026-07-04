module Framework.Architecture.Concern
  ( ArchitectureSemanticRisk (..)
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
