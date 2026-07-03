{-# LANGUAGE PatternSynonyms #-}

module Framework.Runtime.Policy
  ( RuntimePolicyEvidencePayload (..)
  , RuntimePolicyEvidenceStatus (..)
  , renderRuntimePolicyEvidencePayload
  , renderRuntimePolicyEvidencePayloadsJson
  , renderRuntimePolicyEvidenceStatus
  , runtimePolicyEvidenceArtifactSummary
  , runtimePolicyEvidenceClaimNames
  , runtimePolicyEvidencePayloadPassed
  , runtimePolicyEvidencePayloads
  ) where

import Bootstrap.Effect
  ( TypeName )
import Bootstrap.Report
  ( FactClosureReport (..)
  , FrameworkCoreReport (..)
  )
import Bootstrap.Runtime
  ( RuntimeArtifact (..)
  )
import Bootstrap.Vocabulary
  ( pattern RuntimeErrorDispatchArtifact
  , pattern RuntimeErrorDispatchValidatedFact
  , pattern RuntimeIdempotencyPolicyArtifact
  , pattern RuntimeIdempotencyPolicyValidatedFact
  , pattern RuntimeRetryPolicyArtifact
  , pattern RuntimeRetryPolicyValidatedFact
  )
import Bootstrap.Workflow
  ( WorkflowFact )

data RuntimePolicyEvidencePayload = RuntimePolicyEvidencePayload
  { runtimePolicyEvidenceClaim :: String
  , runtimePolicyEvidenceStatus :: RuntimePolicyEvidenceStatus
  , runtimePolicyEvidenceExpected :: String
  , runtimePolicyEvidenceObserved :: String
  , runtimePolicyEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data RuntimePolicyEvidenceStatus
  = RuntimePolicyEvidencePassed
  | RuntimePolicyEvidenceFailed
  deriving (Eq, Show)

data RuntimePolicyEvidenceSpec = RuntimePolicyEvidenceSpec
  { runtimePolicyEvidenceSpecClaim :: String
  , runtimePolicyEvidenceSpecFact :: WorkflowFact
  , runtimePolicyEvidenceSpecArtifact :: TypeName
  , runtimePolicyEvidenceSpecExpected :: String
  }

runtimePolicyEvidencePayloads :: FrameworkCoreReport -> [RuntimePolicyEvidencePayload]
runtimePolicyEvidencePayloads report =
  map (`runtimePolicyEvidencePayload` report) runtimePolicyEvidenceSpecs

runtimePolicyEvidenceClaimNames :: [String]
runtimePolicyEvidenceClaimNames =
  map runtimePolicyEvidenceSpecClaim runtimePolicyEvidenceSpecs

runtimePolicyEvidenceArtifactSummary :: String
runtimePolicyEvidenceArtifactSummary =
  "runtime policy evidence payload claims: "
    ++ joinWith ", " runtimePolicyEvidenceClaimNames

runtimePolicyEvidencePayloadPassed :: RuntimePolicyEvidencePayload -> Bool
runtimePolicyEvidencePayloadPassed payload =
  runtimePolicyEvidenceStatus payload == RuntimePolicyEvidencePassed

renderRuntimePolicyEvidencePayload :: RuntimePolicyEvidencePayload -> [String]
renderRuntimePolicyEvidencePayload payload =
  [ "claim: " ++ runtimePolicyEvidenceClaim payload
  , "status: " ++ renderRuntimePolicyEvidenceStatus (runtimePolicyEvidenceStatus payload)
  , "expected: " ++ runtimePolicyEvidenceExpected payload
  , "observed: " ++ runtimePolicyEvidenceObserved payload
  , "artifact: " ++ runtimePolicyEvidenceArtifact payload
  ]

renderRuntimePolicyEvidenceStatus :: RuntimePolicyEvidenceStatus -> String
renderRuntimePolicyEvidenceStatus RuntimePolicyEvidencePassed =
  "passed"
renderRuntimePolicyEvidenceStatus RuntimePolicyEvidenceFailed =
  "failed"

renderRuntimePolicyEvidencePayloadsJson :: [RuntimePolicyEvidencePayload] -> String
renderRuntimePolicyEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "runtime-policy-evidence.v1")
    , jsonField "status" (jsonString statusText)
    , jsonField "payloads" (jsonArray (map runtimePolicyEvidencePayloadJson payloads))
    ]
  where
    statusText =
      if all runtimePolicyEvidencePayloadPassed payloads
        then "passed"
        else "failed"

runtimePolicyEvidenceSpecs :: [RuntimePolicyEvidenceSpec]
runtimePolicyEvidenceSpecs =
  [ RuntimePolicyEvidenceSpec
      "runtime-policy-error-dispatch"
      RuntimeErrorDispatchValidatedFact
      RuntimeErrorDispatchArtifact
      "runtime error dispatch policy fact and artifact are present"
  , RuntimePolicyEvidenceSpec
      "runtime-policy-retry"
      RuntimeRetryPolicyValidatedFact
      RuntimeRetryPolicyArtifact
      "runtime retry policy fact and artifact are present"
  , RuntimePolicyEvidenceSpec
      "runtime-policy-idempotency"
      RuntimeIdempotencyPolicyValidatedFact
      RuntimeIdempotencyPolicyArtifact
      "runtime idempotency policy fact and artifact are present"
  ]

runtimePolicyEvidencePayload :: RuntimePolicyEvidenceSpec -> FrameworkCoreReport -> RuntimePolicyEvidencePayload
runtimePolicyEvidencePayload spec report =
  RuntimePolicyEvidencePayload
    { runtimePolicyEvidenceClaim = runtimePolicyEvidenceSpecClaim spec
    , runtimePolicyEvidenceStatus = status
    , runtimePolicyEvidenceExpected = runtimePolicyEvidenceSpecExpected spec
    , runtimePolicyEvidenceObserved = observed
    , runtimePolicyEvidenceArtifact = show (runtimePolicyEvidenceSpecArtifact spec)
    }
  where
    factPresent =
      runtimePolicyEvidenceSpecFact spec `elem` factClosureFinalRuntimeFacts (frameworkCoreReportFactClosure report)
    artifactPresent =
      any ((== runtimePolicyEvidenceSpecArtifact spec) . artifactType) (frameworkCoreReportArtifacts report)
    status =
      if factPresent && artifactPresent
        then RuntimePolicyEvidencePassed
        else RuntimePolicyEvidenceFailed
    observed =
      case (factPresent, artifactPresent) of
        (True, True) ->
          "fact and artifact present"
        (False, True) ->
          "missing fact: " ++ show (runtimePolicyEvidenceSpecFact spec)
        (True, False) ->
          "missing artifact: " ++ show (runtimePolicyEvidenceSpecArtifact spec)
        (False, False) ->
          "missing fact: " ++ show (runtimePolicyEvidenceSpecFact spec)
            ++ "; missing artifact: "
            ++ show (runtimePolicyEvidenceSpecArtifact spec)

runtimePolicyEvidencePayloadJson :: RuntimePolicyEvidencePayload -> String
runtimePolicyEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (runtimePolicyEvidenceClaim payload))
    , jsonField "status" (jsonString (renderRuntimePolicyEvidenceStatus (runtimePolicyEvidenceStatus payload)))
    , jsonField "expected" (jsonString (runtimePolicyEvidenceExpected payload))
    , jsonField "observed" (jsonString (runtimePolicyEvidenceObserved payload))
    , jsonField "artifact" (jsonString (runtimePolicyEvidenceArtifact payload))
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
