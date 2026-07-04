module Framework.Runtime.Concurrency
  ( RuntimeConcurrencyEvidencePayload (..)
  , RuntimeConcurrencyEvidenceStatus (..)
  , renderRuntimeConcurrencyEvidencePayload
  , renderRuntimeConcurrencyEvidencePayloadsJson
  , renderRuntimeConcurrencyEvidenceStatus
  , runtimeConcurrencyEvidenceArtifactSummary
  , runtimeConcurrencyEvidenceClaimNames
  , runtimeConcurrencyEvidencePayloadPassed
  , runtimeConcurrencyEvidencePayloads
  ) where

import Framework.Workflow.Semantics
  ( WorkflowSemanticsEvidencePayload (..)
  , workflowSemanticsEvidencePayloadPassed
  )

data RuntimeConcurrencyEvidencePayload = RuntimeConcurrencyEvidencePayload
  { runtimeConcurrencyEvidenceClaim :: String
  , runtimeConcurrencyEvidenceStatus :: RuntimeConcurrencyEvidenceStatus
  , runtimeConcurrencyEvidenceExpected :: String
  , runtimeConcurrencyEvidenceObserved :: String
  , runtimeConcurrencyEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data RuntimeConcurrencyEvidenceStatus
  = RuntimeConcurrencyEvidencePassed
  | RuntimeConcurrencyEvidenceFailed
  deriving (Eq, Show)

data RuntimeConcurrencyClaimLink = RuntimeConcurrencyClaimLink
  { runtimeConcurrencyClaimName :: String
  , runtimeConcurrencyClaimWorkflowClaim :: String
  , runtimeConcurrencyClaimExpected :: String
  , runtimeConcurrencyClaimArtifact :: String
  }

runtimeConcurrencyEvidencePayloads :: [WorkflowSemanticsEvidencePayload] -> [RuntimeConcurrencyEvidencePayload]
runtimeConcurrencyEvidencePayloads workflowPayloads =
  map (runtimeConcurrencyEvidencePayload workflowPayloads) runtimeConcurrencyClaimLinks

runtimeConcurrencyEvidencePayloadPassed :: RuntimeConcurrencyEvidencePayload -> Bool
runtimeConcurrencyEvidencePayloadPassed payload =
  runtimeConcurrencyEvidenceStatus payload == RuntimeConcurrencyEvidencePassed

renderRuntimeConcurrencyEvidencePayload :: RuntimeConcurrencyEvidencePayload -> [String]
renderRuntimeConcurrencyEvidencePayload payload =
  [ "claim: " ++ runtimeConcurrencyEvidenceClaim payload
  , "status: " ++ renderRuntimeConcurrencyEvidenceStatus (runtimeConcurrencyEvidenceStatus payload)
  , "expected: " ++ runtimeConcurrencyEvidenceExpected payload
  , "observed: " ++ runtimeConcurrencyEvidenceObserved payload
  , "artifact: " ++ runtimeConcurrencyEvidenceArtifact payload
  ]

renderRuntimeConcurrencyEvidenceStatus :: RuntimeConcurrencyEvidenceStatus -> String
renderRuntimeConcurrencyEvidenceStatus RuntimeConcurrencyEvidencePassed =
  "passed"
renderRuntimeConcurrencyEvidenceStatus RuntimeConcurrencyEvidenceFailed =
  "failed"

renderRuntimeConcurrencyEvidencePayloadsJson :: [RuntimeConcurrencyEvidencePayload] -> String
renderRuntimeConcurrencyEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "runtime-concurrency-evidence.v1")
    , jsonField "status" (jsonString statusText)
    , jsonField "payloads" (jsonArray (map runtimeConcurrencyEvidencePayloadJson payloads))
    ]
  where
    statusText =
      if all runtimeConcurrencyEvidencePayloadPassed payloads
        then "passed"
        else "failed"

runtimeConcurrencyEvidenceArtifactSummary :: String
runtimeConcurrencyEvidenceArtifactSummary =
  "runtime concurrency evidence payload claims: "
    ++ joinWith ", " runtimeConcurrencyEvidenceClaimNames

runtimeConcurrencyEvidenceClaimNames :: [String]
runtimeConcurrencyEvidenceClaimNames =
  map runtimeConcurrencyClaimName runtimeConcurrencyClaimLinks

runtimeConcurrencyClaimLinks :: [RuntimeConcurrencyClaimLink]
runtimeConcurrencyClaimLinks =
  [ RuntimeConcurrencyClaimLink
      "runtime-concurrency-parallel-branches"
      "workflow-parallel-concurrency"
      "parallel branches run concurrently and merge independent facts"
      "RuntimeConcurrencyParallelBranchesArtifact"
  , RuntimeConcurrencyClaimLink
      "runtime-concurrency-parallel-merge-conflict"
      "workflow-parallel-conflict"
      "parallel merge rejects conflicting writes to the same runtime value type"
      "RuntimeConcurrencyParallelMergeConflictArtifact"
  , RuntimeConcurrencyClaimLink
      "runtime-concurrency-race-cancellation"
      "workflow-race-cancellation"
      "race keeps the winning branch and excludes loser facts"
      "RuntimeConcurrencyRaceCancellationArtifact"
  , RuntimeConcurrencyClaimLink
      "runtime-concurrency-race-exhausted"
      "workflow-race-exhausted"
      "race reports exhaustion when every branch fails"
      "RuntimeConcurrencyRaceExhaustedArtifact"
  ]

runtimeConcurrencyEvidencePayload ::
  [WorkflowSemanticsEvidencePayload] ->
  RuntimeConcurrencyClaimLink ->
  RuntimeConcurrencyEvidencePayload
runtimeConcurrencyEvidencePayload workflowPayloads claimLink =
  case workflowPayloadFor (runtimeConcurrencyClaimWorkflowClaim claimLink) workflowPayloads of
    Just workflowPayload ->
      RuntimeConcurrencyEvidencePayload
        { runtimeConcurrencyEvidenceClaim = runtimeConcurrencyClaimName claimLink
        , runtimeConcurrencyEvidenceStatus =
            if workflowSemanticsEvidencePayloadPassed workflowPayload
              then RuntimeConcurrencyEvidencePassed
              else RuntimeConcurrencyEvidenceFailed
        , runtimeConcurrencyEvidenceExpected = runtimeConcurrencyClaimExpected claimLink
        , runtimeConcurrencyEvidenceObserved = workflowSemanticsEvidenceObserved workflowPayload
        , runtimeConcurrencyEvidenceArtifact = runtimeConcurrencyClaimArtifact claimLink
        }
    Nothing ->
      RuntimeConcurrencyEvidencePayload
        { runtimeConcurrencyEvidenceClaim = runtimeConcurrencyClaimName claimLink
        , runtimeConcurrencyEvidenceStatus = RuntimeConcurrencyEvidenceFailed
        , runtimeConcurrencyEvidenceExpected = runtimeConcurrencyClaimExpected claimLink
        , runtimeConcurrencyEvidenceObserved =
            "missing workflow semantics payload: " ++ runtimeConcurrencyClaimWorkflowClaim claimLink
        , runtimeConcurrencyEvidenceArtifact = runtimeConcurrencyClaimArtifact claimLink
        }

workflowPayloadFor :: String -> [WorkflowSemanticsEvidencePayload] -> Maybe WorkflowSemanticsEvidencePayload
workflowPayloadFor _ [] =
  Nothing
workflowPayloadFor claimName (payload : rest)
  | workflowSemanticsEvidenceClaim payload == claimName =
      Just payload
  | otherwise =
      workflowPayloadFor claimName rest

runtimeConcurrencyEvidencePayloadJson :: RuntimeConcurrencyEvidencePayload -> String
runtimeConcurrencyEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (runtimeConcurrencyEvidenceClaim payload))
    , jsonField "status" (jsonString (renderRuntimeConcurrencyEvidenceStatus (runtimeConcurrencyEvidenceStatus payload)))
    , jsonField "expected" (jsonString (runtimeConcurrencyEvidenceExpected payload))
    , jsonField "observed" (jsonString (runtimeConcurrencyEvidenceObserved payload))
    , jsonField "artifact" (jsonString (runtimeConcurrencyEvidenceArtifact payload))
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
