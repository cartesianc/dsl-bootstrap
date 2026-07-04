module Framework.TrustBase.Manifest
  ( SchemaCatalogEvidencePayload (..)
  , SchemaCatalogEvidenceStatus (..)
  , TrustBaseManifest (..)
  , TrustBaseManifestEvidencePayload (..)
  , TrustBaseManifestEvidenceStatus (..)
  , TrustBaseGatePolicy (..)
  , defaultTrustBaseManifest
  , renderSchemaCatalogEvidencePayload
  , renderSchemaCatalogEvidencePayloadsJson
  , renderSchemaCatalogEvidenceStatus
  , renderTrustBaseManifest
  , renderTrustBaseManifestEvidencePayload
  , renderTrustBaseManifestEvidencePayloadsJson
  , renderTrustBaseManifestEvidenceStatus
  , renderTrustBaseManifestJson
  , schemaCatalogClaimManifestPayload
  , schemaCatalogCoreClaimNames
  , schemaCatalogEvidence
  , schemaCatalogEvidenceArtifactSummary
  , schemaCatalogEvidenceClaimNames
  , schemaCatalogEvidencePayloadPassed
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
        , "Framework.TrustBase.SelfInterpret"
        , "Framework.Background.ConstraintProof"
        , "Framework.FixedPoint"
        , "Framework.RegistryCodegen"
        , "Framework.Runtime.Concurrency"
        , "Framework.Runtime.Diagnosis"
        , "Framework.Runtime.Evidence"
        , "Framework.Runtime.Handlers"
        , "Framework.Runtime.HotPath"
        , "Framework.Runtime.Interpreter"
        , "Framework.Runtime.Policy"
        , "Framework.Runtime.State"
        , "Framework.Runtime.Types"
        , "Framework.Runtime.Values"
        , "Framework.SelfArtifact"
        , "Framework.Workflow.Semantics"
        ]
    , trustBaseManifestReportExecutables =
        [ "bootstrap-report"
        , "domain-app-report"
        , "fixed-point-smoke"
        , "core-self-interpret"
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
        , "architecture-concern-witness"
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

data SchemaCatalogEvidencePayload = SchemaCatalogEvidencePayload
  { schemaCatalogEvidenceClaim :: String
  , schemaCatalogEvidenceStatus :: SchemaCatalogEvidenceStatus
  , schemaCatalogEvidenceExpected :: String
  , schemaCatalogEvidenceObserved :: String
  , schemaCatalogEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data SchemaCatalogEvidenceStatus
  = SchemaCatalogEvidencePassed
  | SchemaCatalogEvidenceFailed
  deriving (Eq, Show)

trustBaseManifestEvidencePayloadPassed :: TrustBaseManifestEvidencePayload -> Bool
trustBaseManifestEvidencePayloadPassed payload =
  trustBaseManifestEvidenceStatus payload == TrustBaseManifestEvidencePassed

schemaCatalogEvidencePayloadPassed :: SchemaCatalogEvidencePayload -> Bool
schemaCatalogEvidencePayloadPassed payload =
  schemaCatalogEvidenceStatus payload == SchemaCatalogEvidencePassed

schemaCatalogCoreClaimNames :: [String]
schemaCatalogCoreClaimNames =
  map schemaCatalogClaimNameForEntry trustBaseManifestRequiredJsonSchemas

schemaCatalogEvidenceClaimNames :: [String]
schemaCatalogEvidenceClaimNames =
  schemaCatalogCoreClaimNames ++ ["schema-catalog-claim-manifest"]

schemaCatalogEvidenceArtifactSummary :: String
schemaCatalogEvidenceArtifactSummary =
  "schema catalog evidence payload claims: "
    ++ joinWith ", " schemaCatalogEvidenceClaimNames

trustBaseManifestEvidenceClaimNames :: [String]
trustBaseManifestEvidenceClaimNames =
  [ "trust-base-kernel-modules-exposed"
  , "trust-base-facade-modules-exposed"
  , "trust-base-report-executables-present"
  , "trust-base-witness-executables-present"
  , "trust-base-artifact-gate-executable-present"
  , "trust-base-artifact-sources-synced"
  , "trust-base-artifact-commands-synced"
  , "trust-base-artifact-docs-excluded"
  , "trust-base-core-surface-covered"
  , "trust-base-json-schemas-synced"
  , "trust-base-gate-policies-synced"
  , "trust-base-manifest-claim-manifest"
  ]

trustBaseManifestEvidenceArtifactSummary :: String
trustBaseManifestEvidenceArtifactSummary =
  "trust base manifest evidence payload claims: "
    ++ joinWith ", " trustBaseManifestEvidenceClaimNames

schemaCatalogEvidence :: String -> Bool -> String -> String -> String -> SchemaCatalogEvidencePayload
schemaCatalogEvidence claim passed expected observed artifact =
  SchemaCatalogEvidencePayload
    { schemaCatalogEvidenceClaim = claim
    , schemaCatalogEvidenceStatus =
        if passed
          then SchemaCatalogEvidencePassed
          else SchemaCatalogEvidenceFailed
    , schemaCatalogEvidenceExpected = expected
    , schemaCatalogEvidenceObserved = observed
    , schemaCatalogEvidenceArtifact = artifact
    }

schemaCatalogClaimManifestPayload :: [SchemaCatalogEvidencePayload] -> SchemaCatalogEvidencePayload
schemaCatalogClaimManifestPayload payloads =
  schemaCatalogEvidence
    "schema-catalog-claim-manifest"
    manifestSynced
    "schema catalog payload claims match exported claim manifest"
    observed
    "SchemaCatalogClaimManifestArtifact"
  where
    actualCoreClaimNames =
      map schemaCatalogEvidenceClaim payloads
    actualEvidenceClaimNames =
      actualCoreClaimNames ++ ["schema-catalog-claim-manifest"]
    manifestSynced =
      actualCoreClaimNames == schemaCatalogCoreClaimNames
        && actualEvidenceClaimNames == schemaCatalogEvidenceClaimNames
    observed =
      if manifestSynced
        then "claim manifest synced: " ++ show (length actualCoreClaimNames) ++ " core claims"
        else "expected " ++ show schemaCatalogEvidenceClaimNames ++ "; actual " ++ show actualEvidenceClaimNames

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
  , "Framework.Runtime.Handlers"
  , "Framework.Runtime.HotPath"
  , "Framework.Runtime.Interpreter"
  , "Framework.Runtime.Policy"
  , "Framework.Runtime.State"
  , "Framework.Runtime.Types"
  , "Framework.Runtime.Values"
  , "Framework.SelfArtifact"
  , "Framework.TrustBase"
  , "Framework.TrustBase.Manifest"
  , "Framework.TrustBase.SelfInterpret"
  , "Framework.Workflow.Semantics"
  ]

trustBaseManifestRequiredJsonSchemas :: [String]
trustBaseManifestRequiredJsonSchemas =
  [ "framework-core-report.v1 <- bootstrap-report -- --json"
  , "domain-report.v1 <- domain-app-report -- --json"
  , "ast-tree.v1 <- ast-tree -- json all"
  , "domain-registry.v1 <- domain-registry -- --json"
  , "domain-map.v1 <- domain-map -- json all"
  , "fixed-point-report.v1 <- fixed-point-smoke -- --json"
  , "fixed-point-summary.v1 <- fixed-point-smoke -- --summary-json"
  , "core-self-interpret-report.v1 <- core-self-interpret -- --json"
  , "framework-core-frontend-evidence.v1 <- framework-core-frontend-witness -- --json"
  , "trust-base-manifest.v2 <- trust-base-manifest-witness -- --json"
  , "trust-base-manifest-evidence.v1 <- trust-base-manifest-witness -- --evidence-json"
  , "schema-catalog-evidence.v1 <- schema-catalog-witness -- --json"
  , "constraint-proof-evidence.v1 <- constraint-proof-witness -- --smt=off --json"
  , "business-syntax-evidence.v1 <- business-syntax-witness -- --json"
  , "runtime-evidence.v1 <- runtime-evidence-witness -- --json"
  , "runtime-hot-path-evidence.v1 <- runtime-hot-path-witness -- --json"
  , "runtime-policy-evidence.v1 <- runtime-policy-witness -- --json"
  , "runtime-diagnosis-evidence.v1 <- runtime-diagnosis-witness -- --json"
  , "registry-codegen-evidence.v1 <- registry-codegen-witness -- --json"
  , "workflow-semantics-evidence.v1 <- workflow-semantics-witness -- --json"
  , "runtime-concurrency-evidence.v1 <- workflow-semantics-witness -- --runtime-concurrency-json"
  , "architecture-concern-evidence.v1 <- architecture-concern-witness -- --json"
  ]

trustBaseManifestRequiredGatePolicies :: [TrustBaseGatePolicy]
trustBaseManifestRequiredGatePolicies =
  [ TrustBaseGatePolicy
      "check-fast"
      ".\\scripts\\check-fast.cmd -List"
      False
      [ "stack --work-dir .stack-work-codex build"
      , "stack --work-dir .stack-work-codex exec core-self-interpret -- --json"
      ]
  , TrustBaseGatePolicy
      "check-semantic"
      ".\\scripts\\check-semantic.cmd -List"
      False
      [ "stack --work-dir .stack-work-codex build"
      , "stack --work-dir .stack-work-codex exec core-self-interpret -- --json"
      , "stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json"
      , "stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json"
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

releaseGateBaseCommands :: [String]
releaseGateBaseCommands =
  [ "stack --work-dir .stack-work-codex build"
  , "stack --work-dir .stack-work-codex exec core-self-interpret -- --json"
  , "stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json"
  , "stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json"
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

renderSchemaCatalogEvidencePayload :: SchemaCatalogEvidencePayload -> [String]
renderSchemaCatalogEvidencePayload payload =
  [ "claim: " ++ schemaCatalogEvidenceClaim payload
  , "status: " ++ renderSchemaCatalogEvidenceStatus (schemaCatalogEvidenceStatus payload)
  , "expected: " ++ schemaCatalogEvidenceExpected payload
  , "observed: " ++ schemaCatalogEvidenceObserved payload
  , "artifact: " ++ schemaCatalogEvidenceArtifact payload
  ]

renderSchemaCatalogEvidenceStatus :: SchemaCatalogEvidenceStatus -> String
renderSchemaCatalogEvidenceStatus SchemaCatalogEvidencePassed =
  "passed"
renderSchemaCatalogEvidenceStatus SchemaCatalogEvidenceFailed =
  "failed"

renderSchemaCatalogEvidencePayloadsJson :: [SchemaCatalogEvidencePayload] -> String
renderSchemaCatalogEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "schema-catalog-evidence.v1")
    , jsonField "status" (jsonString statusText)
    , jsonField "payloads" (jsonArray (map schemaCatalogEvidencePayloadJson payloads))
    ]
  where
    statusText =
      if all schemaCatalogEvidencePayloadPassed payloads
        then "passed"
        else "failed"

schemaCatalogEvidencePayloadJson :: SchemaCatalogEvidencePayload -> String
schemaCatalogEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (schemaCatalogEvidenceClaim payload))
    , jsonField "status" (jsonString (renderSchemaCatalogEvidenceStatus (schemaCatalogEvidenceStatus payload)))
    , jsonField "expected" (jsonString (schemaCatalogEvidenceExpected payload))
    , jsonField "observed" (jsonString (schemaCatalogEvidenceObserved payload))
    , jsonField "artifact" (jsonString (schemaCatalogEvidenceArtifact payload))
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

schemaCatalogClaimNameForEntry :: String -> String
schemaCatalogClaimNameForEntry entry =
  "schema-catalog-output:" ++ schemaCatalogSchemaNameForEntry entry

schemaCatalogSchemaNameForEntry :: String -> String
schemaCatalogSchemaNameForEntry entry =
  case breakOn " <- " entry of
    Just (schemaName, _) ->
      schemaName
    Nothing ->
      entry

breakOn :: String -> String -> Maybe (String, String)
breakOn marker text =
  go "" text
  where
    go _ [] =
      Nothing
    go prefix rest
      | marker `isPrefixOfLocal` rest =
          Just (prefix, drop (length marker) rest)
      | otherwise =
          case rest of
            current : next ->
              go (prefix ++ [current]) next

isPrefixOfLocal :: String -> String -> Bool
isPrefixOfLocal [] _ =
  True
isPrefixOfLocal _ [] =
  False
isPrefixOfLocal (left : leftRest) (right : rightRest)
  | left == right =
      isPrefixOfLocal leftRest rightRest
  | otherwise =
      False

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
