module Framework.TrustBase.Manifest
  ( TrustBaseManifest (..)
  , defaultTrustBaseManifest
  , renderTrustBaseManifest
  , renderTrustBaseManifestJson
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
    }

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
