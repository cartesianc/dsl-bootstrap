module Framework.Workflow.Semantics
  ( WorkflowSemanticsEvidencePayload (..)
  , WorkflowSemanticsEvidenceStatus (..)
  , renderWorkflowSemanticsEvidencePayload
  , renderWorkflowSemanticsEvidencePayloadsJson
  , renderWorkflowSemanticsEvidenceStatus
  , workflowSemanticsCoreClaimNames
  , workflowSemanticsEvidenceClaimNames
  , workflowSemanticsEvidencePayloadPassed
  ) where

data WorkflowSemanticsEvidencePayload = WorkflowSemanticsEvidencePayload
  { workflowSemanticsEvidenceClaim :: String
  , workflowSemanticsEvidenceStatus :: WorkflowSemanticsEvidenceStatus
  , workflowSemanticsEvidenceExpected :: String
  , workflowSemanticsEvidenceObserved :: String
  , workflowSemanticsEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data WorkflowSemanticsEvidenceStatus
  = WorkflowSemanticsEvidencePassed
  | WorkflowSemanticsEvidenceFailed
  deriving (Eq, Show)

workflowSemanticsCoreClaimNames :: [String]
workflowSemanticsCoreClaimNames =
  [ "workflow-parallel-concurrency"
  , "workflow-parallel-conflict"
  , "workflow-race-cancellation"
  , "workflow-race-exhausted"
  , "workflow-fallback-isolation"
  , "workflow-choice-selected-branch"
  , "workflow-fact-any-fallback"
  , "workflow-loop-fixed-point"
  , "workflow-middleware-failure"
  , "workflow-suspense-snapshot"
  , "workflow-callback-failure"
  , "workflow-recursion-context"
  , "workflow-native-framework-alignment"
  , "workflow-effect-system-boundary"
  , "workflow-effect-system-scope"
  , "workflow-effect-system-contracts"
  , "workflow-effect-system-pipeline"
  ]

workflowSemanticsEvidenceClaimNames :: [String]
workflowSemanticsEvidenceClaimNames =
  workflowSemanticsCoreClaimNames ++ ["workflow-semantics-claim-manifest"]

workflowSemanticsEvidencePayloadPassed :: WorkflowSemanticsEvidencePayload -> Bool
workflowSemanticsEvidencePayloadPassed payload =
  workflowSemanticsEvidenceStatus payload == WorkflowSemanticsEvidencePassed

renderWorkflowSemanticsEvidencePayload :: WorkflowSemanticsEvidencePayload -> [String]
renderWorkflowSemanticsEvidencePayload payload =
  [ "claim: " ++ workflowSemanticsEvidenceClaim payload
  , "status: " ++ renderWorkflowSemanticsEvidenceStatus (workflowSemanticsEvidenceStatus payload)
  , "expected: " ++ workflowSemanticsEvidenceExpected payload
  , "observed: " ++ workflowSemanticsEvidenceObserved payload
  , "artifact: " ++ workflowSemanticsEvidenceArtifact payload
  ]

renderWorkflowSemanticsEvidenceStatus :: WorkflowSemanticsEvidenceStatus -> String
renderWorkflowSemanticsEvidenceStatus WorkflowSemanticsEvidencePassed =
  "passed"
renderWorkflowSemanticsEvidenceStatus WorkflowSemanticsEvidenceFailed =
  "failed"

renderWorkflowSemanticsEvidencePayloadsJson :: [WorkflowSemanticsEvidencePayload] -> String
renderWorkflowSemanticsEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "workflow-semantics-evidence.v1")
    , jsonField "status" (jsonString statusText)
    , jsonField "payloads" (jsonArray (map workflowSemanticsEvidencePayloadJson payloads))
    ]
  where
    statusText =
      if all workflowSemanticsEvidencePayloadPassed payloads
        then "passed"
        else "failed"

workflowSemanticsEvidencePayloadJson :: WorkflowSemanticsEvidencePayload -> String
workflowSemanticsEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (workflowSemanticsEvidenceClaim payload))
    , jsonField "status" (jsonString (renderWorkflowSemanticsEvidenceStatus (workflowSemanticsEvidenceStatus payload)))
    , jsonField "expected" (jsonString (workflowSemanticsEvidenceExpected payload))
    , jsonField "observed" (jsonString (workflowSemanticsEvidenceObserved payload))
    , jsonField "artifact" (jsonString (workflowSemanticsEvidenceArtifact payload))
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
