{-# LANGUAGE PatternSynonyms #-}

module Framework.Frontend.Evidence
  ( FrontendClaimModuleLink (..)
  , FrameworkCoreFrontendEvidencePayload (..)
  , FrameworkCoreFrontendEvidenceStatus (..)
  , frameworkCoreFrontendCoreClaimNames
  , frameworkCoreFrontendEvidence
  , frameworkCoreFrontendEvidenceClaimNames
  , frameworkCoreFrontendEvidencePayloadPassed
  , frontendClaimModuleLinkEvidenceClaimName
  , frontendClaimModuleLinks
  , renderFrameworkCoreFrontendEvidencePayload
  , renderFrameworkCoreFrontendEvidencePayloadsJson
  , renderFrameworkCoreFrontendEvidenceStatus
  ) where

import Domain.Vocabulary
  ( pattern AstStructureExpressedFact
  , pattern EffectTheoryDslExpressedFact
  , pattern RegistryCodegenExpressedFact
  , pattern RuntimeBackendParityExpressedFact
  , pattern RuntimeConcurrencySemanticsExpressedFact
  , pattern RuntimeDiagnosisExpressedFact
  , pattern RuntimeFactClosureExpressedFact
  , pattern SelfArtifactManifestExpressedFact
  )
import Framework.Ast
  ( WorkflowFact )
import Framework.RegistryCodegen
  ( GeneratedSource (..)
  , frameworkCoreFrontendSources
  )

data FrontendClaimModuleLink = FrontendClaimModuleLink
  { frontendClaimModuleFact :: WorkflowFact
  , frontendClaimModuleName :: String
  }
  deriving (Eq, Show)

data FrameworkCoreFrontendEvidencePayload = FrameworkCoreFrontendEvidencePayload
  { frameworkCoreFrontendEvidenceClaim :: String
  , frameworkCoreFrontendEvidenceStatus :: FrameworkCoreFrontendEvidenceStatus
  , frameworkCoreFrontendEvidenceExpected :: String
  , frameworkCoreFrontendEvidenceObserved :: String
  , frameworkCoreFrontendEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data FrameworkCoreFrontendEvidenceStatus
  = FrameworkCoreFrontendEvidencePassed
  | FrameworkCoreFrontendEvidenceFailed
  deriving (Eq, Show)

frontendClaimModuleLinks :: [FrontendClaimModuleLink]
frontendClaimModuleLinks =
  [ FrontendClaimModuleLink AstStructureExpressedFact "Framework.Ast"
  , FrontendClaimModuleLink EffectTheoryDslExpressedFact "Framework.Effect"
  , FrontendClaimModuleLink RuntimeConcurrencySemanticsExpressedFact "Framework.Runtime.Concurrency"
  , FrontendClaimModuleLink RuntimeDiagnosisExpressedFact "Framework.Runtime.Diagnosis"
  , FrontendClaimModuleLink RuntimeBackendParityExpressedFact "Framework.FixedPoint"
  , FrontendClaimModuleLink RuntimeFactClosureExpressedFact "Framework.Runtime.Evidence"
  , FrontendClaimModuleLink RegistryCodegenExpressedFact "Framework.RegistryCodegen"
  , FrontendClaimModuleLink SelfArtifactManifestExpressedFact "Framework.SelfArtifact"
  ]

frameworkCoreFrontendCoreClaimNames :: [String]
frameworkCoreFrontendCoreClaimNames =
  map generatedSourceClaimName frameworkCoreFrontendSources
    ++ map frontendClaimModuleLinkEvidenceClaimName frontendClaimModuleLinks
    ++ [ "framework-core-frontend-core-surface-exposed-modules"
       , "framework-core-frontend-runtime-diagnosis-implementation-boundary"
       ]

frameworkCoreFrontendEvidenceClaimNames :: [String]
frameworkCoreFrontendEvidenceClaimNames =
  frameworkCoreFrontendCoreClaimNames ++ ["framework-core-frontend-claim-manifest"]

frontendClaimModuleLinkEvidenceClaimName :: FrontendClaimModuleLink -> String
frontendClaimModuleLinkEvidenceClaimName link =
  "framework-core-frontend-claim-link:" ++ show (frontendClaimModuleFact link)

generatedSourceClaimName :: GeneratedSource -> String
generatedSourceClaimName source =
  "framework-core-frontend-generated-source:" ++ generatedSourcePath source

frameworkCoreFrontendEvidence :: String -> Bool -> String -> String -> String -> FrameworkCoreFrontendEvidencePayload
frameworkCoreFrontendEvidence claim passed expected observed artifact =
  FrameworkCoreFrontendEvidencePayload
    { frameworkCoreFrontendEvidenceClaim = claim
    , frameworkCoreFrontendEvidenceStatus =
        if passed
          then FrameworkCoreFrontendEvidencePassed
          else FrameworkCoreFrontendEvidenceFailed
    , frameworkCoreFrontendEvidenceExpected = expected
    , frameworkCoreFrontendEvidenceObserved = observed
    , frameworkCoreFrontendEvidenceArtifact = artifact
    }

frameworkCoreFrontendEvidencePayloadPassed :: FrameworkCoreFrontendEvidencePayload -> Bool
frameworkCoreFrontendEvidencePayloadPassed payload =
  frameworkCoreFrontendEvidenceStatus payload == FrameworkCoreFrontendEvidencePassed

renderFrameworkCoreFrontendEvidencePayload :: FrameworkCoreFrontendEvidencePayload -> [String]
renderFrameworkCoreFrontendEvidencePayload payload =
  [ "claim: " ++ frameworkCoreFrontendEvidenceClaim payload
  , "status: " ++ renderFrameworkCoreFrontendEvidenceStatus (frameworkCoreFrontendEvidenceStatus payload)
  , "expected: " ++ frameworkCoreFrontendEvidenceExpected payload
  , "observed: " ++ frameworkCoreFrontendEvidenceObserved payload
  , "artifact: " ++ frameworkCoreFrontendEvidenceArtifact payload
  ]

renderFrameworkCoreFrontendEvidenceStatus :: FrameworkCoreFrontendEvidenceStatus -> String
renderFrameworkCoreFrontendEvidenceStatus FrameworkCoreFrontendEvidencePassed =
  "passed"
renderFrameworkCoreFrontendEvidenceStatus FrameworkCoreFrontendEvidenceFailed =
  "failed"

renderFrameworkCoreFrontendEvidencePayloadsJson :: [FrameworkCoreFrontendEvidencePayload] -> String
renderFrameworkCoreFrontendEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "framework-core-frontend-evidence.v1")
    , jsonField "status" (jsonString statusText)
    , jsonField "payloads" (jsonArray (map frameworkCoreFrontendEvidencePayloadJson payloads))
    ]
  where
    statusText =
      if all frameworkCoreFrontendEvidencePayloadPassed payloads
        then "passed"
        else "failed"

frameworkCoreFrontendEvidencePayloadJson :: FrameworkCoreFrontendEvidencePayload -> String
frameworkCoreFrontendEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (frameworkCoreFrontendEvidenceClaim payload))
    , jsonField "status" (jsonString (renderFrameworkCoreFrontendEvidenceStatus (frameworkCoreFrontendEvidenceStatus payload)))
    , jsonField "expected" (jsonString (frameworkCoreFrontendEvidenceExpected payload))
    , jsonField "observed" (jsonString (frameworkCoreFrontendEvidenceObserved payload))
    , jsonField "artifact" (jsonString (frameworkCoreFrontendEvidenceArtifact payload))
    ]

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
