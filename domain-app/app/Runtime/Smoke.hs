{-# LANGUAGE GADTs #-}
{-# LANGUAGE PatternSynonyms #-}

module Runtime.Smoke
  ( runAlternativeWorkflowSmoke
  , runHangingWorkflowSmoke
  , runRaceWorkflowSmoke
  , runRuntimeBoundarySmoke
  , runSimpleWorkflowSmoke
  ) where

import Control.Exception
  ( SomeException
  , try
  )

import Blueprint
import Domain.EffectVocabulary
import Domain.Runtime
  ( ReportInputValue (..)
  , UserNameValue (..)
  , domainRuntimeEffectEnvironment
  , pattern ReportInputTag
  , pattern UserNameTag
  )
import qualified Framework.Workflow as Architecture
import Framework.Background
import Framework.Effect
  ( EffectTheory
  , pattern NoInput
  , pattern Unit
  , theory
  )
import qualified Framework.Effect as EffectTheory
import Effects.User
  ( userEffect
  )

type RuntimeWorkflowProgram = RuntimeM ()

runSimpleWorkflowSmoke :: IO ()
runSimpleWorkflowSmoke = do
  runSmoke "fact" smokeFact
  runSmoke "chain" smokeChain
  runSmoke "wait" smokeWait
  runSmoke "parallel" smokeParallel

runAlternativeWorkflowSmoke :: IO ()
runAlternativeWorkflowSmoke = do
  runSmoke "fallback" smokeFallback
  runSmoke "choice" smokeChoice

runRaceWorkflowSmoke :: IO ()
runRaceWorkflowSmoke =
  runSmoke "race" smokeRace

runHangingWorkflowSmoke :: IO ()
runHangingWorkflowSmoke = do
  putStrLn "[smoke] hanging"
  runtime <-
    runRuntimeMOrThrow
      defaultRuntimeEnv
      emptyRuntime
      (gpreproWorkflow compileWorkflowEff interpretWorkflowEff runtimeAlgebra smokeFact)
  result <-
    try
      ( runRuntimeMOrThrow
          defaultRuntimeEnv
          runtime
          (runHanging (gpreproHanging compileHangingEff interpretHangingEff runtimeAlgebra smokeHanging))
      )
  case result of
    Right nextRuntime ->
      putStrLn ("[smoke] ok " ++ show (availableFacts nextRuntime))
    Left exception ->
      putStrLn ("[smoke] failed " ++ show (exception :: SomeException))

runRuntimeBoundarySmoke :: IO ()
runRuntimeBoundarySmoke = do
  runEffectBoundaryNormalizationSmoke
  runTransformContractSmoke
  runFailureDiagnosisGraphSmoke
  runExpectedRuntimeFailure
    "missing take/make rule"
    (RuntimeMissingFactRule Foo5Fact)
    (programWithEffects (theory []) smokeFact)
  runExpectedRuntimeFailureWithTrace
    "wait blocked"
    (RuntimeWaitBlocked "[Foo5Fact]")
    "wait blocked [Foo5Fact]"
    (programPlain smokeBlockedWait)
  runExpectedRuntimeFailure
    "missing handler"
    (RuntimeMissingHandler AskUserName)
    ( programWithEnvironment
        (runtimeEffectEnvironment emptyHandlerRegistry)
        (theory [userEffect])
        smokeUserNameAsked
    )
  runExpectedRuntimeFailureWithTrace
    "error handler dispatch"
    (RuntimeHandlerFailed AskUserName "ask failed")
    "error handlers UserNameAskedFact [HandleUserNameError]"
    ( programWithEnvironment
        (runtimeEffectEnvironment failingAskUserNameRegistry)
        (theory [userEffect])
        smokeUserNameAsked
    )
  runExpectedRuntimeFailureWithTrace
    "idempotent retry"
    (RuntimeHandlerFailed AskUserName "retry failed")
    "retry externalMake AskUserName"
    ( programWithEnvironment
        (runtimeEffectEnvironment retryFailingAskUserNameRegistry)
        retryUserNameTheory
        smokeUserNameAsked
    )
  runExpectedRuntimeFailureWith
    "idempotent failure diagnosis"
    (RuntimeHandlerFailed AskUserName "retry failed")
    ( \runtime ->
        case runtimeFailureDiagnoses runtime of
          [diagnosis] ->
            diagnosisRootFact diagnosis == UserNameAskedFact
              && diagnosisRootSend diagnosis == Just AskUserName
              && RuntimeDiagnosisProbe
                UserNameAskedFact
                AskUserName
                (DiagnosisProbeFailed "RuntimeHandlerFailed AskUserName \"retry failed\"")
                `elem` diagnosisProbes diagnosis
          _ ->
            False
    )
    ( programWithEnvironment
        (runtimeEffectEnvironment retryFailingAskUserNameRegistry)
        retryUserNameTheory
        smokeUserNameAsked
    )
  runExpectedRuntimeFailureWithTrace
    "handler output mismatch"
    (RuntimeHandlerOutputMismatch AskUserName UserName [ReportOutput])
    "externalMake AskUserName using RuntimeAskUserName"
    ( programWithEnvironment
        (runtimeEffectEnvironment mismatchedAskUserNameRegistry)
        (theory [userEffect])
        smokeUserNameAsked
    )
  runExpectedRuntimeTrace
    "trace captured"
    "fact [Foo5Fact]"
    (programPlain smokeFact)
  runExpectedRuntimeState
    "pending claim resumes"
    ( \runtime ->
        UserNameAskedFact `elem` availableFacts runtime
          && UserGreetedFact `elem` availableFacts runtime
          && "claim pending UserGreetedFact waits [UserNameAskedFact]" `elem` runtimeTrace runtime
    )
    (programWithEffects (theory [userEffect]) smokeOutOfOrderClaim)
  runExpectedRuntimeState
    "pipe pending claim resumes"
    ( \runtime ->
        UserNameAskedFact `elem` availableFacts runtime
          && UserKnownFact `elem` availableFacts runtime
          && UserName `elem` availablePipeTypes runtime
          && "claim pending UserKnownFact waits [UserNameAskedFact]" `elem` runtimeTrace runtime
    )
    (programWithEffects pipeOnlyTheory smokePipeOutOfOrderClaim)
  runExpectedRuntimeState
    "internal take/make signature"
    ( \runtime ->
        Foo5Fact `elem` availableFacts runtime
          && Foo6Fact `elem` availableFacts runtime
          && UserName `elem` availablePipeTypes runtime
    )
    (programWithEffects internalTakeMakeTheory smokeInternalTakeMakeClaim)
  runExternalTakeSignatureSmoke
  runExpectedRuntimeState
    "value pipeline passes handler input"
    ( \runtime ->
        RuntimeValue UserName "dune" `elem` runtimeValues runtime
          && UserKnownFact `elem` availableFacts runtime
    )
    ( programWithEnvironment
        (runtimeEffectEnvironment valuePipelineRegistry)
        pipeOnlyTheory
        smokePipeOutOfOrderClaim
    )
  runExpectedRuntimeState
    "typed value pipeline passes handler input"
    ( \runtime ->
        SomeRuntimeValue (RuntimeTypedValue UserNameTag (UserNameValue "typed-dune"))
          `elem` runtimeTypedValues runtime
          && typedUserNameText runtime == Just "typed-dune"
          && RuntimeValue UserName "typed-dune" `elem` runtimeValues runtime
          && UserKnownFact `elem` availableFacts runtime
    )
    ( programWithEnvironment
        (runtimeEffectEnvironment typedValuePipelineRegistry)
        pipeOnlyTheory
        smokePipeOutOfOrderClaim
    )
  runExpectedRuntimeState
    "pure transform pipeline"
    ( \runtime ->
        SomeRuntimeValue (RuntimeTypedValue ReportInputTag (ReportInputValue "report-input:runtime-user"))
          `elem` runtimeTypedValues runtime
          && ReportInput `elem` availablePipeTypes runtime
          && Foo6Fact `elem` availableFacts runtime
          && "transform UserNameToReportInput UserName -> ReportInput" `elem` runtimeTrace runtime
    )
    (programWithEffects transformPipelineTheory smokeTransformOutOfOrderClaim)
  runExpectedRuntimeFailureWith
    "pipe failure pollutes downstream"
    (RuntimeHandlerFailed AskUserName "ask failed")
    ( \runtime ->
        factClaimFailure runtime UserKnownFact
          == Just (RuntimePipeDependencyFailed UserNameAskedFact UserName)
    )
    ( programWithEnvironment
        (runtimeEffectEnvironment failingAskUserNameRegistry)
        pipeOnlyTheory
        smokePipeOutOfOrderClaim
    )
  runExpectedRuntimeState
    "singleton fact reuse"
    ( \runtime ->
        countOccurrences "externalMake AskUserName using RuntimeAskUserName" (runtimeTrace runtime) == 1
    )
    (programWithEffects (theory [userEffect]) smokeDuplicateUserNameClaim)
  runExpectedRuntimeFailureWith
    "dependency failure pollutes downstream"
    (RuntimeHandlerFailed AskUserName "ask failed")
    ( \runtime ->
        factClaimStatus runtime UserNameAskedFact == Just RuntimeFactFailed
          && factClaimFailure runtime UserGreetedFact
            == Just (RuntimeDependencyFailed UserNameAskedFact)
    )
    ( programWithEnvironment
        (runtimeEffectEnvironment failingAskUserNameRegistry)
        (theory [userEffect])
        smokeOutOfOrderClaim
    )
  runMiddlewareRuntimeSmoke
  runMiddlewareFailureSmoke
  runCallbackTargetSmoke
  runSuspenseRequestSmoke

runEffectBoundaryNormalizationSmoke :: IO ()
runEffectBoundaryNormalizationSmoke = do
  putStrLn "[smoke] boundary effect normalization"
  let userBoundaries =
        semanticEffectBoundaries (effectSemantics (theory [userEffect]))
      internalBoundaries =
        semanticEffectBoundaries (effectSemantics internalTakeMakeTheory)
      externalTakeBoundaries =
        semanticEffectBoundaries (effectSemantics externalTakeSignatureTheory)
      expectedBoundaries =
        [ BoundaryExternalMake UserNameAskedFact AskUserName NoInput UserName (DerivedFromUses AskUserName)
        , BoundaryInternalMake UserNameAskedFact UserName (DerivedFromUses AskUserName)
        , BoundaryInternalTake UserKnownFact UserName (DerivedFromUses RememberUser)
        ]
          ++ [ BoundaryInternalMake Foo5Fact UserName DeclaredExplicitly
             , BoundaryInternalTake Foo6Fact UserName DeclaredExplicitly
             ]
          ++ [ BoundaryExternalTake Foo5Fact (Just UserName) DeclaredExternalTake
             , BoundaryInternalMake Foo5Fact UserName DeclaredExternalTake
             ]
      actualBoundaries =
        userBoundaries ++ internalBoundaries ++ externalTakeBoundaries
  if all (`elem` actualBoundaries) expectedBoundaries
    then putStrLn "[smoke] ok effect normalization"
    else
      ioError
        ( userError
            ( "[smoke] failed effect normalization: "
                ++ show actualBoundaries
            )
        )

runTransformContractSmoke :: IO ()
runTransformContractSmoke = do
  putStrLn "[smoke] boundary transform contract"
  let semantics = effectSemantics transformPipelineTheory
      expectedContract =
        TransformContract
          { transformContractFact = Foo6Fact
          , transformContractName = UserNameToReportInput
          , transformContractInput = UserName
          , transformContractOutput = ReportInput
          }
      expectedUse =
        TransformUse
          { transformUseFact = Foo6Fact
          , transformUseName = UserNameToReportInput
          , transformUseInput = UserName
          , transformUseOutput = ReportInput
          }
  case takeMakeRuleFor semantics Foo6Fact of
    Just currentRule
      | expectedContract `elem` semanticTransformContracts semantics
          && expectedUse `elem` transformUses currentRule ->
          putStrLn "[smoke] ok transform contract"
      | otherwise ->
          ioError
            ( userError
                ( "[smoke] failed transform contract: "
                    ++ show (semanticTransformContracts semantics)
                    ++ " / "
                    ++ show currentRule
                )
            )
    Nothing ->
      ioError (userError "[smoke] failed transform contract: missing rule")

runExternalTakeSignatureSmoke :: IO ()
runExternalTakeSignatureSmoke = do
  putStrLn "[smoke] boundary externalTake signature"
  let semantics = effectSemantics externalTakeSignatureTheory
  case (takeMakeRuleFor semantics Foo5Fact, takeMakeRuleFor semantics Foo6Fact) of
    (Just sourceRule, Just consumerRule)
      | takeMakeSource sourceRule == ExternalTake
          && pipeOutputTypes sourceRule == [UserName]
          && pipeTakeFacts consumerRule == [PipeTake UserName Foo5Fact] ->
          putStrLn "[smoke] ok externalTake signature"
      | otherwise ->
          ioError
            ( userError
                ( "[smoke] failed externalTake signature: "
                    ++ show sourceRule
                    ++ " / "
                    ++ show consumerRule
                )
            )
    other ->
      ioError (userError ("[smoke] failed externalTake signature: missing rules " ++ show other))

runFailureDiagnosisGraphSmoke :: IO ()
runFailureDiagnosisGraphSmoke = do
  putStrLn "[smoke] boundary failure diagnosis graph"
  let runtime =
        emptyRuntime
          { runtimeFactClaims =
              [ RuntimeFactClaim UserKnownFact RuntimeFactPending Nothing
              , RuntimeFactClaim
                  UserNameAskedFact
                  RuntimeFactFailed
                  (Just (RuntimeExternalMakeFailed AskUserName "ask failed"))
              ]
          }
      diagnosis =
        buildFailureDiagnosis
          (effectSemantics pipeOnlyTheory)
          runtime
          UserKnownFact
          Nothing
          "dependency failed"
      nonIdempotentBlockers =
        [ (diagnosisNodeFact currentNode, diagnosisNodeBlockers currentNode)
        | currentNode <- diagnosisNodes diagnosis
        ]
  if null (diagnosisProbes diagnosis)
    && (UserKnownFact, [DiagnosisNonIdempotentSend RememberUser]) `elem` nonIdempotentBlockers
    && (UserNameAskedFact, [DiagnosisNonIdempotentSend AskUserName]) `elem` nonIdempotentBlockers
    && UserKnownFact `elem` diagnosisSuspects diagnosis
    && UserNameAskedFact `elem` diagnosisSuspects diagnosis
    then putStrLn "[smoke] ok failure diagnosis graph"
    else
      ioError
        ( userError
            ( "[smoke] failed failure diagnosis graph: "
                ++ show diagnosis
            )
        )

runMiddlewareRuntimeSmoke :: IO ()
runMiddlewareRuntimeSmoke = do
  putStrLn "[smoke] boundary middleware runtime"
  result <- runRuntimeM defaultRuntimeEnv emptyRuntime (runHanging smokeMiddlewareRuntime)
  case result of
    RuntimeSucceeded _ runtime
      | runtimeMiddlewareStack runtime == []
          && runtimeMiddlewareEvents runtime
            == [ RuntimeMiddlewareEntered ReportMiddleware
               , RuntimeMiddlewareExited ReportMiddleware
               ]
          && AddCalculatedFact `elem` availableFacts runtime
          && "middleware ReportMiddleware begin" `elem` runtimeTrace runtime
          && "middleware ReportMiddleware end" `elem` runtimeTrace runtime ->
          putStrLn "[smoke] ok middleware runtime"
      | otherwise ->
          ioError
            ( userError
                ( "[smoke] failed middleware runtime: "
                    ++ show runtime
                )
            )
    RuntimeFailed actualError _ ->
      ioError
        ( userError
            ( "[smoke] failed middleware runtime: expected success, got "
                ++ show actualError
            )
        )

runMiddlewareFailureSmoke :: IO ()
runMiddlewareFailureSmoke = do
  putStrLn "[smoke] boundary middleware failure cleanup"
  result <- runRuntimeM defaultRuntimeEnv emptyRuntime (runHanging smokeMiddlewareFailureRuntime)
  case result of
    RuntimeFailed (RuntimeIoException "middleware target failed") runtime
      | runtimeMiddlewareStack runtime == []
          && runtimeMiddlewareEvents runtime
            == [ RuntimeMiddlewareEntered ReportMiddleware
               , RuntimeMiddlewareExited ReportMiddleware
               ] ->
          putStrLn "[smoke] ok middleware failure cleanup"
      | otherwise ->
          ioError
            ( userError
                ( "[smoke] failed middleware failure cleanup: "
                    ++ show runtime
                )
            )
    RuntimeFailed actualError _ ->
      ioError
        ( userError
            ( "[smoke] failed middleware failure cleanup: expected middleware target failure, got "
                ++ show actualError
            )
        )
    RuntimeSucceeded _ runtime ->
      ioError
        ( userError
            ( "[smoke] failed middleware failure cleanup: expected failure, got success "
                ++ show runtime
            )
        )

runCallbackTargetSmoke :: IO ()
runCallbackTargetSmoke = do
  putStrLn "[smoke] boundary callback target"
  let environment =
        withRuntimeCallbacks
          [ RuntimeCallback
              { runtimeCallbackTarget = Foo1
              , runtimeCallbackBody = programPlain (fact [Foo6Fact])
              }
          ]
          defaultRuntimeEnv
  result <- runRuntimeM environment emptyRuntime (programPlain smokeCallbackTarget)
  case result of
    RuntimeSucceeded _ runtime
      | Foo5Fact `elem` availableFacts runtime
          && Foo6Fact `elem` availableFacts runtime
          && runtimeCallbackEvents runtime
            == [ RuntimeCallbackTriggered Foo1
               , RuntimeCallbackCompleted Foo1
               ]
          && runtimeComponentEvents runtime
            == [ RuntimeComponentEntered Foo1
               , RuntimeComponentExited Foo1
               ] -> do
          putStrLn "[smoke] ok callback target"
    RuntimeSucceeded _ runtime ->
      ioError
        ( userError
            ( "[smoke] failed callback target: unexpected runtime "
                ++ show runtime
            )
        )
    RuntimeFailed actualError runtime ->
      ioError
        ( userError
            ( "[smoke] failed callback target: expected success, got "
                ++ show actualError
                ++ " with "
                ++ show runtime
            )
        )

runSuspenseRequestSmoke :: IO ()
runSuspenseRequestSmoke = do
  putStrLn "[smoke] boundary suspense request"
  firstResult <- runRuntimeM defaultRuntimeEnv emptyRuntime (programPlain smokeCallbackTarget)
  case firstResult of
    RuntimeSucceeded _ runtime -> do
      let currentHanging =
            Architecture.hanging
              [ Architecture.suspense Foo1
              ]
      secondResult <- runRuntimeM defaultRuntimeEnv runtime (runHanging currentHanging)
      case secondResult of
        RuntimeSucceeded _ nextRuntime
          | RuntimeSuspenseRequested Foo1 RuntimeComponentCompleted
              `elem` runtimeSuspenseEvents nextRuntime -> do
              putStrLn "[smoke] ok suspense request"
        RuntimeSucceeded _ nextRuntime ->
          ioError
            ( userError
                ( "[smoke] failed suspense request: unexpected runtime "
                    ++ show nextRuntime
                )
            )
        RuntimeFailed actualError nextRuntime ->
          ioError
            ( userError
                ( "[smoke] failed suspense request: expected success, got "
                    ++ show actualError
                    ++ " with "
                    ++ show nextRuntime
                )
            )
    RuntimeFailed actualError runtime ->
      ioError
        ( userError
            ( "[smoke] failed suspense request setup: expected success, got "
                ++ show actualError
                ++ " with "
                ++ show runtime
            )
        )

runSmoke :: String -> WorkflowComponent -> IO ()
runSmoke label workflow = do
  putStrLn ("[smoke] " ++ label)
  result <-
    try
      ( runRuntimeMOrThrow
          defaultRuntimeEnv
          emptyRuntime
          (gpreproWorkflow compileWorkflowEff interpretWorkflowEff runtimeAlgebra workflow)
      )
  case result of
    Right runtime ->
      putStrLn ("[smoke] ok " ++ show (availableFacts runtime))
    Left exception ->
      putStrLn ("[smoke] failed " ++ show (exception :: SomeException))

runExpectedRuntimeFailure :: String -> RuntimeError -> RuntimeWorkflowProgram -> IO ()
runExpectedRuntimeFailure label expectedError program =
  runExpectedRuntimeFailureWith label expectedError (const True) program

runExpectedRuntimeFailureWithTrace ::
  String ->
  RuntimeError ->
  String ->
  RuntimeWorkflowProgram ->
  IO ()
runExpectedRuntimeFailureWithTrace label expectedError expectedTrace =
  runExpectedRuntimeFailureWith label expectedError (elem expectedTrace . runtimeTrace)

runExpectedRuntimeFailureWith ::
  String ->
  RuntimeError ->
  (Runtime -> Bool) ->
  RuntimeWorkflowProgram ->
  IO ()
runExpectedRuntimeFailureWith label expectedError statePredicate program = do
  putStrLn ("[smoke] boundary " ++ label)
  result <- runRuntimeM defaultRuntimeEnv emptyRuntime program
  case result of
    RuntimeFailed actualError runtime
      | actualError == expectedError && statePredicate runtime ->
          putStrLn ("[smoke] ok " ++ label)
      | actualError == expectedError ->
          ioError (userError ("[smoke] failed " ++ label ++ ": trace/state predicate failed"))
      | otherwise ->
          ioError
            ( userError
                ( "[smoke] failed "
                    ++ label
                    ++ ": expected "
                    ++ show expectedError
                    ++ ", got "
                    ++ show actualError
                )
            )
    RuntimeSucceeded _ runtime ->
      ioError
        ( userError
            ( "[smoke] failed "
                ++ label
                ++ ": expected runtime error, got success "
                ++ show (availableFacts runtime)
            )
        )

runExpectedRuntimeTrace :: String -> String -> RuntimeWorkflowProgram -> IO ()
runExpectedRuntimeTrace label expectedTrace program = do
  putStrLn ("[smoke] boundary " ++ label)
  result <- runRuntimeM defaultRuntimeEnv emptyRuntime program
  case result of
    RuntimeSucceeded _ runtime
      | expectedTrace `elem` runtimeTrace runtime ->
          putStrLn ("[smoke] ok " ++ label)
      | otherwise ->
          ioError
            ( userError
                ( "[smoke] failed "
                    ++ label
                    ++ ": missing trace "
                    ++ show expectedTrace
                    ++ " in "
                    ++ show (runtimeTrace runtime)
                )
            )
    RuntimeFailed actualError _ ->
      ioError
        ( userError
            ( "[smoke] failed "
                ++ label
                ++ ": expected success, got "
                ++ show actualError
            )
        )

runExpectedRuntimeState :: String -> (Runtime -> Bool) -> RuntimeWorkflowProgram -> IO ()
runExpectedRuntimeState label statePredicate program = do
  putStrLn ("[smoke] boundary " ++ label)
  result <- runRuntimeM defaultRuntimeEnv emptyRuntime program
  case result of
    RuntimeSucceeded _ runtime
      | statePredicate runtime ->
          putStrLn ("[smoke] ok " ++ label)
      | otherwise ->
          ioError
            ( userError
                ( "[smoke] failed "
                    ++ label
                    ++ ": unexpected runtime "
                    ++ show runtime
                )
            )
    RuntimeFailed actualError _ ->
      ioError
        ( userError
            ( "[smoke] failed "
                ++ label
                ++ ": expected success, got "
                ++ show actualError
            )
        )

programPlain :: WorkflowComponent -> RuntimeWorkflowProgram
programPlain =
  gpreproWorkflow compileWorkflowEff interpretWorkflowEff runtimeAlgebra

programWithEffects :: EffectTheory -> WorkflowComponent -> RuntimeWorkflowProgram
programWithEffects =
  programWithEnvironment domainRuntimeEffectEnvironment

programWithEnvironment ::
  RuntimeEffectEnvironment ->
  EffectTheory ->
  WorkflowComponent ->
  RuntimeWorkflowProgram
programWithEnvironment environment effects =
  gpreproWorkflow
    compileWorkflowEff
    interpretWorkflowEff
    (contextwareWithEffectEnvironment environment effects runtimeAlgebra)

smokeFact :: Fact
smokeFact =
  fact [Foo5Fact]

smokeUserNameAsked :: Fact
smokeUserNameAsked =
  fact [UserNameAskedFact]

failingAskUserNameRegistry :: HandlerRegistry
failingAskUserNameRegistry =
  HandlerRegistry
    [ HandlerBinding AskUserName RuntimeAskUserName (RuntimeHandler (\_ _ _ -> pure (HandlerFailed "ask failed")))
    , HandlerBinding HandleUserNameError RuntimeHandleUserNameError (RuntimeHandler (\_ _ _ -> pure (HandlerSucceeded [])))
    ]

retryFailingAskUserNameRegistry :: HandlerRegistry
retryFailingAskUserNameRegistry =
  HandlerRegistry
    [ HandlerBinding AskUserName RuntimeAskUserName (RuntimeHandler (\_ _ _ -> pure (HandlerFailed "retry failed")))
    ]

mismatchedAskUserNameRegistry :: HandlerRegistry
mismatchedAskUserNameRegistry =
  HandlerRegistry
    [ HandlerBinding
        AskUserName
        RuntimeAskUserName
        (RuntimeHandler (\_ _ _ -> pure (HandlerSucceeded [RuntimeValue ReportOutput "wrong"])))
    , HandlerBinding HandleUserNameError RuntimeHandleUserNameError (RuntimeHandler (\_ _ _ -> pure (HandlerSucceeded [])))
    ]

valuePipelineRegistry :: HandlerRegistry
valuePipelineRegistry =
  HandlerRegistry
    [ HandlerBinding
        AskUserName
        RuntimeAskUserName
        (RuntimeHandler (\_ _ _ -> pure (HandlerSucceeded [RuntimeValue UserName "dune"])))
    , HandlerBinding
        RememberUser
        RuntimeRememberUser
        ( RuntimeHandler
            ( \_ input _ ->
                if RuntimeValue UserName "dune" `elem` handlerInputValues input
                  then pure (HandlerSucceeded [])
                  else pure (HandlerFailed "missing UserName input")
            )
        )
    ]

typedValuePipelineRegistry :: HandlerRegistry
typedValuePipelineRegistry =
  HandlerRegistry
    [ HandlerBinding
        AskUserName
        RuntimeAskUserName
        ( RuntimeHandler
            ( \_ _ _ ->
                pure
                  ( HandlerSucceededTyped
                      [SomeRuntimeValue (RuntimeTypedValue UserNameTag (UserNameValue "typed-dune"))]
                  )
            )
        )
    , HandlerBinding
        RememberUser
        RuntimeRememberUser
        ( RuntimeHandler
            ( \_ input _ ->
                if SomeRuntimeValue (RuntimeTypedValue UserNameTag (UserNameValue "typed-dune"))
                  `elem` handlerInputTypedValues input
                  then pure (HandlerSucceeded [])
                  else pure (HandlerFailed "missing typed UserName input")
            )
        )
    ]

retryUserNameTheory :: EffectTheory
retryUserNameTheory =
  theory
    [ EffectTheory.effect UserEffect
        [ EffectTheory.fact UserNameAskedFact
            [ EffectTheory.uses AskUserName
            ]
        , EffectTheory.externalMake AskUserName NoInput UserName
        , EffectTheory.idempotent AskUserName
        , EffectTheory.retry AskUserName
        ]
    ]

pipeOnlyTheory :: EffectTheory
pipeOnlyTheory =
  theory
    [ EffectTheory.effect UserEffect
        [ EffectTheory.fact UserNameAskedFact
            [ EffectTheory.uses AskUserName
            ]
        , EffectTheory.fact UserKnownFact
            [ EffectTheory.uses RememberUser
            ]
        , EffectTheory.externalMake AskUserName NoInput UserName
        , EffectTheory.externalMake RememberUser UserName Unit
        ]
    ]

internalTakeMakeTheory :: EffectTheory
internalTakeMakeTheory =
  theory
    [ EffectTheory.effect UserEffect
        [ EffectTheory.fact Foo5Fact
            [ EffectTheory.make UserName
            ]
        , EffectTheory.fact Foo6Fact
            [ EffectTheory.take UserName
            ]
        ]
    ]

externalTakeSignatureTheory :: EffectTheory
externalTakeSignatureTheory =
  theory
    [ EffectTheory.effect UserEffect
        [ EffectTheory.externalTake Foo5Fact UserName
        , EffectTheory.fact Foo6Fact
            [ EffectTheory.take UserName
            ]
        ]
    ]

transformPipelineTheory :: EffectTheory
transformPipelineTheory =
  theory
    [ EffectTheory.effect UserEffect
        [ EffectTheory.fact UserNameAskedFact
            [ EffectTheory.uses AskUserName
            ]
        , EffectTheory.fact Foo6Fact
            [ EffectTheory.transform UserName ReportInput UserNameToReportInput
            ]
        , EffectTheory.externalMake AskUserName NoInput UserName
        ]
    ]

smokeBlockedWait :: Wait
smokeBlockedWait =
  wait [Foo5Fact] (fact [Foo6Fact])

smokeOutOfOrderClaim :: Chain
smokeOutOfOrderClaim =
  chain Foo1
    [ fact [UserGreetedFact]
    , fact [UserNameAskedFact]
    ]

smokePipeOutOfOrderClaim :: Chain
smokePipeOutOfOrderClaim =
  chain Foo1
    [ fact [UserKnownFact]
    , fact [UserNameAskedFact]
    ]

smokeDuplicateUserNameClaim :: Chain
smokeDuplicateUserNameClaim =
  chain Foo1
    [ fact [UserNameAskedFact]
    , fact [UserNameAskedFact]
    ]

smokeInternalTakeMakeClaim :: Chain
smokeInternalTakeMakeClaim =
  chain Foo1
    [ fact [Foo6Fact]
    , fact [Foo5Fact]
    ]

smokeTransformOutOfOrderClaim :: Chain
smokeTransformOutOfOrderClaim =
  chain Foo1
    [ fact [Foo6Fact]
    , fact [UserNameAskedFact]
    ]

smokeChain :: Chain
smokeChain =
  chain Foo1
    [ fact [Foo5Fact]
    , fact [Foo6Fact]
    ]

smokeCallbackTarget :: Chain
smokeCallbackTarget =
  chain Foo1
    [ fact [Foo5Fact]
    ]

smokeWait :: Chain
smokeWait =
  chain Foo2
    [ fact [Foo5Fact]
    , wait [Foo5Fact] (fact [Foo6Fact])
    ]

smokeParallel :: Parallel
smokeParallel =
  parallel Foo3
    [ fact [AddCalculatedFact]
    , fact [FactorialCalculatedFact]
    , fact [SquaresCalculatedFact]
    ]

smokeFallback :: Fallback
smokeFallback =
  fallback
    [ wait [RuntimePreparedFact] (fact [Foo5Fact])
    , fact [Foo6Fact]
    ]

smokeChoice :: Choice
smokeChoice =
  choice
    (ChoiceKey "primary")
    [ (ChoiceKey "primary", fact [Foo5Fact])
    , (ChoiceKey "backup", fact [Foo6Fact])
    ]

smokeRace :: Race
smokeRace =
  race
    [ fact [Foo5Fact]
    , fact [Foo6Fact]
    ]

smokeHanging :: Hanging
smokeHanging =
  hanging
    [ callback Foo1 (fact [Foo6Fact])
    , suspense Foo1
    , middleware ReportMiddleware (fact [AddCalculatedFact])
    , loop (fact [SquaresCalculatedFact])
    ]

smokeMiddlewareRuntime ::
  Architecture.Hanging (Architecture.HangingAction WorkflowFact Interceptor RuntimeWorkflowProgram)
smokeMiddlewareRuntime =
  Architecture.hanging
    [ Architecture.middleware ReportMiddleware smokeMiddlewareBody
    ]

smokeMiddlewareFailureRuntime ::
  Architecture.Hanging (Architecture.HangingAction WorkflowFact Interceptor RuntimeWorkflowProgram)
smokeMiddlewareFailureRuntime =
  Architecture.hanging
    [ Architecture.middleware ReportMiddleware smokeMiddlewareFailureBody
    ]

smokeMiddlewareBody :: RuntimeWorkflowProgram
smokeMiddlewareBody = do
  runtime <- getRuntimeState
  if runtimeMiddlewareStack runtime == [ReportMiddleware]
    then programPlain (fact [AddCalculatedFact])
    else
      throwRuntimeError
        ( RuntimeIoException
            ( "middleware stack inactive: "
                ++ show (runtimeMiddlewareStack runtime)
            )
        )

smokeMiddlewareFailureBody :: RuntimeWorkflowProgram
smokeMiddlewareFailureBody = do
  runtime <- getRuntimeState
  if runtimeMiddlewareStack runtime == [ReportMiddleware]
    then
      throwRuntimeError (RuntimeIoException "middleware target failed")
    else
      throwRuntimeError
        ( RuntimeIoException
            ( "middleware stack inactive before failure: "
                ++ show (runtimeMiddlewareStack runtime)
            )
        )

factClaimStatus :: Runtime -> WorkflowFact -> Maybe RuntimeFactStatus
factClaimStatus runtime currentFact =
  case factClaimFor runtime currentFact of
    Just currentClaim ->
      Just (runtimeFactClaimStatus currentClaim)
    Nothing ->
      Nothing

factClaimFailure :: Runtime -> WorkflowFact -> Maybe RuntimeFactFailure
factClaimFailure runtime currentFact =
  case factClaimFor runtime currentFact of
    Just currentClaim ->
      runtimeFactClaimFailure currentClaim
    Nothing ->
      Nothing

factClaimFor :: Runtime -> WorkflowFact -> Maybe RuntimeFactClaim
factClaimFor runtime currentFact =
  firstJust
    [ Just currentClaim
    | currentClaim <- runtimeFactClaims runtime
    , runtimeFactClaimFact currentClaim == currentFact
    ]

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest

countOccurrences :: Eq item => item -> [item] -> Int
countOccurrences item =
  length . filter (== item)

typedUserNameText :: Runtime -> Maybe String
typedUserNameText runtime =
  case typedValueFor UserNameTag runtime of
    Just currentValue ->
      Just (runtimeTypedValueText currentValue)
    Nothing ->
      Nothing
