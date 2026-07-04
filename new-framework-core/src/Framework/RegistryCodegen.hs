module Framework.RegistryCodegen
  ( EffectRegistryBinding (..)
  , GeneratedSource (..)
  , PluginRegistryBinding (..)
  , diffGeneratedLines
  , frameworkCoreFrontendSources
  , generatedLinesMatch
  , registryCodegenEvidenceClaimNames
  , registryCodegenEvidenceStatus
  , renderRegistryCodegenEvidencePayload
  , renderRegistryCodegenEvidencePayloadsJson
  , renderEffectsTheoryModule
  , renderFrameworkCoreBaseAppModule
  , renderFrameworkCoreCurrentAppModule
  , renderFrameworkCoreCurrentAstModule
  , renderFrameworkCoreCurrentEffectsModule
  , renderFrameworkCoreCurrentInterpreterModule
  , renderPluginsModule
  ) where

import Bootstrap.RegistryCodegen
  ( GeneratedSource (..)
  , frameworkCoreFrontendSources
  , renderFrameworkCoreBaseAppModule
  , renderFrameworkCoreCurrentAppModule
  , renderFrameworkCoreCurrentAstModule
  , renderFrameworkCoreCurrentEffectsModule
  , renderFrameworkCoreCurrentInterpreterModule
  )
import Framework.Domain
  ( DomainSemanticEvidencePayload (..) )

data PluginRegistryBinding = PluginRegistryBinding
  { pluginRegistryBindingName :: String
  , pluginRegistryBindingModule :: String
  , pluginRegistryBindingSource :: String
  }
  deriving (Eq, Show)

data EffectRegistryBinding = EffectRegistryBinding
  { effectRegistryBindingModule :: String
  , effectRegistryBindingName :: String
  }
  deriving (Eq, Show)

registryCodegenEvidenceClaimNames :: [String]
registryCodegenEvidenceClaimNames =
  [ "registry-codegen-plugins"
  , "registry-codegen-effects"
  ]

renderRegistryCodegenEvidencePayload :: DomainSemanticEvidencePayload -> [String]
renderRegistryCodegenEvidencePayload payload =
  [ "claim: " ++ domainSemanticEvidencePayloadClaim payload
  , "status: " ++ domainSemanticEvidencePayloadStatus payload
  , "expected: " ++ domainSemanticEvidencePayloadExpected payload
  , "observed: " ++ domainSemanticEvidencePayloadObserved payload
  , "artifact: " ++ domainSemanticEvidencePayloadArtifact payload
  ]

renderRegistryCodegenEvidencePayloadsJson :: [DomainSemanticEvidencePayload] -> [String] -> [String] -> [String] -> [String] -> String
renderRegistryCodegenEvidencePayloadsJson payloads missing failed missingPayloads failedPayloads =
  jsonObject
    [ jsonField "schema" (jsonString "registry-codegen-evidence.v1")
    , jsonField "status" (jsonString (registryCodegenEvidenceStatus missing failed missingPayloads failedPayloads))
    , jsonField "payloads" (jsonArray (map registryCodegenEvidencePayloadJson payloads))
    , jsonField "missing" (jsonStringArray missing)
    , jsonField "failed" (jsonStringArray failed)
    , jsonField "missingPayloads" (jsonStringArray missingPayloads)
    , jsonField "failedPayloads" (jsonStringArray failedPayloads)
    ]

registryCodegenEvidenceStatus :: [String] -> [String] -> [String] -> [String] -> String
registryCodegenEvidenceStatus [] [] [] [] =
  "passed"
registryCodegenEvidenceStatus _ _ _ _ =
  "failed"

registryCodegenEvidencePayloadJson :: DomainSemanticEvidencePayload -> String
registryCodegenEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (domainSemanticEvidencePayloadClaim payload))
    , jsonField "status" (jsonString (domainSemanticEvidencePayloadStatus payload))
    , jsonField "expected" (jsonString (domainSemanticEvidencePayloadExpected payload))
    , jsonField "observed" (jsonString (domainSemanticEvidencePayloadObserved payload))
    , jsonField "artifact" (jsonString (domainSemanticEvidencePayloadArtifact payload))
    ]

renderPluginsModule :: [PluginRegistryBinding] -> [String]
renderPluginsModule bindings =
  [ "{-# OPTIONS_GHC -Wno-missing-export-lists #-}"
  , "{-# OPTIONS_GHC -Wno-missing-signatures #-}"
  , ""
  , "module Plugins"
  , "  where"
  , ""
  ]
    ++ map (("import qualified " ++) . pluginRegistryBindingModule) (uniqueOn pluginRegistryBindingModule bindings)
    ++ [""]
    ++
    [ pluginRegistryBindingName binding
        ++ " = "
        ++ pluginRegistryBindingModule binding
        ++ "."
        ++ pluginRegistryBindingSource binding
    | binding <- bindings
    ]

renderEffectsTheoryModule :: [EffectRegistryBinding] -> [String]
renderEffectsTheoryModule bindings =
  [ "{-# OPTIONS_GHC -Wno-missing-export-lists #-}"
  , "{-# OPTIONS_GHC -Wno-missing-signatures #-}"
  , ""
  , "module Effects.Theory"
  , "  ( effectTheory"
  , "  ) where"
  , ""
  , "import Framework.Business"
  , "  ( EffectTheory"
  , "  , theory"
  , "  )"
  ]
    ++ map (("import qualified " ++) . effectRegistryBindingModule) bindings
    ++ [ ""
       , "effectTheory :: EffectTheory"
       , "effectTheory ="
       , "  theory"
       ]
    ++ renderEffectList bindings

generatedLinesMatch :: [String] -> [String] -> Bool
generatedLinesMatch expected actual =
  normalizeLines expected == normalizeLines actual

diffGeneratedLines :: [String] -> [String] -> [String]
diffGeneratedLines expected actual =
  [ "expected:"
  ]
    ++ numberedLines (normalizeLines expected)
    ++ [ "actual:"
       ]
    ++ numberedLines (normalizeLines actual)

renderEffectList :: [EffectRegistryBinding] -> [String]
renderEffectList [] =
  ["    []"]
renderEffectList (binding : rest) =
  ("    [ " ++ renderEffectBinding binding)
    : map (("    , " ++) . renderEffectBinding) rest
    ++ ["    ]"]

renderEffectBinding :: EffectRegistryBinding -> String
renderEffectBinding binding =
  effectRegistryBindingModule binding ++ "." ++ effectRegistryBindingName binding

normalizeLines :: [String] -> [String]
normalizeLines =
  dropTrailingBlank . map trimLineEnding

trimLineEnding :: String -> String
trimLineEnding line =
  case reverse line of
    '\r' : rest ->
      reverse rest
    _ ->
      line

dropTrailingBlank :: [String] -> [String]
dropTrailingBlank =
  reverse . dropWhile null . reverse

numberedLines :: [String] -> [String]
numberedLines linesToNumber =
  zipWith renderNumberedLine [(1 :: Int) ..] linesToNumber

renderNumberedLine :: Int -> String -> String
renderNumberedLine lineNumber line =
  show lineNumber ++ ": " ++ line

uniqueOn :: Eq key => (item -> key) -> [item] -> [item]
uniqueOn keyFor =
  foldl appendUnique []
  where
    appendUnique items item
      | keyFor item `elem` map keyFor items =
          items
      | otherwise =
          items ++ [item]

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
jsonStringArray =
  jsonArray . map jsonString

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
