{-# LANGUAGE PatternSynonyms #-}

module Interpreter.Runtime.Facts
  ( claimFact
  , factExprAvailable
  , factStatus
  , mergeRuntime
  , failDependentFacts
  , markFactFailed
  , markFactFailedBy
  , markFactRunning
  , markFactSucceeded
  , recordFact
  , recordPipeOutputs
  , recordRuntimeTypedValues
  , recordRuntimeValues
  , succeededFacts
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Architecture
  ( Fact (..)
  , FactExpr (..)
  , Requirement (..)
  , WorkflowName
  )
import Core.Architecture.Internal
  ( RequirementEffect (..)
  )
import Core.Effect.Semantics
  ( EffectSemantics (..)
  , PipeTake (..)
  , TakeMakeRule (..)
  )
import Effects.Names
  ( TypeName (..)
  , pattern NoInput
  , pattern Unit
  )
import Interpreter.Runtime.Monad
  ( modifyRuntimeState
  , runtimeSleepM
  , traceRuntimeM
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , RuntimeFactClaim (..)
  , RuntimeFactFailure (..)
  , RuntimeFactStatus (..)
  , RuntimeValue (..)
  , SomeRuntimeValue
  , WorkflowProgram
  , runtimeValueToSome
  , someRuntimeValueToRuntimeValue
  , someRuntimeValueType
  )
import Interpreter.Runtime.Trace
  ( renderFactExpr
  )

recordFact :: Fact WorkflowFact -> WorkflowProgram
recordFact currentFact = do
  traceRuntimeM ("fact " ++ renderFactExpr (factExpression currentFact))
  runtimeSleepM
  modifyRuntimeState
    ( \runtime ->
        foldl markSucceeded runtime (collectFactExpr (factExpression currentFact))
    )

factExprAvailable :: Runtime -> FactExpr WorkflowFact -> Bool
factExprAvailable runtime (FactItems currentFacts) =
  all (`factSucceeded` runtime) (collectFacts currentFacts)
factExprAvailable runtime (FactAll currentFacts) =
  all (factExprAvailable runtime) currentFacts
factExprAvailable runtime (FactAny currentFacts) =
  any (factExprAvailable runtime) currentFacts

claimFact :: WorkflowFact -> Runtime -> Runtime
claimFact currentFact runtime =
  case factStatus runtime currentFact of
    Nothing ->
      runtime
        { runtimeFactClaims =
            runtimeFactClaims runtime <> [RuntimeFactClaim currentFact RuntimeFactPending Nothing]
        }
    Just _ ->
      runtime

markFactRunning :: WorkflowFact -> Runtime -> Runtime
markFactRunning currentFact =
  updateFactStatus currentFact RuntimeFactRunning

markFactSucceeded :: WorkflowFact -> Runtime -> Runtime
markFactSucceeded currentFact runtime =
  markSucceeded runtime currentFact

markFactFailed :: WorkflowFact -> Runtime -> Runtime
markFactFailed currentFact runtime =
  markFactFailedBy currentFact (RuntimeLocalFactFailed "fact failed") runtime

markFactFailedBy :: WorkflowFact -> RuntimeFactFailure -> Runtime -> Runtime
markFactFailedBy currentFact failure runtime =
  updateFactFailure currentFact failure (removeAvailableFact currentFact runtime)

failDependentFacts :: EffectSemantics -> WorkflowFact -> Runtime -> Runtime
failDependentFacts semantics failedFact runtime =
  foldl failOneDependent runtime (dependentClaimFailures semantics failedFact runtime)
  where
    failOneDependent currentRuntime (currentFact, failure) =
      failDependentFacts
        semantics
        currentFact
        (markFactFailedBy currentFact failure currentRuntime)

factStatus :: Runtime -> WorkflowFact -> Maybe RuntimeFactStatus
factStatus runtime currentFact =
  firstJust
    [ Just (runtimeFactClaimStatus currentClaim)
    | currentClaim <- runtimeFactClaims runtime
    , runtimeFactClaimFact currentClaim == currentFact
    ]

succeededFacts :: Runtime -> [WorkflowFact]
succeededFacts =
  availableFacts

mergeRuntime :: Runtime -> Runtime -> Runtime
mergeRuntime left right =
  left
    { availableFacts = mergeFacts (availableFacts left) (availableFacts right)
    , availablePipeTypes = mergePipeTypes (availablePipeTypes left) (availablePipeTypes right)
    , runtimeValues = mergeRuntimeValues (runtimeValues left) (runtimeValues right)
    , runtimeTypedValues = mergeRuntimeTypedValues (runtimeTypedValues left) (runtimeTypedValues right)
    , runtimeFactClaims = mergeFactClaims (runtimeFactClaims left) (runtimeFactClaims right)
    , runtimeTrace = runtimeTrace left <> runtimeTrace right
    , runtimeCompletedComponents =
        mergeWorkflowNames (runtimeCompletedComponents left) (runtimeCompletedComponents right)
    , runtimeComponentEvents = runtimeComponentEvents left <> runtimeComponentEvents right
    , runtimeCallbackEvents = runtimeCallbackEvents left <> runtimeCallbackEvents right
    , runtimeSuspenseEvents = runtimeSuspenseEvents left <> runtimeSuspenseEvents right
    , runtimeMiddlewareEvents = runtimeMiddlewareEvents left <> runtimeMiddlewareEvents right
    , runtimeFailureDiagnoses = runtimeFailureDiagnoses left <> runtimeFailureDiagnoses right
    }

collectFactExpr :: FactExpr WorkflowFact -> [WorkflowFact]
collectFactExpr (FactItems currentFacts) =
  collectFacts currentFacts
collectFactExpr (FactAll currentFacts) =
  concatMap collectFactExpr currentFacts
collectFactExpr (FactAny currentFacts) =
  concatMap collectFactExpr currentFacts

collectFacts :: Requirement WorkflowFact -> [WorkflowFact]
collectFacts =
  requirementEffectItems . requirementFacts

mergeFacts :: [WorkflowFact] -> [WorkflowFact] -> [WorkflowFact]
mergeFacts =
  mergeUnique

mergePipeTypes :: [TypeName] -> [TypeName] -> [TypeName]
mergePipeTypes =
  mergeUnique

mergeRuntimeValues :: [RuntimeValue] -> [RuntimeValue] -> [RuntimeValue]
mergeRuntimeValues =
  foldl upsertRuntimeValue

upsertRuntimeValue :: [RuntimeValue] -> RuntimeValue -> [RuntimeValue]
upsertRuntimeValue [] currentValue =
  [currentValue]
upsertRuntimeValue (currentValue : rest) nextValue
  | runtimeValueType currentValue == runtimeValueType nextValue =
      nextValue : rest
  | otherwise =
      currentValue : upsertRuntimeValue rest nextValue

mergeRuntimeTypedValues :: [SomeRuntimeValue] -> [SomeRuntimeValue] -> [SomeRuntimeValue]
mergeRuntimeTypedValues =
  foldl upsertRuntimeTypedValue

upsertRuntimeTypedValue :: [SomeRuntimeValue] -> SomeRuntimeValue -> [SomeRuntimeValue]
upsertRuntimeTypedValue [] currentValue =
  [currentValue]
upsertRuntimeTypedValue (currentValue : rest) nextValue
  | someRuntimeValueType currentValue == someRuntimeValueType nextValue =
      nextValue : rest
  | otherwise =
      currentValue : upsertRuntimeTypedValue rest nextValue

mergeFactClaims :: [RuntimeFactClaim] -> [RuntimeFactClaim] -> [RuntimeFactClaim]
mergeFactClaims =
  foldl mergeClaim

mergeClaim :: [RuntimeFactClaim] -> RuntimeFactClaim -> [RuntimeFactClaim]
mergeClaim [] currentClaim =
  [currentClaim]
mergeClaim (currentClaim : rest) nextClaim
  | runtimeFactClaimFact currentClaim == runtimeFactClaimFact nextClaim =
      mergeFactClaim currentClaim nextClaim : rest
  | otherwise =
      currentClaim : mergeClaim rest nextClaim

mergeFactClaim :: RuntimeFactClaim -> RuntimeFactClaim -> RuntimeFactClaim
mergeFactClaim left right =
  left
    { runtimeFactClaimStatus =
        strongerFactStatus (runtimeFactClaimStatus left) (runtimeFactClaimStatus right)
    , runtimeFactClaimFailure =
        mergeFailureCause (runtimeFactClaimFailure left) (runtimeFactClaimFailure right)
    }

strongerFactStatus :: RuntimeFactStatus -> RuntimeFactStatus -> RuntimeFactStatus
strongerFactStatus RuntimeFactSucceeded _ =
  RuntimeFactSucceeded
strongerFactStatus _ RuntimeFactSucceeded =
  RuntimeFactSucceeded
strongerFactStatus RuntimeFactFailed _ =
  RuntimeFactFailed
strongerFactStatus _ RuntimeFactFailed =
  RuntimeFactFailed
strongerFactStatus RuntimeFactRunning _ =
  RuntimeFactRunning
strongerFactStatus _ RuntimeFactRunning =
  RuntimeFactRunning
strongerFactStatus RuntimeFactPending RuntimeFactPending =
  RuntimeFactPending

mergeFailureCause :: Maybe RuntimeFactFailure -> Maybe RuntimeFactFailure -> Maybe RuntimeFactFailure
mergeFailureCause left right =
  case right of
    Just _ ->
      right
    Nothing ->
      left

factSucceeded :: WorkflowFact -> Runtime -> Bool
factSucceeded currentFact runtime =
  currentFact `elem` availableFacts runtime
    || factStatus runtime currentFact == Just RuntimeFactSucceeded

markSucceeded :: Runtime -> WorkflowFact -> Runtime
markSucceeded runtime currentFact =
  let claimedRuntime = claimFact currentFact runtime
   in updateFactStatus currentFact RuntimeFactSucceeded claimedRuntime
        { availableFacts = mergeFacts (availableFacts claimedRuntime) [currentFact]
        }

recordPipeOutputs :: [TypeName] -> Runtime -> Runtime
recordPipeOutputs currentTypes runtime =
  runtime
    { availablePipeTypes = mergePipeTypes (availablePipeTypes runtime) currentTypes
    }

recordRuntimeValues :: [RuntimeValue] -> Runtime -> Runtime
recordRuntimeValues currentValues runtime =
  runtime
    { runtimeValues = mergeRuntimeValues (runtimeValues runtime) currentValues
    , runtimeTypedValues =
        mergeRuntimeTypedValues
          (runtimeTypedValues runtime)
          [ currentTypedValue
          | currentValue <- currentValues
          , Just currentTypedValue <- [runtimeValueToSome currentValue]
          ]
    , availablePipeTypes =
        mergePipeTypes
          (availablePipeTypes runtime)
          [ runtimeValueType currentValue
          | currentValue <- currentValues
          , isStoredPipeType (runtimeValueType currentValue)
          ]
    }

recordRuntimeTypedValues :: [SomeRuntimeValue] -> Runtime -> Runtime
recordRuntimeTypedValues currentValues runtime =
  recordRuntimeValues (map someRuntimeValueToRuntimeValue currentValues) typedRuntime
  where
    typedRuntime =
      runtime
        { runtimeTypedValues =
            mergeRuntimeTypedValues (runtimeTypedValues runtime) currentValues
        }

isStoredPipeType :: TypeName -> Bool
isStoredPipeType NoInput =
  False
isStoredPipeType Unit =
  False
isStoredPipeType _ =
  True

updateFactStatus :: WorkflowFact -> RuntimeFactStatus -> Runtime -> Runtime
updateFactStatus currentFact status runtime =
  let claimedRuntime = claimFact currentFact runtime
   in claimedRuntime
        { runtimeFactClaims =
            map (updateClaimStatus currentFact status) (runtimeFactClaims claimedRuntime)
        }

updateFactFailure :: WorkflowFact -> RuntimeFactFailure -> Runtime -> Runtime
updateFactFailure currentFact failure runtime =
  let claimedRuntime = claimFact currentFact runtime
   in claimedRuntime
        { runtimeFactClaims =
            map (updateClaimFailure currentFact failure) (runtimeFactClaims claimedRuntime)
        }

updateClaimStatus :: WorkflowFact -> RuntimeFactStatus -> RuntimeFactClaim -> RuntimeFactClaim
updateClaimStatus currentFact status currentClaim
  | runtimeFactClaimFact currentClaim == currentFact =
      currentClaim
        { runtimeFactClaimStatus = status
        , runtimeFactClaimFailure =
            if status == RuntimeFactSucceeded
              then Nothing
              else runtimeFactClaimFailure currentClaim
        }
  | otherwise =
      currentClaim

updateClaimFailure :: WorkflowFact -> RuntimeFactFailure -> RuntimeFactClaim -> RuntimeFactClaim
updateClaimFailure currentFact failure currentClaim
  | runtimeFactClaimFact currentClaim == currentFact =
      currentClaim
        { runtimeFactClaimStatus = RuntimeFactFailed
        , runtimeFactClaimFailure = Just failure
        }
  | otherwise =
      currentClaim

removeAvailableFact :: WorkflowFact -> Runtime -> Runtime
removeAvailableFact currentFact runtime =
  runtime
    { availableFacts =
        [ availableFact
        | availableFact <- availableFacts runtime
        , availableFact /= currentFact
        ]
    }

dependentClaimFailures :: EffectSemantics -> WorkflowFact -> Runtime -> [(WorkflowFact, RuntimeFactFailure)]
dependentClaimFailures semantics failedFact runtime =
  [ (currentFact, RuntimeDependencyFailed failedFact)
  | currentRule <- semanticTakeMakeRules semantics
  , failedFact `elem` takeFacts currentRule
  , currentFact <- makeFacts currentRule
  , currentFact `elem` claimedFacts runtime
  , factStatus runtime currentFact /= Just RuntimeFactFailed
  ]
    ++ [ (currentFact, RuntimePipeDependencyFailed failedFact (pipeTakeInput currentPipeTake))
       | currentRule <- semanticTakeMakeRules semantics
       , currentPipeTake <- pipeTakeFacts currentRule
       , pipeTakeFact currentPipeTake == failedFact
       , currentFact <- makeFacts currentRule
       , currentFact `elem` claimedFacts runtime
       , factStatus runtime currentFact /= Just RuntimeFactFailed
       ]

claimedFacts :: Runtime -> [WorkflowFact]
claimedFacts runtime =
  [ runtimeFactClaimFact currentClaim
  | currentClaim <- runtimeFactClaims runtime
  ]

mergeWorkflowNames :: [WorkflowName] -> [WorkflowName] -> [WorkflowName]
mergeWorkflowNames =
  mergeUnique

mergeUnique :: Eq item => [item] -> [item] -> [item]
mergeUnique =
  foldl addItem
  where
    addItem items item
      | item `elem` items = items
      | otherwise = item : items

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest
