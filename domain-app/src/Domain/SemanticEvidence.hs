{-# LANGUAGE PatternSynonyms #-}

module Domain.SemanticEvidence
  ( domainSemanticChecks
  ) where

import Domain.EffectVocabulary
import Effects.User
  ( userEffect )
import Framework.Background
  ( HandlerBinding (..)
  , HandlerInput (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , NativeAppPlan
  , Runtime (..)
  , RuntimeDiagnosisBlocker (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeError (..)
  , RuntimeFactClaim (..)
  , RuntimeFactStatus (..)
  , RuntimeFailureDiagnosis (..)
  , RuntimeHandler (..)
  , RuntimeResult (..)
  , RuntimeValue (..)
  , buildApp
  , buildFailureDiagnosis
  , emptyRuntime
  , runtimeEffectEnvironment
  , runBlueprintWithEffectEnvironmentRuntimeResult
  )
import Framework.Domain
  ( DomainSemanticCheck (..)
  , DomainSemanticEvidence
  , domainEvidenceFailed
  , domainEvidencePassed
  )
import Framework.Effect
  ( EffectName (..)
  , EffectTheory
  , effect
  , idempotent
  , retry
  , pattern ErrorInput
  , theory
  )
import Framework.Workflow
  ( AppBlueprint (..)
  )
import qualified Framework.Workflow as Workflow

domainSemanticChecks :: [DomainSemanticCheck]
domainSemanticChecks =
  [ runtimeErrorHandlerDiagnosisCheck
  , runtimeRetryDiagnosisCheck
  , runtimeNonIdempotentBlockerCheck
  ]

runtimeErrorHandlerDiagnosisCheck :: DomainSemanticCheck
runtimeErrorHandlerDiagnosisCheck =
  DomainSemanticCheck
    "runtime-diagnosis-error-handler"
    (\_ _ -> runErrorHandlerEvidence)

runtimeRetryDiagnosisCheck :: DomainSemanticCheck
runtimeRetryDiagnosisCheck =
  DomainSemanticCheck
    "runtime-diagnosis-retry-probe"
    (\_ _ -> runRetryDiagnosisEvidence)

runtimeNonIdempotentBlockerCheck :: DomainSemanticCheck
runtimeNonIdempotentBlockerCheck =
  DomainSemanticCheck
    "runtime-diagnosis-non-idempotent-blocker"
    (\_ _ -> runNonIdempotentBlockerEvidence)

runErrorHandlerEvidence :: IO DomainSemanticEvidence
runErrorHandlerEvidence = do
  result <-
    runBlueprintWithEffectEnvironmentRuntimeResult
      (runtimeEffectEnvironment failingAskRegistry)
      (theory [userEffect])
      userNameBlueprint
  pure
    ( case result of
        RuntimeFailed (RuntimeHandlerFailed currentSend "ask failed") runtime
          | currentSend == AskUserName
              && not (null (runtimeFailureDiagnoses runtime))
              && traceContains "error handlers UserNameAskedFact [HandleUserNameError]" runtime
              && traceContains "externalMake HandleUserNameError using RuntimeHandleUserNameError" runtime ->
              domainEvidencePassed
                "runtime-diagnosis-error-handler"
                ["HandleUserNameError dispatched with ErrorInput"]
        other ->
          domainEvidenceFailed
            "runtime-diagnosis-error-handler"
            [showRuntimeResult other]
    )

runRetryDiagnosisEvidence :: IO DomainSemanticEvidence
runRetryDiagnosisEvidence = do
  result <-
    runBlueprintWithEffectEnvironmentRuntimeResult
      (runtimeEffectEnvironment retryFailingAskRegistry)
      retryUserNameTheory
      userNameBlueprint
  pure
    ( case result of
        RuntimeFailed (RuntimeHandlerFailed currentSend "retry failed") runtime
          | currentSend == AskUserName
              && traceContains "retry externalMake AskUserName" runtime
              && any diagnosisHasFailedProbe (runtimeFailureDiagnoses runtime) ->
              domainEvidencePassed
                "runtime-diagnosis-retry-probe"
                ["idempotent retry produced a failed diagnosis probe"]
        other ->
          domainEvidenceFailed
            "runtime-diagnosis-retry-probe"
            [showRuntimeResult other]
    )

runNonIdempotentBlockerEvidence :: IO DomainSemanticEvidence
runNonIdempotentBlockerEvidence = do
  planResult <- requirePlan (theory [userEffect])
  pure
    ( case planResult of
        Left message ->
          domainEvidenceFailed "runtime-diagnosis-non-idempotent-blocker" [message]
        Right plan ->
          let runtime =
                emptyRuntime
                  { runtimeFactClaims =
                      [ RuntimeFactClaim userNameAskedFact RuntimeFactFailed Nothing
                      ]
                  }
              diagnosis =
                buildFailureDiagnosis
                  plan
                  runtime
                  userNameAskedFact
                  (Just AskUserName)
                  "ask failed"
              blockers =
                concatMap diagnosisNodeBlockers (diagnosisNodes diagnosis)
           in if DiagnosisNonIdempotentSend AskUserName `elem` blockers
                then
                  domainEvidencePassed
                    "runtime-diagnosis-non-idempotent-blocker"
                    ["non-idempotent AskUserName blocks probe replay"]
                else
                  domainEvidenceFailed
                    "runtime-diagnosis-non-idempotent-blocker"
                    [show diagnosis]
    )

userNameBlueprint :: AppBlueprint
userNameBlueprint =
  AppBlueprint
    { blueprintApp = Workflow.fact (Workflow.factItems [userNameAskedFact])
    , blueprintHanging = Workflow.hanging []
    }

userNameAskedFact :: Workflow.WorkflowFact
userNameAskedFact =
  Workflow.WorkflowFact "UserNameAskedFact"

retryUserNameTheory :: EffectTheory
retryUserNameTheory =
  theory
    [ userEffect
    , effect
        (EffectName "RetryUserNameEffect")
        [ idempotent AskUserName
        , retry AskUserName
        ]
    ]

failingAskRegistry :: HandlerRegistry
failingAskRegistry =
  HandlerRegistry
    [ HandlerBinding AskUserName RuntimeAskUserName (failingHandler "ask failed")
    , HandlerBinding HandleUserNameError RuntimeHandleUserNameError errorHandler
    ]

retryFailingAskRegistry :: HandlerRegistry
retryFailingAskRegistry =
  HandlerRegistry
    [ HandlerBinding AskUserName RuntimeAskUserName (failingHandler "retry failed")
    , HandlerBinding HandleUserNameError RuntimeHandleUserNameError errorHandler
    ]

failingHandler :: String -> RuntimeHandler
failingHandler message =
  RuntimeHandler (\_ _ _ -> pure (HandlerFailed message))

errorHandler :: RuntimeHandler
errorHandler =
  RuntimeHandler
    ( \_ input _ ->
        if any ((== ErrorInput) . runtimeValueType) (handlerInputValues input)
          then pure (HandlerSucceeded [])
          else pure (HandlerFailed "missing error input")
    )

requirePlan :: EffectTheory -> IO (Either String NativeAppPlan)
requirePlan effects =
  case buildApp userNameBlueprint effects of
    Left message ->
      pure (Left message)
    Right plan ->
      pure (Right plan)

diagnosisHasFailedProbe :: RuntimeFailureDiagnosis -> Bool
diagnosisHasFailedProbe diagnosis =
  any isFailedProbe (diagnosisProbes diagnosis)

isFailedProbe :: RuntimeDiagnosisProbe -> Bool
isFailedProbe probe =
  case diagnosisProbeStatus probe of
    DiagnosisProbeFailed _ ->
      True
    _ ->
      False

traceContains :: String -> Runtime -> Bool
traceContains expected runtime =
  ("[runtime] " ++ expected) `elem` runtimeTrace runtime

showRuntimeResult :: RuntimeResult Runtime -> String
showRuntimeResult result =
  case result of
    RuntimeSucceeded _ runtime ->
      "succeeded " ++ show (runtimeTrace runtime)
    RuntimeFailed errorReport runtime ->
      "failed " ++ show errorReport ++ " " ++ show (runtimeTrace runtime)
