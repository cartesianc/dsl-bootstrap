{-# LANGUAGE PatternSynonyms #-}

module Domain.SemanticEvidence
  ( domainSemanticChecks
  , runtimeDiagnosisEvidencePayloads
  ) where

import Domain.EffectVocabulary
import Domain.RegistryCodegenSpec
  ( expectedEffectsTheoryLines
  , expectedPluginsLines
  )
import Effects.User
  ( userEffect )
import Framework.Handler
  ( HandlerBinding (..)
  , HandlerInput (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , RuntimeHandler (..)
  , RuntimeValue (..)
  , runtimeEffectEnvironment
  )
import Framework.TrustBase
  ( DomainRegistration (domainRegistrationName)
  , DomainSemanticCheck (..)
  , DomainSemanticEvidence
  , NativeAppPlan
  , Runtime (..)
  , RuntimeDiagnosisBlocker (..)
  , RuntimeDiagnosisEvidencePayload (..)
  , RuntimeDiagnosisEvidenceStatus (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeDiagnosisRootCause (..)
  , RuntimeDiagnosisStep (..)
  , RuntimeError (..)
  , RuntimeFactClaim (..)
  , RuntimeFactStatus (..)
  , RuntimeFailureDiagnosis (..)
  , RuntimeResult (..)
  , buildApp
  , buildFailureDiagnosis
  , diffGeneratedLines
  , domainEvidenceFailed
  , domainEvidencePassed
  , emptyRuntime
  , generatedLinesMatch
  , renderRuntimeDiagnosisEvidencePayload
  , runBlueprintWithEffectEnvironmentRuntimeResult
  , runtimeDiagnosisEvidencePayloadPassed
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
import Framework.Ast
  ( AppBlueprint (..)
  )
import qualified Framework.Ast as Workflow

domainSemanticChecks :: [DomainSemanticCheck]
domainSemanticChecks =
  [ runtimeErrorHandlerDiagnosisCheck
  , runtimeRetryDiagnosisCheck
  , runtimeNonIdempotentBlockerCheck
  , runtimeSystemRootCauseDiagnosisCheck
  , pluginRegistryCodegenCheck
  , effectTheoryCodegenCheck
  ]

runtimeErrorHandlerDiagnosisCheck :: DomainSemanticCheck
runtimeErrorHandlerDiagnosisCheck =
  DomainSemanticCheck
    "runtime-diagnosis-error-handler"
    (\_ _ -> runtimeDiagnosisEvidenceFromPayload <$> runErrorHandlerEvidencePayload)

runtimeRetryDiagnosisCheck :: DomainSemanticCheck
runtimeRetryDiagnosisCheck =
  DomainSemanticCheck
    "runtime-diagnosis-retry-probe"
    (\_ _ -> runtimeDiagnosisEvidenceFromPayload <$> runRetryDiagnosisEvidencePayload)

runtimeNonIdempotentBlockerCheck :: DomainSemanticCheck
runtimeNonIdempotentBlockerCheck =
  DomainSemanticCheck
    "runtime-diagnosis-non-idempotent-blocker"
    (\_ _ -> runtimeDiagnosisEvidenceFromPayload <$> runNonIdempotentBlockerEvidencePayload)

runtimeSystemRootCauseDiagnosisCheck :: DomainSemanticCheck
runtimeSystemRootCauseDiagnosisCheck =
  DomainSemanticCheck
    "runtime-diagnosis-system-root-cause"
    (\_ _ -> runtimeDiagnosisEvidenceFromPayload <$> runSystemRootCauseEvidencePayload)

pluginRegistryCodegenCheck :: DomainSemanticCheck
pluginRegistryCodegenCheck =
  DomainSemanticCheck
    "registry-codegen-plugins"
    (\registration _ -> runGeneratedFileEvidence registration "registry-codegen-plugins" "domain-app/src/Plugins.hs" expectedPluginsLines)

effectTheoryCodegenCheck :: DomainSemanticCheck
effectTheoryCodegenCheck =
  DomainSemanticCheck
    "registry-codegen-effects"
    (\registration _ -> runGeneratedFileEvidence registration "registry-codegen-effects" "domain-app/src/Effects/Theory.hs" expectedEffectsTheoryLines)

runGeneratedFileEvidence :: DomainRegistration -> String -> FilePath -> [String] -> IO DomainSemanticEvidence
runGeneratedFileEvidence registration evidenceName path expectedLines = do
  actualText <- readFile path
  let actualLines =
        lines actualText
      mismatchDetails =
        ["generated source differs from " ++ path]
          ++ take 40 (diffGeneratedLines expectedLines actualLines)
  pure
    ( if generatedLinesMatch expectedLines actualLines
        then
          domainEvidencePassed
            evidenceName
            [ "domain: " ++ domainRegistrationName registration
            , "generated source matches " ++ path
            ]
        else
          domainEvidenceFailed
            evidenceName
            mismatchDetails
    )

runtimeDiagnosisEvidencePayloads :: IO [RuntimeDiagnosisEvidencePayload]
runtimeDiagnosisEvidencePayloads =
  sequence
    [ runErrorHandlerEvidencePayload
    , runRetryDiagnosisEvidencePayload
    , runNonIdempotentBlockerEvidencePayload
    , runSystemRootCauseEvidencePayload
    ]

runtimeDiagnosisEvidenceFromPayload :: RuntimeDiagnosisEvidencePayload -> DomainSemanticEvidence
runtimeDiagnosisEvidenceFromPayload payload =
  if runtimeDiagnosisEvidencePayloadPassed payload
    then domainEvidencePassed claim details
    else domainEvidenceFailed claim details
  where
    claim =
      runtimeDiagnosisEvidenceClaim payload
    details =
      renderRuntimeDiagnosisEvidencePayload payload

runErrorHandlerEvidencePayload :: IO RuntimeDiagnosisEvidencePayload
runErrorHandlerEvidencePayload = do
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
              runtimeDiagnosisPayloadPassed
                "runtime-diagnosis-error-handler"
                "RuntimeErrorDispatchArtifact"
                "error handler dispatches recovery path with ErrorInput"
                "HandleUserNameError dispatched with ErrorInput"
        other ->
          runtimeDiagnosisPayloadFailed
            "runtime-diagnosis-error-handler"
            "RuntimeErrorDispatchArtifact"
            "error handler dispatches recovery path with ErrorInput"
            (showRuntimeResult other)
    )

runRetryDiagnosisEvidencePayload :: IO RuntimeDiagnosisEvidencePayload
runRetryDiagnosisEvidencePayload = do
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
              runtimeDiagnosisPayloadPassed
                "runtime-diagnosis-retry-probe"
                "RuntimeRetryPolicyArtifact"
                "idempotent retry records failed diagnosis probe"
                "retry externalMake AskUserName and failed diagnosis probe observed"
        other ->
          runtimeDiagnosisPayloadFailed
            "runtime-diagnosis-retry-probe"
            "RuntimeRetryPolicyArtifact"
            "idempotent retry records failed diagnosis probe"
            (showRuntimeResult other)
    )

runNonIdempotentBlockerEvidencePayload :: IO RuntimeDiagnosisEvidencePayload
runNonIdempotentBlockerEvidencePayload = do
  planResult <- requirePlan (theory [userEffect])
  pure
    ( case planResult of
        Left message ->
          runtimeDiagnosisPayloadFailed
            "runtime-diagnosis-non-idempotent-blocker"
            "RuntimeIdempotencyPolicyArtifact"
            "non-idempotent send is reported as blocker for probe replay"
            message
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
                  runtimeDiagnosisPayloadPassed
                    "runtime-diagnosis-non-idempotent-blocker"
                    "RuntimeIdempotencyPolicyArtifact"
                    "non-idempotent send is reported as blocker for probe replay"
                    "DiagnosisNonIdempotentSend AskUserName found"
                else
                  runtimeDiagnosisPayloadFailed
                    "runtime-diagnosis-non-idempotent-blocker"
                    "RuntimeIdempotencyPolicyArtifact"
                    "non-idempotent send is reported as blocker for probe replay"
                    (show diagnosis)
    )

runSystemRootCauseEvidencePayload :: IO RuntimeDiagnosisEvidencePayload
runSystemRootCauseEvidencePayload = do
  result <-
    runBlueprintWithEffectEnvironmentRuntimeResult
      (runtimeEffectEnvironment missingAskRegistry)
      (theory [userEffect])
      userNameBlueprint
  pure
    ( case result of
        RuntimeFailed (RuntimeMissingHandler currentSend) runtime
          | currentSend == AskUserName
              && any userNameSystemRootCauseDiagnosis (runtimeFailureDiagnoses runtime) ->
              runtimeDiagnosisPayloadPassed
                "runtime-diagnosis-system-root-cause"
                "RuntimeDiagnosisEvidenceArtifact"
                "runtime diagnosis reports EffectSystem, pipeline step, and root cause"
                "UserNameAskedSystem / send AskUserName / missing handler"
        other ->
          runtimeDiagnosisPayloadFailed
            "runtime-diagnosis-system-root-cause"
            "RuntimeDiagnosisEvidenceArtifact"
            "runtime diagnosis reports EffectSystem, pipeline step, and root cause"
            (showRuntimeResult other)
    )

runtimeDiagnosisPayloadPassed :: String -> String -> String -> String -> RuntimeDiagnosisEvidencePayload
runtimeDiagnosisPayloadPassed claim artifact expected observed =
  RuntimeDiagnosisEvidencePayload
    { runtimeDiagnosisEvidenceClaim = claim
    , runtimeDiagnosisEvidenceStatus = RuntimeDiagnosisEvidencePassed
    , runtimeDiagnosisEvidenceExpected = expected
    , runtimeDiagnosisEvidenceObserved = observed
    , runtimeDiagnosisEvidenceArtifact = artifact
    }

runtimeDiagnosisPayloadFailed :: String -> String -> String -> String -> RuntimeDiagnosisEvidencePayload
runtimeDiagnosisPayloadFailed claim artifact expected observed =
  RuntimeDiagnosisEvidencePayload
    { runtimeDiagnosisEvidenceClaim = claim
    , runtimeDiagnosisEvidenceStatus = RuntimeDiagnosisEvidenceFailed
    , runtimeDiagnosisEvidenceExpected = expected
    , runtimeDiagnosisEvidenceObserved = observed
    , runtimeDiagnosisEvidenceArtifact = artifact
    }

userNameBlueprint :: AppBlueprint
userNameBlueprint =
  AppBlueprint
    { blueprintApp =
        Workflow.run
          ( Workflow.effectSystem
              userNameSystem
              (Workflow.factItems [userNameAskedFact])
          )
    , blueprintHanging = Workflow.hanging []
    }

userNameSystem :: Workflow.EffectSystemName
userNameSystem =
  Workflow.EffectSystemName "UserNameAskedSystem"

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

missingAskRegistry :: HandlerRegistry
missingAskRegistry =
  HandlerRegistry
    [ HandlerBinding HandleUserNameError RuntimeHandleUserNameError errorHandler
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

userNameSystemRootCauseDiagnosis :: RuntimeFailureDiagnosis -> Bool
userNameSystemRootCauseDiagnosis diagnosis =
  diagnosisRootSystem diagnosis == Just userNameSystem
    && diagnosisPipelineStep diagnosis == Just (DiagnosisSendStep AskUserName)
    && diagnosisRootCause diagnosis == DiagnosisMissingHandlerCause AskUserName

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
