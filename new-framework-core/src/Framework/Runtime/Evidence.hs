{-# LANGUAGE PatternSynonyms #-}

module Framework.Runtime.Evidence
  ( RuntimeEvidencePayload (..)
  , RuntimeEvidenceStatus (..)
  , renderRuntimeEvidencePayload
  , renderRuntimeEvidencePayloadsJson
  , renderRuntimeEvidenceStatus
  , runtimeEvidenceArtifactSummary
  , runtimeEvidenceClaimNames
  , runtimeEvidencePayloadPassed
  , runtimeEvidencePayloads
  ) where

import Bootstrap.Report
  ( FactClosureReport (..)
  , FrameworkCoreReport (..)
  )
import Bootstrap.Runtime
  ( RuntimeArtifact (..)
  )
import Bootstrap.Vocabulary
  ( pattern RuntimeBackendParityEvidenceArtifact
  , pattern RuntimeBackendParityEvidencePassedFact
  , pattern RuntimeConcurrencyEvidenceArtifact
  , pattern RuntimeConcurrencyEvidencePassedFact
  , pattern RuntimeDiagnosisEvidenceArtifact
  , pattern RuntimeDiagnosisEvidencePassedFact
  , pattern RuntimeExecutionEvidenceArtifact
  , pattern RuntimeExecutionEvidencePassedFact
  , pattern RuntimePlanBuildEvidenceArtifact
  , pattern RuntimePlanBuildEvidencePassedFact
  , pattern RuntimeValidationEvidenceArtifact
  , pattern RuntimeValidationEvidencePassedFact
  )
import Bootstrap.Effect
  ( TypeName )
import Bootstrap.Workflow
  ( WorkflowFact )

data RuntimeEvidencePayload = RuntimeEvidencePayload
  { runtimeEvidenceClaim :: String
  , runtimeEvidenceStatus :: RuntimeEvidenceStatus
  , runtimeEvidenceExpected :: String
  , runtimeEvidenceObserved :: String
  , runtimeEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data RuntimeEvidenceStatus
  = RuntimeEvidencePassed
  | RuntimeEvidenceFailed
  deriving (Eq, Show)

data RuntimeEvidenceSpec = RuntimeEvidenceSpec
  { runtimeEvidenceSpecClaim :: String
  , runtimeEvidenceSpecFact :: WorkflowFact
  , runtimeEvidenceSpecArtifact :: TypeName
  , runtimeEvidenceSpecExpected :: String
  }

runtimeEvidencePayloads :: FrameworkCoreReport -> [RuntimeEvidencePayload]
runtimeEvidencePayloads report =
  map (`runtimeEvidencePayload` report) runtimeEvidenceSpecs

runtimeEvidenceClaimNames :: [String]
runtimeEvidenceClaimNames =
  map runtimeEvidenceSpecClaim runtimeEvidenceSpecs

runtimeEvidenceArtifactSummary :: String
runtimeEvidenceArtifactSummary =
  "runtime evidence payload claims: "
    ++ joinWith ", " runtimeEvidenceClaimNames

runtimeEvidencePayloadPassed :: RuntimeEvidencePayload -> Bool
runtimeEvidencePayloadPassed payload =
  runtimeEvidenceStatus payload == RuntimeEvidencePassed

renderRuntimeEvidencePayload :: RuntimeEvidencePayload -> [String]
renderRuntimeEvidencePayload payload =
  [ "claim: " ++ runtimeEvidenceClaim payload
  , "status: " ++ renderRuntimeEvidenceStatus (runtimeEvidenceStatus payload)
  , "expected: " ++ runtimeEvidenceExpected payload
  , "observed: " ++ runtimeEvidenceObserved payload
  , "artifact: " ++ runtimeEvidenceArtifact payload
  ]

renderRuntimeEvidenceStatus :: RuntimeEvidenceStatus -> String
renderRuntimeEvidenceStatus RuntimeEvidencePassed =
  "passed"
renderRuntimeEvidenceStatus RuntimeEvidenceFailed =
  "failed"

renderRuntimeEvidencePayloadsJson :: [RuntimeEvidencePayload] -> String
renderRuntimeEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "runtime-evidence.v1")
    , jsonField "status" (jsonString statusText)
    , jsonField "payloads" (jsonArray (map runtimeEvidencePayloadJson payloads))
    ]
  where
    statusText =
      if all runtimeEvidencePayloadPassed payloads
        then "passed"
        else "failed"

runtimeEvidenceSpecs :: [RuntimeEvidenceSpec]
runtimeEvidenceSpecs =
  [ RuntimeEvidenceSpec
      "runtime-plan-build-evidence"
      RuntimePlanBuildEvidencePassedFact
      RuntimePlanBuildEvidenceArtifact
      "runtime plan build evidence fact and artifact are present"
  , RuntimeEvidenceSpec
      "runtime-validation-evidence"
      RuntimeValidationEvidencePassedFact
      RuntimeValidationEvidenceArtifact
      "runtime validation evidence fact and artifact are present"
  , RuntimeEvidenceSpec
      "runtime-execution-evidence"
      RuntimeExecutionEvidencePassedFact
      RuntimeExecutionEvidenceArtifact
      "runtime execution evidence fact and artifact are present"
  , RuntimeEvidenceSpec
      "runtime-concurrency-evidence"
      RuntimeConcurrencyEvidencePassedFact
      RuntimeConcurrencyEvidenceArtifact
      "runtime concurrency evidence fact and artifact are present"
  , RuntimeEvidenceSpec
      "runtime-diagnosis-evidence"
      RuntimeDiagnosisEvidencePassedFact
      RuntimeDiagnosisEvidenceArtifact
      "runtime diagnosis evidence fact and artifact are present"
  , RuntimeEvidenceSpec
      "runtime-backend-parity-evidence"
      RuntimeBackendParityEvidencePassedFact
      RuntimeBackendParityEvidenceArtifact
      "runtime backend parity evidence fact and artifact are present"
  ]

runtimeEvidencePayload :: RuntimeEvidenceSpec -> FrameworkCoreReport -> RuntimeEvidencePayload
runtimeEvidencePayload spec report =
  RuntimeEvidencePayload
    { runtimeEvidenceClaim = runtimeEvidenceSpecClaim spec
    , runtimeEvidenceStatus = status
    , runtimeEvidenceExpected = runtimeEvidenceSpecExpected spec
    , runtimeEvidenceObserved = observed
    , runtimeEvidenceArtifact = show (runtimeEvidenceSpecArtifact spec)
    }
  where
    factPresent =
      runtimeEvidenceSpecFact spec `elem` factClosureFinalRuntimeFacts (frameworkCoreReportFactClosure report)
    artifactPresent =
      any ((== runtimeEvidenceSpecArtifact spec) . artifactType) (frameworkCoreReportArtifacts report)
    status =
      if factPresent && artifactPresent
        then RuntimeEvidencePassed
        else RuntimeEvidenceFailed
    observed =
      case (factPresent, artifactPresent) of
        (True, True) ->
          "fact and artifact present"
        (False, True) ->
          "missing fact: " ++ show (runtimeEvidenceSpecFact spec)
        (True, False) ->
          "missing artifact: " ++ show (runtimeEvidenceSpecArtifact spec)
        (False, False) ->
          "missing fact: " ++ show (runtimeEvidenceSpecFact spec)
            ++ "; missing artifact: "
            ++ show (runtimeEvidenceSpecArtifact spec)

runtimeEvidencePayloadJson :: RuntimeEvidencePayload -> String
runtimeEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (runtimeEvidenceClaim payload))
    , jsonField "status" (jsonString (renderRuntimeEvidenceStatus (runtimeEvidenceStatus payload)))
    , jsonField "expected" (jsonString (runtimeEvidenceExpected payload))
    , jsonField "observed" (jsonString (runtimeEvidenceObserved payload))
    , jsonField "artifact" (jsonString (runtimeEvidenceArtifact payload))
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
