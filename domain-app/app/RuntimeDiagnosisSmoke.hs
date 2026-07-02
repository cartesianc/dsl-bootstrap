{-# LANGUAGE PatternSynonyms #-}

module Main
  ( main
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

main :: IO ()
main = do
  runErrorHandlerSmoke
  runRetryDiagnosisSmoke
  runNonIdempotentBlockerSmoke
  putStrLn "[smoke] ok runtime diagnosis"

runErrorHandlerSmoke :: IO ()
runErrorHandlerSmoke = do
  result <-
    runBlueprintWithEffectEnvironmentRuntimeResult
      (runtimeEffectEnvironment failingAskRegistry)
      (theory [userEffect])
      userNameBlueprint
  case result of
    RuntimeFailed (RuntimeHandlerFailed currentSend "ask failed") runtime
      | currentSend == AskUserName
          && not (null (runtimeFailureDiagnoses runtime))
          && traceContains "error handlers UserNameAskedFact [HandleUserNameError]" runtime
          && traceContains "externalMake HandleUserNameError using RuntimeHandleUserNameError" runtime ->
          pure ()
    other ->
      ioError (userError ("[smoke] failed error handler diagnosis: " ++ showRuntimeResult other))

runRetryDiagnosisSmoke :: IO ()
runRetryDiagnosisSmoke = do
  result <-
    runBlueprintWithEffectEnvironmentRuntimeResult
      (runtimeEffectEnvironment retryFailingAskRegistry)
      retryUserNameTheory
      userNameBlueprint
  case result of
    RuntimeFailed (RuntimeHandlerFailed currentSend "retry failed") runtime
      | currentSend == AskUserName
          && traceContains "retry externalMake AskUserName" runtime
          && any diagnosisHasFailedProbe (runtimeFailureDiagnoses runtime) ->
          pure ()
    other ->
      ioError (userError ("[smoke] failed retry diagnosis: " ++ showRuntimeResult other))

runNonIdempotentBlockerSmoke :: IO ()
runNonIdempotentBlockerSmoke = do
  plan <- requirePlan (theory [userEffect])
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
  if DiagnosisNonIdempotentSend AskUserName `elem` blockers
    then pure ()
    else ioError (userError ("[smoke] failed non-idempotent blocker: " ++ show diagnosis))

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

requirePlan :: EffectTheory -> IO NativeAppPlan
requirePlan effects =
  case buildApp userNameBlueprint effects of
    Left message ->
      ioError (userError ("[smoke] failed buildApp: " ++ message))
    Right plan ->
      pure plan

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
