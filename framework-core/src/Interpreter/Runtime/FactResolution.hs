module Interpreter.Runtime.FactResolution
  ( resolveFactClaim
  ) where

import Control.Monad
  ( foldM
  )

import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Architecture
  ( Fact (..)
  , FactExpr (..)
  , Requirement (..)
  , factItems
  )
import Core.Architecture.Internal
  ( RequirementEffect (..)
  )
import Core.Effect.Semantics
  ( IdempotencyPolicy (..)
  , PipeTake (..)
  , RetryPolicy (..)
  , SendContract (..)
  , TakeMakeRule (..)
  , TakeMakeSource (..)
  , TransformUse (..)
  , sendContractFor
  , takeMakeRuleFor
  )
import Effects.EffectTheory
  ( SendSignature (..)
  , SendName
  , TypeName (..)
  )
import Interpreter.Runtime.Handlers
  ( handlerFor
  , runHandler
  , transformFor
  )
import Interpreter.Runtime.Facts
  ( claimFact
  , failDependentFacts
  , factStatus
  , markFactFailedBy
  , markFactRunning
  , recordPipeOutputs
  , recordRuntimeTypedValues
  , recordRuntimeValues
  )
import Interpreter.Runtime.Diagnosis
  ( buildFailureDiagnosis
  , completeDiagnosisProbe
  , diagnosisProbePairs
  , recordRuntimeDiagnosis
  , renderRuntimeFailureDiagnosis
  )
import Interpreter.Runtime.Monad
  ( askRuntimeEnv
  , getRuntimeState
  , liftRuntimeIO
  , modifyRuntimeState
  , runtimeSleepM
  , throwRuntimeError
  , traceRuntimeM
  )
import Interpreter.Runtime.Types
  ( HandlerBinding (..)
  , HandlerInput (..)
  , HandlerResult (..)
  , Runtime (..)
  , RuntimeEnv (..)
  , RuntimeError (..)
  , RuntimeEffectEnvironment (..)
  , RuntimeFactClaim (..)
  , RuntimeFactFailure (..)
  , RuntimeFactStatus (..)
  , RuntimeFailureDiagnosis
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeM
  , RuntimeValue (..)
  , SomeRuntimeValue
  , WorkflowProgram
  , applyRuntimeTransform
  , handlerInputFromTypedValues
  , handlerInputFromValues
  , runtimeTransformInput
  , runtimeTransformOutput
  , someRuntimeValueToRuntimeValue
  , someRuntimeValueType
  )

resolveFactClaim ::
  (Fact WorkflowFact -> WorkflowProgram) ->
  Fact WorkflowFact ->
  WorkflowProgram
resolveFactClaim makeFact currentFact = do
  let currentFacts = collectFactExpr (factExpression currentFact)
  traceRuntimeM ("claim " ++ show currentFacts)
  modifyRuntimeState
    ( \runtime ->
        foldl (\state currentItem -> claimFact currentItem state) runtime currentFacts
    )
  advancePendingFacts makeFact

advancePendingFacts ::
  (Fact WorkflowFact -> WorkflowProgram) ->
  WorkflowProgram
advancePendingFacts makeFact = do
  runtime <- getRuntimeState
  let pendingFacts = pendingRuntimeFacts runtime
  progressed <- advancePendingFactsOnce makeFact pendingFacts
  if progressed
    then advancePendingFacts makeFact
    else pure ()

advancePendingFactsOnce ::
  (Fact WorkflowFact -> WorkflowProgram) ->
  [WorkflowFact] ->
  RuntimeM Bool
advancePendingFactsOnce _ [] =
  pure False
advancePendingFactsOnce makeFact (currentFact : rest) = do
  progressed <- advanceOnePendingFact makeFact currentFact
  restProgressed <- advancePendingFactsOnce makeFact rest
  pure (progressed || restProgressed)

advanceOnePendingFact ::
  (Fact WorkflowFact -> WorkflowProgram) ->
  WorkflowFact ->
  RuntimeM Bool
advanceOnePendingFact makeFact currentFact = do
  runtime <- getRuntimeState
  environment <- askRuntimeEnv
  let semantics = runtimeEnvEffectSemantics environment
  case factStatus runtime currentFact of
    Just RuntimeFactSucceeded ->
      pure False
    Just RuntimeFactRunning ->
      pure False
    Just RuntimeFactFailed ->
      pure False
    _ ->
      case takeMakeRuleFor semantics currentFact of
        Nothing ->
          throwRuntimeError (RuntimeMissingFactRule currentFact)
        Just currentRule ->
          advanceByRule makeFact currentRule

advanceByRule ::
  (Fact WorkflowFact -> WorkflowProgram) ->
  TakeMakeRule ->
  RuntimeM Bool
advanceByRule makeFact currentRule =
  case takeMakeSource currentRule of
    ExternalTake ->
      pure False
    InternalMake -> do
      environment <- askRuntimeEnv
      runtime <- getRuntimeState
      let currentFact = takeMakeRuleFact currentRule
          semantics = runtimeEnvEffectSemantics environment
          missingFacts = pendingTakeFacts runtime currentRule
          failedDependencies = failedTakeDependencies runtime currentRule
      if not (null failedDependencies)
        then do
          traceRuntimeM ("claim failed " ++ show currentFact ++ " after " ++ show (map failedDependencyFact failedDependencies))
          _ <- diagnoseRuntimeFailure currentFact Nothing (show (failedDependencyFailure (head failedDependencies)))
          modifyRuntimeState
            ( failDependentFacts semantics
                currentFact
                . markFactFailedBy currentFact (failedDependencyFailure (head failedDependencies))
            )
          pure True
        else
          if not (null missingFacts)
            then do
              traceRuntimeM ("claim pending " ++ show currentFact ++ " waits " ++ show missingFacts)
              pure False
            else do
              traceRuntimeM ("claim running " ++ show currentFact)
              modifyRuntimeState (markFactRunning currentFact)
              transformResult <- runTransforms (transformUses currentRule)
              case transformResult of
                TransformsSucceeded -> do
                  externalMakeResult <- runExternalMakes (externalMakeNames currentRule)
                  case externalMakeResult of
                    ExternalMakesSucceeded -> do
                      makeFact (Fact (factItems (makeFacts currentRule)))
                      modifyRuntimeState (recordPipeOutputs (pipeOutputTypes currentRule))
                      pure True
                    ExternalMakeFailed currentExternalMake errorReport ->
                      handleExternalMakeFailure makeFact currentRule currentExternalMake errorReport
                TransformFailed errorReport ->
                  handleTransformFailure makeFact currentRule errorReport

data TransformResult
  = TransformsSucceeded
  | TransformFailed RuntimeError

data ExternalMakeResult
  = ExternalMakesSucceeded
  | ExternalMakeFailed SendName RuntimeError

diagnoseRuntimeFailure ::
  WorkflowFact ->
  Maybe SendName ->
  String ->
  RuntimeM RuntimeFailureDiagnosis
diagnoseRuntimeFailure currentFact currentSend errorReport = do
  environment <- askRuntimeEnv
  runtime <- getRuntimeState
  let diagnosis =
        buildFailureDiagnosis
          (runtimeEnvEffectSemantics environment)
          runtime
          currentFact
          currentSend
          errorReport
  probedDiagnosis <- runDiagnosisProbes diagnosis
  traceRuntimeM (renderRuntimeFailureDiagnosis probedDiagnosis)
  modifyRuntimeState (recordRuntimeDiagnosis probedDiagnosis)
  pure probedDiagnosis

runDiagnosisProbes :: RuntimeFailureDiagnosis -> RuntimeM RuntimeFailureDiagnosis
runDiagnosisProbes diagnosis =
  foldM runDiagnosisProbe diagnosis (diagnosisProbePairs diagnosis)

runDiagnosisProbe ::
  RuntimeFailureDiagnosis ->
  (WorkflowFact, SendName) ->
  RuntimeM RuntimeFailureDiagnosis
runDiagnosisProbe diagnosis (currentFact, currentSend) = do
  traceRuntimeM ("diagnosis probe " ++ show currentFact ++ " externalMake " ++ show currentSend)
  result <- runExternalMakeOnce currentSend
  case result of
    Nothing -> do
      traceRuntimeM ("diagnosis probe ok " ++ show currentFact ++ " externalMake " ++ show currentSend)
      pure (completeDiagnosisProbe currentFact currentSend DiagnosisProbePassed diagnosis)
    Just errorReport -> do
      traceRuntimeM
        ( "diagnosis probe failed "
            ++ show currentFact
            ++ " externalMake "
            ++ show currentSend
            ++ " "
            ++ show errorReport
        )
      pure
        ( completeDiagnosisProbe
            currentFact
            currentSend
            (DiagnosisProbeFailed (show errorReport))
            diagnosis
        )

handleTransformFailure ::
  (Fact WorkflowFact -> WorkflowProgram) ->
  TakeMakeRule ->
  RuntimeError ->
  RuntimeM Bool
handleTransformFailure makeFact currentRule errorReport = do
  environment <- askRuntimeEnv
  let currentFact = takeMakeRuleFact currentRule
      semantics = runtimeEnvEffectSemantics environment
  _ <- diagnoseRuntimeFailure currentFact Nothing (show errorReport)
  modifyRuntimeState
    ( recordRuntimeValues [RuntimeValue ErrorInput (show errorReport)]
        . failDependentFacts semantics currentFact
        . markFactFailedBy currentFact (RuntimeLocalFactFailed (show errorReport))
    )
  runErrorHandlers currentRule
  if null (failureMakeFacts currentRule)
    then throwRuntimeError errorReport
    else do
      traceRuntimeM
        ( "transform failed, make failure facts "
            ++ show (failureMakeFacts currentRule)
        )
      makeFact (Fact (factItems (failureMakeFacts currentRule)))
      pure True

handleExternalMakeFailure ::
  (Fact WorkflowFact -> WorkflowProgram) ->
  TakeMakeRule ->
  SendName ->
  RuntimeError ->
  RuntimeM Bool
handleExternalMakeFailure makeFact currentRule currentExternalMake errorReport
  = do
      environment <- askRuntimeEnv
      let currentFact = takeMakeRuleFact currentRule
          semantics = runtimeEnvEffectSemantics environment
      _ <- diagnoseRuntimeFailure currentFact (Just currentExternalMake) (show errorReport)
      modifyRuntimeState
        ( recordRuntimeValues [RuntimeValue ErrorInput (show errorReport)]
            . failDependentFacts semantics currentFact
            . markFactFailedBy
              currentFact
              (RuntimeExternalMakeFailed currentExternalMake (show errorReport))
        )
      runErrorHandlers currentRule
      if null (failureMakeFacts currentRule)
        then throwRuntimeError errorReport
        else do
          traceRuntimeM
            ( "externalMake "
                ++ show currentExternalMake
                ++ " failed, make failure facts "
                ++ show (failureMakeFacts currentRule)
            )
          makeFact (Fact (factItems (failureMakeFacts currentRule)))
          pure True

runExternalMakes ::
  [SendName] ->
  RuntimeM ExternalMakeResult
runExternalMakes [] =
  pure ExternalMakesSucceeded
runExternalMakes (currentExternalMake : rest) = do
  currentResult <- runExternalMakeWithPolicy currentExternalMake
  case currentResult of
    Nothing ->
      runExternalMakes rest
    Just errorReport ->
      pure (ExternalMakeFailed currentExternalMake errorReport)

runTransforms :: [TransformUse] -> RuntimeM TransformResult
runTransforms [] =
  pure TransformsSucceeded
runTransforms (currentTransform : rest) = do
  currentResult <- runTransform currentTransform
  case currentResult of
    Nothing ->
      runTransforms rest
    Just errorReport ->
      pure (TransformFailed errorReport)

runTransform :: TransformUse -> RuntimeM (Maybe RuntimeError)
runTransform currentTransform = do
  environment <- askRuntimeEnv
  runtime <- getRuntimeState
  let effectEnvironment = runtimeEnvEffectEnvironment environment
      currentName = transformUseName currentTransform
      expectedInput = transformUseInput currentTransform
      expectedOutput = transformUseOutput currentTransform
  case transformFor (runtimeEffectTransforms effectEnvironment) currentName of
    Nothing ->
      pure (Just (RuntimeMissingTransform currentName))
    Just currentRuntimeTransform ->
      if runtimeTransformInput currentRuntimeTransform /= expectedInput
        || runtimeTransformOutput currentRuntimeTransform /= expectedOutput
        then
          pure
            ( Just
                ( RuntimeTransformSignatureMismatch
                    currentName
                    expectedInput
                    expectedOutput
                    (runtimeTransformInput currentRuntimeTransform)
                    (runtimeTransformOutput currentRuntimeTransform)
                )
            )
        else
          case runtimeTypedValueFor expectedInput runtime of
            Nothing ->
              pure (Just (RuntimeMissingTransformInput currentName expectedInput))
            Just currentInput -> do
              traceRuntimeM
                ( "transform "
                    ++ show currentName
                    ++ " "
                    ++ show expectedInput
                    ++ " -> "
                    ++ show expectedOutput
                )
              case applyRuntimeTransform currentName currentRuntimeTransform currentInput of
                Left errorReport ->
                  pure (Just errorReport)
                Right currentOutput -> do
                  modifyRuntimeState (recordRuntimeTypedValues [currentOutput])
                  pure Nothing

runExternalMakeWithPolicy :: SendName -> RuntimeM (Maybe RuntimeError)
runExternalMakeWithPolicy currentExternalMake = do
  firstResult <- runExternalMakeOnce currentExternalMake
  case firstResult of
    Nothing ->
      pure Nothing
    Just errorReport -> do
      retryAllowed <- externalMakeRetryAllowed currentExternalMake
      if retryAllowed
        then do
          traceRuntimeM ("retry externalMake " ++ show currentExternalMake)
          runExternalMakeOnce currentExternalMake
        else
          pure (Just errorReport)

runExternalMakeOnce :: SendName -> RuntimeM (Maybe RuntimeError)
runExternalMakeOnce currentExternalMake = do
  environment <- askRuntimeEnv
  runtime <- getRuntimeState
  let effectEnvironment = runtimeEnvEffectEnvironment environment
      semantics = runtimeEnvEffectSemantics environment
  case sendContractFor semantics currentExternalMake of
    Nothing ->
      pure (Just (RuntimeMissingSendBoundary currentExternalMake))
    Just currentContract ->
      case handlerFor (runtimeEffectHandlers effectEnvironment) currentExternalMake of
        Nothing ->
          pure (Just (RuntimeMissingHandler currentExternalMake))
        Just currentBinding -> do
          let currentSignature =
                sendContractSignature currentContract
          traceRuntimeM
            ( "externalMake "
                ++ show currentExternalMake
                ++ " using "
                ++ show (handlerBindingName currentBinding)
            )
          runtimeSleepM
          case handlerInputFor currentExternalMake currentSignature runtime of
            Left errorReport ->
              pure (Just errorReport)
            Right handlerInput -> do
              handlerResult <- liftRuntimeIO $
                runHandler
                  (runtimeEffectHandlers effectEnvironment)
                  currentExternalMake
                  handlerInput
                  runtime
              case handlerResult of
                HandlerSucceeded outputs ->
                  case checkedHandlerOutputs currentExternalMake currentSignature outputs of
                    Left errorReport ->
                      pure (Just errorReport)
                    Right checkedOutputs -> do
                      modifyRuntimeState (recordRuntimeValues checkedOutputs)
                      pure Nothing
                HandlerSucceededTyped outputs ->
                  case checkedHandlerTypedOutputs currentExternalMake currentSignature outputs of
                    Left errorReport ->
                      pure (Just errorReport)
                    Right checkedOutputs -> do
                      modifyRuntimeState (recordRuntimeTypedValues checkedOutputs)
                      pure Nothing
                HandlerFailed message ->
                  pure (Just (RuntimeHandlerFailed currentExternalMake message))

handlerInputFor :: SendName -> SendSignature -> Runtime -> Either RuntimeError HandlerInput
handlerInputFor currentSend currentSignature runtime =
  case sendInput currentSignature of
    NoInput ->
      Right (handlerInputFromValues [])
    Unit ->
      Right (handlerInputFromValues [])
    currentInput ->
      case runtimeTypedValueFor currentInput runtime of
        Just currentValue ->
          Right (handlerInputFromTypedValues [currentValue])
        Nothing ->
          case runtimeValueFor currentInput runtime of
            Just currentValue ->
              Right (handlerInputFromValues [currentValue])
            Nothing ->
              Left (RuntimeMissingHandlerInput currentSend currentInput)

checkedHandlerOutputs ::
  SendName ->
  SendSignature ->
  [RuntimeValue] ->
  Either RuntimeError [RuntimeValue]
checkedHandlerOutputs currentSend currentSignature outputs =
  case sendOutput currentSignature of
    NoInput ->
      checkNoOutput currentSend NoInput outputs
    Unit ->
      checkNoOutput currentSend Unit outputs
    expectedOutput ->
      if runtimeValueTypes outputs == [expectedOutput]
        then Right outputs
        else Left (RuntimeHandlerOutputMismatch currentSend expectedOutput (runtimeValueTypes outputs))

checkedHandlerTypedOutputs ::
  SendName ->
  SendSignature ->
  [SomeRuntimeValue] ->
  Either RuntimeError [SomeRuntimeValue]
checkedHandlerTypedOutputs currentSend currentSignature outputs =
  case checkedHandlerOutputs currentSend currentSignature (map someRuntimeValueToRuntimeValue outputs) of
    Left errorReport ->
      Left errorReport
    Right _ ->
      Right outputs

checkNoOutput :: SendName -> TypeName -> [RuntimeValue] -> Either RuntimeError [RuntimeValue]
checkNoOutput currentSend expectedOutput outputs =
  case runtimeValueTypes outputs of
    [] ->
      Right []
    [Unit] ->
      Right []
    actualOutputs ->
      Left (RuntimeHandlerOutputMismatch currentSend expectedOutput actualOutputs)

runtimeValueFor :: TypeName -> Runtime -> Maybe RuntimeValue
runtimeValueFor currentType runtime =
  firstJust
    [ Just currentValue
    | currentValue <- runtimeValues runtime
    , runtimeValueType currentValue == currentType
    ]

runtimeTypedValueFor :: TypeName -> Runtime -> Maybe SomeRuntimeValue
runtimeTypedValueFor currentType runtime =
  firstJust
    [ Just currentValue
    | currentValue <- runtimeTypedValues runtime
    , someRuntimeValueType currentValue == currentType
    ]

runtimeValueTypes :: [RuntimeValue] -> [TypeName]
runtimeValueTypes =
  map runtimeValueType

externalMakeRetryAllowed :: SendName -> RuntimeM Bool
externalMakeRetryAllowed currentExternalMake = do
  environment <- askRuntimeEnv
  let semantics = runtimeEnvEffectSemantics environment
  case sendContractFor semantics currentExternalMake of
    Just currentContract ->
      pure
        ( sendContractRetry currentContract == RetryOnce
            && sendContractIdempotency currentContract == Idempotent
        )
    Nothing ->
      pure False

runErrorHandlers :: TakeMakeRule -> RuntimeM ()
runErrorHandlers currentRule =
  case errorHandlerNames currentRule of
    [] ->
      pure ()
    handlers -> do
      traceRuntimeM
        ( "error handlers "
            ++ show (takeMakeRuleFact currentRule)
            ++ " "
            ++ show handlers
        )
      result <- runExternalMakes handlers
      case result of
        ExternalMakesSucceeded ->
          pure ()
        ExternalMakeFailed currentHandler errorReport -> do
          traceRuntimeM
            ( "error handler "
                ++ show currentHandler
                ++ " failed "
                ++ show errorReport
            )
          modifyRuntimeState
            ( markFactFailedBy
                (takeMakeRuleFact currentRule)
                (RuntimeErrorHandlerFailed currentHandler (show errorReport))
            )
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

pendingRuntimeFacts :: Runtime -> [WorkflowFact]
pendingRuntimeFacts runtime =
  [ currentFact
  | RuntimeFactClaim currentFact RuntimeFactPending _ <- runtimeFactClaims runtime
  ]

pendingTakeFacts :: Runtime -> TakeMakeRule -> [WorkflowFact]
pendingTakeFacts runtime currentRule =
  [ currentFact
  | currentFact <- allTakeFacts currentRule
  , not (runtimeFactSucceeded runtime currentFact)
  ]

data FailedDependency
  = FailedNeedsDependency WorkflowFact
  | FailedPipeDependency WorkflowFact TypeName

failedTakeDependencies :: Runtime -> TakeMakeRule -> [FailedDependency]
failedTakeDependencies runtime currentRule =
  [ FailedNeedsDependency currentFact
  | currentFact <- takeFacts currentRule
  , factStatus runtime currentFact == Just RuntimeFactFailed
  ]
    ++ [ FailedPipeDependency (pipeTakeFact currentPipeTake) (pipeTakeInput currentPipeTake)
       | currentPipeTake <- pipeTakeFacts currentRule
       , factStatus runtime (pipeTakeFact currentPipeTake) == Just RuntimeFactFailed
       ]

failedDependencyFact :: FailedDependency -> WorkflowFact
failedDependencyFact (FailedNeedsDependency currentFact) =
  currentFact
failedDependencyFact (FailedPipeDependency currentFact _) =
  currentFact

failedDependencyFailure :: FailedDependency -> RuntimeFactFailure
failedDependencyFailure (FailedNeedsDependency currentFact) =
  RuntimeDependencyFailed currentFact
failedDependencyFailure (FailedPipeDependency currentFact currentType) =
  RuntimePipeDependencyFailed currentFact currentType

allTakeFacts :: TakeMakeRule -> [WorkflowFact]
allTakeFacts currentRule =
  unique
    ( takeFacts currentRule
        ++ [ pipeTakeFact currentPipeTake
           | currentPipeTake <- pipeTakeFacts currentRule
           ]
    )

runtimeFactSucceeded :: Runtime -> WorkflowFact -> Bool
runtimeFactSucceeded runtime currentFact =
  currentFact `elem` availableFacts runtime
    || factStatus runtime currentFact == Just RuntimeFactSucceeded

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
