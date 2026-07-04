module Framework.TrustBase.Manifest
  ( TrustBaseManifest (..)
  , TrustBaseManifestEvidencePayload (..)
  , TrustBaseManifestEvidenceStatus (..)
  , TrustBaseGatePolicy (..)
  , defaultTrustBaseManifest
  , renderTrustBaseManifest
  , renderTrustBaseManifestEvidencePayload
  , renderTrustBaseManifestEvidencePayloadsJson
  , renderTrustBaseManifestEvidenceStatus
  , renderTrustBaseManifestJson
  , trustBaseManifestEvidenceArtifactSummary
  , trustBaseManifestEvidenceClaimNames
  , trustBaseManifestEvidencePayloadPassed
  , trustBaseManifestRequiredCoreSurfaceModules
  , trustBaseManifestRequiredGatePolicies
  , trustBaseManifestRequiredJsonSchemas
  ) where

import Framework.SelfArtifact
  ( ArtifactManifest (..)
  , ArtifactSource (..)
  , defaultSelfArtifactManifest
  , renderArtifactCommand
  )

data TrustBaseManifest = TrustBaseManifest
  { trustBaseManifestSchema :: String
  , trustBaseManifestName :: String
  , trustBaseManifestHostBoundary :: [String]
  , trustBaseManifestKernelModules :: [String]
  , trustBaseManifestFacadeModules :: [String]
  , trustBaseManifestReportExecutables :: [String]
  , trustBaseManifestWitnessExecutables :: [String]
  , trustBaseManifestArtifactGateExecutable :: String
  , trustBaseManifestArtifactSources :: [String]
  , trustBaseManifestArtifactCommands :: [String]
  , trustBaseManifestJsonSchemas :: [String]
  , trustBaseManifestGatePolicies :: [TrustBaseGatePolicy]
  }
  deriving (Eq, Show)

data TrustBaseGatePolicy = TrustBaseGatePolicy
  { trustBaseGatePolicyName :: String
  , trustBaseGatePolicyCommand :: String
  , trustBaseGatePolicyHighRisk :: Bool
  , trustBaseGatePolicyCommands :: [String]
  }
  deriving (Eq, Show)

defaultTrustBaseManifest :: TrustBaseManifest
defaultTrustBaseManifest =
  TrustBaseManifest
    { trustBaseManifestSchema = "trust-base-manifest.v2"
    , trustBaseManifestName = "bootstrap-kernel"
    , trustBaseManifestHostBoundary =
        [ "ghc"
        , "stack"
        , "os"
        , "filesystem"
        , "process"
        , "terminal-encoding"
        ]
    , trustBaseManifestKernelModules =
        [ "Bootstrap.Runtime"
        , "Bootstrap.Runtime.Types"
        , "Bootstrap.Runtime.Build"
        , "Bootstrap.Runtime.Contract"
        , "Bootstrap.Runtime.Interpreter"
        , "Bootstrap.Runtime.Boundary"
        , "Bootstrap.Runtime.BootstrapHandlers"
        ]
    , trustBaseManifestFacadeModules =
        [ "Framework.TrustBase"
        , "Framework.TrustBase.Manifest"
        , "Framework.Background.ConstraintProof"
        , "Framework.FixedPoint"
        , "Framework.RegistryCodegen"
        , "Framework.Runtime.Concurrency"
        , "Framework.Runtime.Diagnosis"
        , "Framework.Runtime.Evidence"
        , "Framework.Runtime.HotPath"
        , "Framework.Runtime.Interpreter"
        , "Framework.Runtime.Policy"
        , "Framework.SelfArtifact"
        , "Framework.Workflow.Semantics"
        ]
    , trustBaseManifestReportExecutables =
        [ "bootstrap-report"
        , "domain-app-report"
        , "fixed-point-smoke"
        ]
    , trustBaseManifestWitnessExecutables =
        [ "constraint-proof-witness"
        , "workflow-semantics-witness"
        , "runtime-evidence-witness"
        , "runtime-hot-path-witness"
        , "runtime-policy-witness"
        , "runtime-diagnosis-witness"
        , "framework-core-frontend-witness"
        , "registry-codegen-witness"
        , "business-syntax-witness"
        , "trust-base-manifest-witness"
        , "schema-catalog-witness"
        ]
    , trustBaseManifestArtifactGateExecutable = "self-artifact-witness"
    , trustBaseManifestArtifactSources =
        map renderArtifactSourceText (artifactManifestSources defaultSelfArtifactManifest)
    , trustBaseManifestArtifactCommands =
        map renderArtifactCommand (artifactManifestCommands defaultSelfArtifactManifest)
    , trustBaseManifestJsonSchemas =
        trustBaseManifestRequiredJsonSchemas
    , trustBaseManifestGatePolicies =
        trustBaseManifestRequiredGatePolicies
    }

data TrustBaseManifestEvidencePayload = TrustBaseManifestEvidencePayload
  { trustBaseManifestEvidenceClaim :: String
  , trustBaseManifestEvidenceStatus :: TrustBaseManifestEvidenceStatus
  , trustBaseManifestEvidenceExpected :: String
  , trustBaseManifestEvidenceObserved :: String
  , trustBaseManifestEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data TrustBaseManifestEvidenceStatus
  = TrustBaseManifestEvidencePassed
  | TrustBaseManifestEvidenceFailed
  deriving (Eq, Show)

trustBaseManifestEvidencePayloadPassed :: TrustBaseManifestEvidencePayload -> Bool
trustBaseManifestEvidencePayloadPassed payload =
  trustBaseManifestEvidenceStatus payload == TrustBaseManifestEvidencePassed

trustBaseManifestEvidenceClaimNames :: [String]
trustBaseManifestEvidenceClaimNames =
  [ "trust-base-kernel-modules-exposed"
  , "trust-base-facade-modules-exposed"
  , "trust-base-report-executables-present"
  , "trust-base-witness-executables-present"
  , "trust-base-artifact-gate-executable-present"
  , "trust-base-artifact-sources-synced"
  , "trust-base-artifact-commands-synced"
  , "trust-base-core-surface-covered"
  , "trust-base-json-schemas-synced"
  , "trust-base-gate-policies-synced"
  ]

trustBaseManifestEvidenceArtifactSummary :: String
trustBaseManifestEvidenceArtifactSummary =
  "trust base manifest evidence payload claims: "
    ++ joinWith ", " trustBaseManifestEvidenceClaimNames

trustBaseManifestRequiredCoreSurfaceModules :: [String]
trustBaseManifestRequiredCoreSurfaceModules =
  [ "Bootstrap.Runtime"
  , "Bootstrap.Runtime.BootstrapHandlers"
  , "Bootstrap.Runtime.Boundary"
  , "Bootstrap.Runtime.Build"
  , "Bootstrap.Runtime.Contract"
  , "Bootstrap.Runtime.Interpreter"
  , "Bootstrap.Runtime.Types"
  , "Framework.Background.ConstraintProof"
  , "Framework.FixedPoint"
  , "Framework.RegistryCodegen"
  , "Framework.Runtime.Concurrency"
  , "Framework.Runtime.Diagnosis"
  , "Framework.Runtime.Evidence"
  , "Framework.Runtime.HotPath"
  , "Framework.Runtime.Interpreter"
  , "Framework.Runtime.Policy"
  , "Framework.SelfArtifact"
  , "Framework.TrustBase"
  , "Framework.TrustBase.Manifest"
  , "Framework.Workflow.Semantics"
  ]

trustBaseManifestRequiredJsonSchemas :: [String]
trustBaseManifestRequiredJsonSchemas =
  [ "framework-core-report.v1 <- bootstrap-report -- --json"
  , "domain-report.v1 <- domain-app-report -- --json"
  , "fixed-point-report.v1 <- fixed-point-smoke -- --json"
  , "fixed-point-summary.v1 <- fixed-point-smoke -- --summary-json"
  , "framework-core-frontend-evidence.v1 <- framework-core-frontend-witness -- --json"
  , "trust-base-manifest.v2 <- trust-base-manifest-witness -- --json"
  , "trust-base-manifest-evidence.v1 <- trust-base-manifest-witness -- --evidence-json"
  , "schema-catalog-evidence.v1 <- schema-catalog-witness -- --json"
  , "business-syntax-evidence.v1 <- business-syntax-witness -- --json"
  , "runtime-evidence.v1 <- runtime-evidence-witness -- --json"
  , "runtime-hot-path-evidence.v1 <- runtime-hot-path-witness -- --json"
  , "runtime-policy-evidence.v1 <- runtime-policy-witness -- --json"
  , "runtime-diagnosis-evidence.v1 <- runtime-diagnosis-witness -- --json"
  , "workflow-semantics-evidence.v1 <- workflow-semantics-witness -- --json"
  , "runtime-concurrency-evidence.v1 <- workflow-semantics-witness -- --runtime-concurrency-json"
  ]

trustBaseManifestRequiredGatePolicies :: [TrustBaseGatePolicy]
trustBaseManifestRequiredGatePolicies =
  [ TrustBaseGatePolicy
      "check-fast"
      ".\\scripts\\check-fast.cmd -List"
      False
      [ "stack --work-dir .stack-work-codex build"
      , "stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json"
      , "stack --work-dir .stack-work-codex exec business-syntax-witness -- --json"
      , "stack --work-dir .stack-work-codex exec runtime-hot-path-witness -- --json"
      , "stack --work-dir .stack-work-codex exec runtime-policy-witness -- --json"
      , "stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json"
      , "stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json"
      ]
  , TrustBaseGatePolicy
      "check-semantic"
      ".\\scripts\\check-semantic.cmd -List"
      False
      [ "stack --work-dir .stack-work-codex build"
      , "stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json"
      , "stack --work-dir .stack-work-codex exec business-syntax-witness -- --json"
      , "stack --work-dir .stack-work-codex exec domain-app-report -- --json"
      , "stack --work-dir .stack-work-codex exec runtime-hot-path-witness -- --json"
      , "stack --work-dir .stack-work-codex exec runtime-policy-witness -- --json"
      , "stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json"
      , "stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json"
      , "stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --runtime-concurrency-json"
      , "stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json"
      ]
  , TrustBaseGatePolicy
      "check-release"
      ".\\scripts\\check-release.cmd -List"
      False
      releaseGateCommands
  , TrustBaseGatePolicy
      "check-release-with-self-artifact"
      ".\\scripts\\check-release.cmd -IncludeSelfArtifact -List"
      True
      ( releaseGateBaseCommands
          ++ [ "# self-artifact-witness high-risk gate; same HEAD may run only once unless marker is reset"
             , "stack --work-dir .stack-work-codex exec self-artifact-witness"
             ]
      )
  ]

releaseGateCommands :: [String]
releaseGateCommands =
  releaseGateBaseCommands
    ++ ["# self-artifact-witness skipped; pass -IncludeSelfArtifact to run the high-risk artifact gate once"]

releaseGateBaseCommands :: [String]
releaseGateBaseCommands =
  [ "stack --work-dir .stack-work-codex build"
  , "stack --work-dir .stack-work-codex exec mytest"
  , "stack --work-dir .stack-work-codex exec domain-app-report -- --json"
  , "stack --work-dir .stack-work-codex exec domain-app-self-smoke"
  , "stack --work-dir .stack-work-codex exec business-syntax-witness -- --json"
  , "stack --work-dir .stack-work-codex exec framework-core-mytest"
  , "stack --work-dir .stack-work-codex exec bootstrap-smoke"
  , "stack --work-dir .stack-work-codex exec bootstrap-runtime-smoke"
  , "stack --work-dir .stack-work-codex exec bootstrap-report -- --json"
  , "stack --work-dir .stack-work-codex exec fixed-point-smoke -- --summary-json"
  , "stack --work-dir .stack-work-codex exec runtime-evidence-witness -- --json"
  , "stack --work-dir .stack-work-codex exec runtime-hot-path-witness -- --json"
  , "stack --work-dir .stack-work-codex exec runtime-policy-witness -- --json"
  , "stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json"
  , "stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json"
  , "stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --runtime-concurrency-json"
  , "stack --work-dir .stack-work-codex exec constraint-proof-witness -- --smt=auto"
  , "stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json"
  , "stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json"
  , "stack --work-dir .stack-work-codex exec schema-catalog-witness -- --json"
  , "stack --work-dir .stack-work-codex exec registry-codegen-witness"
  ]

renderTrustBaseManifest :: TrustBaseManifest -> [String]
renderTrustBaseManifest manifest =
  [ "trust base manifest"
  , "schema: " ++ trustBaseManifestSchema manifest
  , "name: " ++ trustBaseManifestName manifest
  , "host boundary:"
  ]
    ++ indentLines 2 (trustBaseManifestHostBoundary manifest)
    ++ ["kernel modules:"]
    ++ indentLines 2 (trustBaseManifestKernelModules manifest)
    ++ ["facade modules:"]
    ++ indentLines 2 (trustBaseManifestFacadeModules manifest)
    ++ ["report executables:"]
    ++ indentLines 2 (trustBaseManifestReportExecutables manifest)
    ++ ["witness executables:"]
    ++ indentLines 2 (trustBaseManifestWitnessExecutables manifest)
    ++ ["artifact gate executable: " ++ trustBaseManifestArtifactGateExecutable manifest]
    ++ ["artifact sources:"]
    ++ indentLines 2 (trustBaseManifestArtifactSources manifest)
    ++ ["artifact commands:"]
    ++ indentLines 2 (trustBaseManifestArtifactCommands manifest)
    ++ ["json schemas:"]
    ++ indentLines 2 (trustBaseManifestJsonSchemas manifest)
    ++ ["gate policies:"]
    ++ indentLines 2 (concatMap renderTrustBaseGatePolicy (trustBaseManifestGatePolicies manifest))

renderTrustBaseGatePolicy :: TrustBaseGatePolicy -> [String]
renderTrustBaseGatePolicy policy =
  [ trustBaseGatePolicyName policy
      ++ ": "
      ++ trustBaseGatePolicyCommand policy
      ++ " highRisk="
      ++ show (trustBaseGatePolicyHighRisk policy)
  ]
    ++ indentLines 2 (trustBaseGatePolicyCommands policy)

renderTrustBaseManifestEvidencePayload :: TrustBaseManifestEvidencePayload -> [String]
renderTrustBaseManifestEvidencePayload payload =
  [ "claim: " ++ trustBaseManifestEvidenceClaim payload
  , "status: " ++ renderTrustBaseManifestEvidenceStatus (trustBaseManifestEvidenceStatus payload)
  , "expected: " ++ trustBaseManifestEvidenceExpected payload
  , "observed: " ++ trustBaseManifestEvidenceObserved payload
  , "artifact: " ++ trustBaseManifestEvidenceArtifact payload
  ]

renderTrustBaseManifestEvidenceStatus :: TrustBaseManifestEvidenceStatus -> String
renderTrustBaseManifestEvidenceStatus TrustBaseManifestEvidencePassed =
  "passed"
renderTrustBaseManifestEvidenceStatus TrustBaseManifestEvidenceFailed =
  "failed"

renderTrustBaseManifestEvidencePayloadsJson :: [TrustBaseManifestEvidencePayload] -> String
renderTrustBaseManifestEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "trust-base-manifest-evidence.v1")
    , jsonField "status" (jsonString statusText)
    , jsonField "payloads" (jsonArray (map trustBaseManifestEvidencePayloadJson payloads))
    ]
  where
    statusText =
      if all trustBaseManifestEvidencePayloadPassed payloads
        then "passed"
        else "failed"

trustBaseManifestEvidencePayloadJson :: TrustBaseManifestEvidencePayload -> String
trustBaseManifestEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (trustBaseManifestEvidenceClaim payload))
    , jsonField "status" (jsonString (renderTrustBaseManifestEvidenceStatus (trustBaseManifestEvidenceStatus payload)))
    , jsonField "expected" (jsonString (trustBaseManifestEvidenceExpected payload))
    , jsonField "observed" (jsonString (trustBaseManifestEvidenceObserved payload))
    , jsonField "artifact" (jsonString (trustBaseManifestEvidenceArtifact payload))
    ]

renderTrustBaseManifestJson :: TrustBaseManifest -> String
renderTrustBaseManifestJson manifest =
  jsonObject
    [ jsonField "schema" (jsonString (trustBaseManifestSchema manifest))
    , jsonField "name" (jsonString (trustBaseManifestName manifest))
    , jsonField "hostBoundary" (jsonStringArray (trustBaseManifestHostBoundary manifest))
    , jsonField "kernelModules" (jsonStringArray (trustBaseManifestKernelModules manifest))
    , jsonField "facadeModules" (jsonStringArray (trustBaseManifestFacadeModules manifest))
    , jsonField "reportExecutables" (jsonStringArray (trustBaseManifestReportExecutables manifest))
    , jsonField "witnessExecutables" (jsonStringArray (trustBaseManifestWitnessExecutables manifest))
    , jsonField "artifactGateExecutable" (jsonString (trustBaseManifestArtifactGateExecutable manifest))
    , jsonField "artifactSources" (jsonStringArray (trustBaseManifestArtifactSources manifest))
    , jsonField "artifactCommands" (jsonStringArray (trustBaseManifestArtifactCommands manifest))
    , jsonField "jsonSchemas" (jsonStringArray (trustBaseManifestJsonSchemas manifest))
    , jsonField "gatePolicies" (jsonArray (map trustBaseGatePolicyJson (trustBaseManifestGatePolicies manifest)))
    ]

trustBaseGatePolicyJson :: TrustBaseGatePolicy -> String
trustBaseGatePolicyJson policy =
  jsonObject
    [ jsonField "name" (jsonString (trustBaseGatePolicyName policy))
    , jsonField "command" (jsonString (trustBaseGatePolicyCommand policy))
    , jsonField "highRisk" (jsonBool (trustBaseGatePolicyHighRisk policy))
    , jsonField "commands" (jsonStringArray (trustBaseGatePolicyCommands policy))
    ]

renderArtifactSourceText :: ArtifactSource -> String
renderArtifactSourceText source =
  artifactSourcePath source ++ " -> " ++ artifactTargetPath source

indentLines :: Int -> [String] -> [String]
indentLines count =
  map (replicate count ' ' ++)

jsonObject :: [String] -> String
jsonObject fields =
  "{" ++ joinWith "," fields ++ "}"

jsonField :: String -> String -> String
jsonField name value =
  jsonString name ++ ":" ++ value

jsonArray :: [String] -> String
jsonArray values =
  "[" ++ joinWith "," values ++ "]"

jsonStringArray :: [String] -> String
jsonStringArray values =
  "[" ++ joinWith "," (map jsonString values) ++ "]"

jsonBool :: Bool -> String
jsonBool True =
  "true"
jsonBool False =
  "false"

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
