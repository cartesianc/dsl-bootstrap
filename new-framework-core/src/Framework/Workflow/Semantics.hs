module Framework.Workflow.Semantics
  ( WorkflowSemanticsEvidencePayload (..)
  , WorkflowSemanticsEvidenceStatus (..)
  , renderWorkflowSemanticsEvidencePayload
  , renderWorkflowSemanticsEvidencePayloadsJson
  , renderWorkflowSemanticsEvidenceStatus
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
