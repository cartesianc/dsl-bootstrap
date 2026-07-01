module Interpreter.Runtime.Diagnosis
  ( buildFailureDiagnosis
  , completeDiagnosisProbe
  , diagnosisProbePairs
  , recordRuntimeDiagnosis
  , renderRuntimeFailureDiagnosis
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Effect.Semantics
  ( EffectSemantics (..)
  , IdempotencyPolicy (..)
  , PipeTake (..)
  , SendContract (..)
  , TakeMakeRule (..)
  , TakeMakeSource (..)
  , sendContractFor
  , takeMakeRuleFor
  )
import Effects.Names
  ( SendName
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , RuntimeDiagnosisBlocker (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisNodeKind (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeFactClaim (..)
  , RuntimeFactStatus
  , RuntimeFailureDiagnosis (..)
  )

buildFailureDiagnosis ::
  EffectSemantics ->
  Runtime ->
  WorkflowFact ->
  Maybe SendName ->
  String ->
  RuntimeFailureDiagnosis
buildFailureDiagnosis semantics runtime rootFact rootSend rootError =
  RuntimeFailureDiagnosis
    { diagnosisRootFact = rootFact
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
    , diagnosisPollutedFacts = downstreamFacts semantics runtime rootFact
    }
  where
    nodes =
      diagnosisNodesFrom semantics runtime [] [SearchItem rootFact DiagnosisRoot]

data SearchItem = SearchItem WorkflowFact RuntimeDiagnosisNodeKind

diagnosisNodesFrom ::
  EffectSemantics ->
  Runtime ->
  [WorkflowFact] ->
  [SearchItem] ->
  [RuntimeDiagnosisNode]
diagnosisNodesFrom _ _ _ [] =
  []
diagnosisNodesFrom semantics runtime seen (SearchItem currentFact currentKind : rest)
  | currentFact `elem` seen =
      diagnosisNodesFrom semantics runtime seen rest
  | otherwise =
      currentNode : diagnosisNodesFrom semantics runtime (currentFact : seen) (rest ++ upstreamItems)
  where
    currentNode =
      diagnosisNodeFor semantics runtime currentFact currentKind
    upstreamItems =
      case takeMakeRuleFor semantics currentFact of
        Nothing ->
          []
        Just currentRule ->
          [ SearchItem neededFact (DiagnosisNeedsUpstream currentFact)
          | neededFact <- takeFacts currentRule
          ]
            ++ [ SearchItem
                  (pipeTakeFact currentPipeTake)
                  (DiagnosisPipeUpstream currentFact (pipeTakeInput currentPipeTake))
               | currentPipeTake <- pipeTakeFacts currentRule
               ]

diagnosisNodeFor ::
  EffectSemantics ->
  Runtime ->
  WorkflowFact ->
  RuntimeDiagnosisNodeKind ->
  RuntimeDiagnosisNode
diagnosisNodeFor semantics runtime currentFact currentKind =
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
      takeMakeRuleFor semantics currentFact
    sends =
      maybe [] externalMakeNames currentRule
    idempotentSends =
      [ currentSend
      | currentSend <- sends
      , sendIsIdempotent semantics currentSend
      ]
    nonIdempotentSends =
      [ currentSend
      | currentSend <- sends
      , not (sendIsIdempotent semantics currentSend)
      ]
    blockers =
      missingRuleBlocker currentRule
        ++ externalTakeBlocker currentRule
        ++ map DiagnosisNonIdempotentSend nonIdempotentSends

missingRuleBlocker :: Maybe TakeMakeRule -> [RuntimeDiagnosisBlocker]
missingRuleBlocker Nothing =
  [DiagnosisMissingRule]
missingRuleBlocker (Just _) =
  []

externalTakeBlocker :: Maybe TakeMakeRule -> [RuntimeDiagnosisBlocker]
externalTakeBlocker (Just currentRule)
  | takeMakeSource currentRule == ExternalTake =
      [DiagnosisExternalTakeSource]
externalTakeBlocker _ =
  []

sendIsIdempotent :: EffectSemantics -> SendName -> Bool
sendIsIdempotent semantics currentSend =
  case sendContractFor semantics currentSend of
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

downstreamFacts :: EffectSemantics -> Runtime -> WorkflowFact -> [WorkflowFact]
downstreamFacts semantics runtime rootFact =
  downstreamFactsFrom semantics runtime [] [rootFact]

downstreamFactsFrom ::
  EffectSemantics ->
  Runtime ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  [WorkflowFact]
downstreamFactsFrom _ _ seen [] =
  seen
downstreamFactsFrom semantics runtime seen (currentFact : rest) =
  downstreamFactsFrom semantics runtime nextSeen (rest ++ nextFacts)
  where
    nextFacts =
      [ dependentFact
      | currentRule <- semanticTakeMakeRules semantics
      , currentFact `ruleDependsOnFact` currentRule
      , dependentFact <- makeFacts currentRule
      , dependentFact `elem` claimedFacts runtime
      , dependentFact `notElem` seen
      ]
    nextSeen =
      unique (seen ++ nextFacts)

ruleDependsOnFact :: WorkflowFact -> TakeMakeRule -> Bool
ruleDependsOnFact currentFact currentRule =
  currentFact `elem` takeFacts currentRule
    || any ((== currentFact) . pipeTakeFact) (pipeTakeFacts currentRule)

claimedFacts :: Runtime -> [WorkflowFact]
claimedFacts runtime =
  [ runtimeFactClaimFact currentClaim
  | currentClaim <- runtimeFactClaims runtime
  ]

factStatus :: Runtime -> WorkflowFact -> Maybe RuntimeFactStatus
factStatus runtime currentFact =
  firstJust
    [ Just (runtimeFactClaimStatus currentClaim)
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
    [ "diagnosis root"
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

unique :: Eq item => [item] -> [item]
unique =
  foldl addUnique []
  where
    addUnique items item
      | item `elem` items = items
      | otherwise = items ++ [item]

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest
