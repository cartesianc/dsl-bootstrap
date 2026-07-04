module Framework.TrustBase.Manifest
  ( TrustBaseManifest (..)
  , TrustBaseManifestEvidencePayload (..)
  , TrustBaseManifestEvidenceStatus (..)
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
  }
  deriving (Eq, Show)

defaultTrustBaseManifest :: TrustBaseManifest
defaultTrustBaseManifest =
  TrustBaseManifest
    { trustBaseManifestSchema = "trust-base-manifest.v1"
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
        ]
    , trustBaseManifestArtifactGateExecutable = "self-artifact-witness"
    , trustBaseManifestArtifactSources =
        map renderArtifactSourceText (artifactManifestSources defaultSelfArtifactManifest)
    , trustBaseManifestArtifactCommands =
        map renderArtifactCommand (artifactManifestCommands defaultSelfArtifactManifest)
    , trustBaseManifestJsonSchemas =
        trustBaseManifestRequiredJsonSchemas
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
  , "trust-base-manifest.v1 <- trust-base-manifest-witness -- --json"
  , "trust-base-manifest-evidence.v1 <- trust-base-manifest-witness -- --evidence-json"
  , "business-syntax-evidence.v1 <- business-syntax-witness -- --json"
  , "runtime-evidence.v1 <- runtime-evidence-witness -- --json"
  , "runtime-hot-path-evidence.v1 <- runtime-hot-path-witness -- --json"
  , "runtime-policy-evidence.v1 <- runtime-policy-witness -- --json"
  , "runtime-diagnosis-evidence.v1 <- runtime-diagnosis-witness -- --json"
  , "workflow-semantics-evidence.v1 <- workflow-semantics-witness -- --json"
  , "runtime-concurrency-evidence.v1 <- workflow-semantics-witness -- --runtime-concurrency-json"
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
