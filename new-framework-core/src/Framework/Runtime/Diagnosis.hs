{-# LANGUAGE PatternSynonyms #-}

module Framework.Runtime.Diagnosis
  ( RuntimeFailureDiagnosis (..)
  , RuntimeDiagnosisEvidencePayload (..)
  , RuntimeDiagnosisEvidenceStatus (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisNodeKind (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeDiagnosisRootCause (..)
  , RuntimeDiagnosisStep (..)
  , RuntimeDiagnosisBlocker (..)
  , buildFailureDiagnosis
  , buildFailureDiagnosisWithSystem
  , completeDiagnosisProbe
  , diagnosisProbePairs
  , renderRuntimeDiagnosisEvidencePayload
  , renderRuntimeDiagnosisEvidencePayloadsJson
  , renderRuntimeDiagnosisEvidenceStatus
  , recordRuntimeDiagnosis
  , runtimeDiagnosisEvidenceArtifactSummary
  , runtimeDiagnosisEvidenceClaimNames
  , runtimeDiagnosisEvidencePayloadPassed
  , renderRuntimeFailureDiagnosis
  ) where

import Bootstrap.Effect
  ( IdempotencyPolicy (..)
  , SendName
  , TypeName
  , pattern NoInput
  , pattern Unit
  )
import Bootstrap.Runtime
  ( NativeAppPlan (..)
  , NativeFactRule (..)
  , SendContract (..)
  )
import Bootstrap.Workflow
  ( EffectSystemName
  , WorkflowFact
  )
import Framework.Runtime.Types
  ( Runtime (..)
  , RuntimeDiagnosisBlocker (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisNodeKind (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeDiagnosisRootCause (..)
  , RuntimeDiagnosisStep (..)
  , RuntimeFactClaim (..)
  , RuntimeFactStatus
  , RuntimeFailureDiagnosis (..)
  )

buildFailureDiagnosis ::
  NativeAppPlan ->
  Runtime ->
  WorkflowFact ->
  Maybe SendName ->
  String ->
  RuntimeFailureDiagnosis
buildFailureDiagnosis plan runtime rootFact rootSend rootError =
  buildFailureDiagnosisWithSystem
    plan
    runtime
    Nothing
    rootFact
    Nothing
    (DiagnosisUnknownRootCause rootError)
    rootSend
    rootError

buildFailureDiagnosisWithSystem ::
  NativeAppPlan ->
  Runtime ->
  Maybe EffectSystemName ->
  WorkflowFact ->
  Maybe RuntimeDiagnosisStep ->
  RuntimeDiagnosisRootCause ->
  Maybe SendName ->
  String ->
  RuntimeFailureDiagnosis
buildFailureDiagnosisWithSystem plan runtime rootSystem rootFact rootStep rootCause rootSend rootError =
  RuntimeFailureDiagnosis
    { diagnosisRootSystem = rootSystem
    , diagnosisRootFact = rootFact
    , diagnosisPipelineStep = rootStep
    , diagnosisRootCause = rootCause
    , diagnosisRootSend = rootSend
    , diagnosisRootError = rootError
    , diagnosisNodes = nodes
    , diagnosisProbes =
        [ RuntimeDiagnosisProbe currentFact currentSend DiagnosisProbePending
        | currentNode <- nodes
        , currentSend <- diagnosisNodeIdempotentSends currentNode
        , let currentFact = diagnosisNodeFact currentNode
        ]
    , diagnosisSuspects = diagnosisSuspectFacts nodes rootFact
    , diagnosisPollutedFacts = downstreamFacts plan runtime rootFact
    }
  where
    nodes =
      diagnosisNodesFrom plan runtime [] [SearchItem rootFact DiagnosisRoot]

data SearchItem = SearchItem WorkflowFact RuntimeDiagnosisNodeKind

diagnosisNodesFrom ::
  NativeAppPlan ->
  Runtime ->
  [WorkflowFact] ->
  [SearchItem] ->
  [RuntimeDiagnosisNode]
diagnosisNodesFrom _ _ _ [] =
  []
diagnosisNodesFrom plan runtime seen (SearchItem currentFact currentKind : rest)
  | currentFact `elem` seen =
      diagnosisNodesFrom plan runtime seen rest
  | otherwise =
      currentNode : diagnosisNodesFrom plan runtime (currentFact : seen) (rest ++ upstreamItems)
  where
    currentNode =
      diagnosisNodeFor plan runtime currentFact currentKind
    upstreamItems =
      case nativeRuleFor plan currentFact of
        Nothing ->
          []
        Just currentRule ->
          [ SearchItem neededFact (DiagnosisNeedsUpstream currentFact)
          | neededFact <- nativeRuleNeeds currentRule
          ]
            ++ [ SearchItem sourceFact (DiagnosisPipeUpstream currentFact currentType)
               | currentType <- filter runtimePipeDependencyType (nativeRuleTakes currentRule)
               , sourceFact <- sourceFactsForType plan currentType
               ]

diagnosisNodeFor ::
  NativeAppPlan ->
  Runtime ->
  WorkflowFact ->
  RuntimeDiagnosisNodeKind ->
  RuntimeDiagnosisNode
diagnosisNodeFor plan runtime currentFact currentKind =
  RuntimeDiagnosisNode
    { diagnosisNodeFact = currentFact
    , diagnosisNodeKind = currentKind
    , diagnosisNodeStatus = factStatus runtime currentFact
    , diagnosisNodeExternalMakes = sends
    , diagnosisNodeIdempotentSends = idempotentSends
    , diagnosisNodeNonIdempotentSends = nonIdempotentSends
    , diagnosisNodeBlockers = blockers
    }
  where
    currentRule =
      nativeRuleFor plan currentFact
    sends =
      maybe [] nativeRuleUses currentRule
    idempotentSends =
      [ currentSend
      | currentSend <- sends
      , sendIsIdempotent plan currentSend
      ]
    nonIdempotentSends =
      [ currentSend
      | currentSend <- sends
      , not (sendIsIdempotent plan currentSend)
      ]
    blockers =
      missingRuleBlocker currentRule
        ++ externalTakeBlocker currentRule
        ++ map DiagnosisNonIdempotentSend nonIdempotentSends

missingRuleBlocker :: Maybe NativeFactRule -> [RuntimeDiagnosisBlocker]
missingRuleBlocker Nothing =
  [DiagnosisMissingRule]
missingRuleBlocker (Just _) =
  []

externalTakeBlocker :: Maybe NativeFactRule -> [RuntimeDiagnosisBlocker]
externalTakeBlocker (Just currentRule)
  | nativeRuleExternal currentRule =
      [DiagnosisExternalTakeSource]
externalTakeBlocker _ =
  []

sendIsIdempotent :: NativeAppPlan -> SendName -> Bool
sendIsIdempotent plan currentSend =
  case sendContractFor plan currentSend of
    Just currentContract ->
      sendContractIdempotency currentContract == Idempotent
    Nothing ->
      False

diagnosisSuspectFacts :: [RuntimeDiagnosisNode] -> WorkflowFact -> [WorkflowFact]
diagnosisSuspectFacts nodes rootFact =
  unique
    ( rootFact
        : [ diagnosisNodeFact currentNode
          | currentNode <- nodes
          , nodeIsSuspect currentNode
          ]
    )

nodeIsSuspect :: RuntimeDiagnosisNode -> Bool
nodeIsSuspect currentNode =
  not (null (diagnosisNodeIdempotentSends currentNode))
    || any isNonIdempotentBlocker (diagnosisNodeBlockers currentNode)
    || DiagnosisMissingRule `elem` diagnosisNodeBlockers currentNode
    || DiagnosisExternalTakeSource `elem` diagnosisNodeBlockers currentNode
    || ( null (diagnosisNodeExternalMakes currentNode)
          && null (diagnosisNodeBlockers currentNode)
       )

isNonIdempotentBlocker :: RuntimeDiagnosisBlocker -> Bool
isNonIdempotentBlocker (DiagnosisNonIdempotentSend _) =
  True
isNonIdempotentBlocker _ =
  False

downstreamFacts :: NativeAppPlan -> Runtime -> WorkflowFact -> [WorkflowFact]
downstreamFacts plan runtime rootFact =
  downstreamFactsFrom plan runtime [] [rootFact]

downstreamFactsFrom ::
  NativeAppPlan ->
  Runtime ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  [WorkflowFact]
downstreamFactsFrom _ _ seen [] =
  seen
downstreamFactsFrom plan runtime seen (currentFact : rest) =
  downstreamFactsFrom plan runtime nextSeen (rest ++ nextFacts)
  where
    nextFacts =
      [ dependentFact
      | currentRule <- nativeAppPlanFactRules plan
      , currentFact `ruleDependsOnFact` (plan, currentRule)
      , let dependentFact = nativeRuleFact currentRule
      , dependentFact `elem` claimedFacts runtime
      , dependentFact `notElem` seen
      ]
    nextSeen =
      unique (seen ++ nextFacts)

ruleDependsOnFact :: WorkflowFact -> (NativeAppPlan, NativeFactRule) -> Bool
ruleDependsOnFact currentFact (plan, currentRule) =
  currentFact `elem` nativeRuleNeeds currentRule
    || any factMakesTakenType (nativeRuleTakes currentRule)
  where
    factMakesTakenType currentType =
      currentFact `elem` sourceFactsForType plan currentType

claimedFacts :: Runtime -> [WorkflowFact]
claimedFacts runtime =
  [ runtimeFactClaimFact currentClaim
  | currentClaim <- runtimeFactClaims runtime
  ]

factStatus :: Runtime -> WorkflowFact -> Maybe RuntimeFactStatus
factStatus runtime currentFact =
  runtimeFactClaimStatus
    <$> firstJust
      [ Just currentClaim
      | currentClaim <- runtimeFactClaims runtime
      , runtimeFactClaimFact currentClaim == currentFact
      ]

diagnosisProbePairs :: RuntimeFailureDiagnosis -> [(WorkflowFact, SendName)]
diagnosisProbePairs diagnosis =
  [ (diagnosisProbeFact currentProbe, diagnosisProbeSend currentProbe)
  | currentProbe <- diagnosisProbes diagnosis
  , diagnosisProbeStatus currentProbe == DiagnosisProbePending
  ]

completeDiagnosisProbe ::
  WorkflowFact ->
  SendName ->
  RuntimeDiagnosisProbeStatus ->
  RuntimeFailureDiagnosis ->
  RuntimeFailureDiagnosis
completeDiagnosisProbe currentFact currentSend currentStatus diagnosis =
  diagnosis
    { diagnosisProbes =
        map completeProbe (diagnosisProbes diagnosis)
    }
  where
    completeProbe currentProbe
      | diagnosisProbeFact currentProbe == currentFact
          && diagnosisProbeSend currentProbe == currentSend =
          currentProbe {diagnosisProbeStatus = currentStatus}
      | otherwise =
          currentProbe

recordRuntimeDiagnosis :: RuntimeFailureDiagnosis -> Runtime -> Runtime
recordRuntimeDiagnosis diagnosis runtime =
  runtime
    { runtimeFailureDiagnoses =
        runtimeFailureDiagnoses runtime ++ [diagnosis]
    }

renderRuntimeFailureDiagnosis :: RuntimeFailureDiagnosis -> String
renderRuntimeFailureDiagnosis diagnosis =
  unwords
    [ "diagnosis system"
    , renderRootSystem (diagnosisRootSystem diagnosis)
    , "step"
    , renderDiagnosisStep (diagnosisPipelineStep diagnosis)
    , "cause"
    , renderDiagnosisRootCause (diagnosisRootCause diagnosis)
    , "root"
    , show (diagnosisRootFact diagnosis)
    , renderRootSend (diagnosisRootSend diagnosis)
    , "error"
    , show (diagnosisRootError diagnosis)
    , "suspects"
    , show (diagnosisSuspects diagnosis)
    , "probes"
    , show (diagnosisProbes diagnosis)
    , "blocked"
    , show (blockedNodes (diagnosisNodes diagnosis))
    , "polluted"
    , show (diagnosisPollutedFacts diagnosis)
    ]

renderRootSystem :: Maybe EffectSystemName -> String
renderRootSystem Nothing =
  "unknown"
renderRootSystem (Just name) =
  show name

renderDiagnosisStep :: Maybe RuntimeDiagnosisStep -> String
renderDiagnosisStep Nothing =
  "unknown"
renderDiagnosisStep (Just step) =
  case step of
    DiagnosisFactStep fact ->
      "fact " ++ show fact
    DiagnosisSendStep currentSend ->
      "send " ++ show currentSend
    DiagnosisTransformStep transformName ->
      "transform " ++ transformName

renderDiagnosisRootCause :: RuntimeDiagnosisRootCause -> String
renderDiagnosisRootCause cause =
  case cause of
    DiagnosisMissingFactRuleCause fact ->
      "missing fact rule " ++ show fact
    DiagnosisMissingSendBoundaryCause currentSend ->
      "missing send boundary " ++ show currentSend
    DiagnosisMissingHandlerCause currentSend ->
      "missing handler " ++ show currentSend
    DiagnosisMissingHandlerInputCause currentSend currentType ->
      "missing handler input " ++ show currentSend ++ " " ++ show currentType
    DiagnosisHandlerOutputMismatchCause currentSend expected actual ->
      "handler output mismatch " ++ show currentSend ++ " expected " ++ show expected ++ " actual " ++ show actual
    DiagnosisHandlerFailedCause currentSend message ->
      "handler failed " ++ show currentSend ++ " " ++ show message
    DiagnosisMissingTransformCause transformName ->
      "missing transform " ++ transformName
    DiagnosisMissingTransformInputCause transformName currentType ->
      "missing transform input " ++ transformName ++ " " ++ show currentType
    DiagnosisTransformMismatchCause transformName ->
      "transform mismatch " ++ transformName
    DiagnosisDependencyFailedCause fact ->
      "dependency failed " ++ show fact
    DiagnosisWaitBlockedCause message ->
      "wait blocked " ++ show message
    DiagnosisChoiceMissingBranchCause message ->
      "choice missing branch " ++ show message
    DiagnosisParallelBranchFailedCause index ->
      "parallel branch failed " ++ show index
    DiagnosisParallelMergeConflictCause message ->
      "parallel merge conflict " ++ show message
    DiagnosisFallbackExhaustedCause ->
      "fallback exhausted"
    DiagnosisRaceExhaustedCause ->
      "race exhausted"
    DiagnosisLoopExceededCause count ->
      "loop exceeded " ++ show count
    DiagnosisIoExceptionCause message ->
      "io exception " ++ show message
    DiagnosisUnknownRootCause message ->
      "unknown " ++ show message

renderRootSend :: Maybe SendName -> String
renderRootSend Nothing =
  "local"
renderRootSend (Just currentSend) =
  "send " ++ show currentSend

blockedNodes :: [RuntimeDiagnosisNode] -> [(WorkflowFact, [RuntimeDiagnosisBlocker])]
blockedNodes nodes =
  [ (diagnosisNodeFact currentNode, diagnosisNodeBlockers currentNode)
  | currentNode <- nodes
  , not (null (diagnosisNodeBlockers currentNode))
  ]

data RuntimeDiagnosisEvidencePayload = RuntimeDiagnosisEvidencePayload
  { runtimeDiagnosisEvidenceClaim :: String
  , runtimeDiagnosisEvidenceStatus :: RuntimeDiagnosisEvidenceStatus
  , runtimeDiagnosisEvidenceExpected :: String
  , runtimeDiagnosisEvidenceObserved :: String
  , runtimeDiagnosisEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data RuntimeDiagnosisEvidenceStatus
  = RuntimeDiagnosisEvidencePassed
  | RuntimeDiagnosisEvidenceFailed
  deriving (Eq, Show)

runtimeDiagnosisEvidencePayloadPassed :: RuntimeDiagnosisEvidencePayload -> Bool
runtimeDiagnosisEvidencePayloadPassed payload =
  runtimeDiagnosisEvidenceStatus payload == RuntimeDiagnosisEvidencePassed

runtimeDiagnosisEvidenceClaimNames :: [String]
runtimeDiagnosisEvidenceClaimNames =
  [ "runtime-diagnosis-error-handler"
  , "runtime-diagnosis-retry-probe"
  , "runtime-diagnosis-non-idempotent-blocker"
  , "runtime-diagnosis-system-root-cause"
  ]

runtimeDiagnosisEvidenceArtifactSummary :: String
runtimeDiagnosisEvidenceArtifactSummary =
  "runtime diagnosis evidence payload claims: "
    ++ joinWith ", " runtimeDiagnosisEvidenceClaimNames

renderRuntimeDiagnosisEvidencePayload :: RuntimeDiagnosisEvidencePayload -> [String]
renderRuntimeDiagnosisEvidencePayload payload =
  [ "claim: " ++ runtimeDiagnosisEvidenceClaim payload
  , "status: " ++ renderRuntimeDiagnosisEvidenceStatus (runtimeDiagnosisEvidenceStatus payload)
  , "expected: " ++ runtimeDiagnosisEvidenceExpected payload
  , "observed: " ++ runtimeDiagnosisEvidenceObserved payload
  , "artifact: " ++ runtimeDiagnosisEvidenceArtifact payload
  ]

renderRuntimeDiagnosisEvidenceStatus :: RuntimeDiagnosisEvidenceStatus -> String
renderRuntimeDiagnosisEvidenceStatus RuntimeDiagnosisEvidencePassed =
  "passed"
renderRuntimeDiagnosisEvidenceStatus RuntimeDiagnosisEvidenceFailed =
  "failed"

renderRuntimeDiagnosisEvidencePayloadsJson :: [RuntimeDiagnosisEvidencePayload] -> String
renderRuntimeDiagnosisEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "runtime-diagnosis-evidence.v1")
    , jsonField "status" (jsonString statusText)
    , jsonField "payloads" (jsonArray (map runtimeDiagnosisEvidencePayloadJson payloads))
    ]
  where
    statusText =
      if all runtimeDiagnosisEvidencePayloadPassed payloads
        then "passed"
        else "failed"

runtimeDiagnosisEvidencePayloadJson :: RuntimeDiagnosisEvidencePayload -> String
runtimeDiagnosisEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (runtimeDiagnosisEvidenceClaim payload))
    , jsonField "status" (jsonString (renderRuntimeDiagnosisEvidenceStatus (runtimeDiagnosisEvidenceStatus payload)))
    , jsonField "expected" (jsonString (runtimeDiagnosisEvidenceExpected payload))
    , jsonField "observed" (jsonString (runtimeDiagnosisEvidenceObserved payload))
    , jsonField "artifact" (jsonString (runtimeDiagnosisEvidenceArtifact payload))
    ]

nativeRuleFor :: NativeAppPlan -> WorkflowFact -> Maybe NativeFactRule
nativeRuleFor plan currentFact =
  firstJust
    [ Just rule
    | rule <- nativeAppPlanFactRules plan
    , nativeRuleFact rule == currentFact
    ]

sendContractFor :: NativeAppPlan -> SendName -> Maybe SendContract
sendContractFor plan currentSend =
  firstJust
    [ Just contract
    | contract <- nativeAppPlanSendContracts plan
    , sendContractName contract == currentSend
    ]

sourceFactsForType :: NativeAppPlan -> TypeName -> [WorkflowFact]
sourceFactsForType plan currentType =
  [ nativeRuleFact rule
  | rule <- nativeAppPlanFactRules plan
  , currentType `elem` nativeRuleMakes rule
  ]

runtimePipeDependencyType :: TypeName -> Bool
runtimePipeDependencyType NoInput =
  False
runtimePipeDependencyType Unit =
  False
runtimePipeDependencyType _ =
  True

unique :: Eq item => [item] -> [item]
unique =
  foldl appendUnique []

appendUnique :: Eq item => [item] -> item -> [item]
appendUnique items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest

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
