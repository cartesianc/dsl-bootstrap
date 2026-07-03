module Main
  ( main
  ) where

import Control.Concurrent
  ( MVar
  , newEmptyMVar
  , putMVar
  , takeMVar
  , threadDelay
  )
import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import System.Environment
  ( getArgs )
import System.Timeout
  ( timeout
  )

import qualified Bootstrap.Runtime as Native
import qualified Framework.Effect as E
import qualified Framework.Runtime as R
import Framework.Runtime.Concurrency
  ( RuntimeConcurrencyEvidencePayload
  , renderRuntimeConcurrencyEvidencePayload
  , renderRuntimeConcurrencyEvidencePayloadsJson
  , runtimeConcurrencyEvidencePayloadPassed
  , runtimeConcurrencyEvidencePayloads
  )
import qualified Framework.Workflow as W
import Framework.Workflow.Semantics
  ( WorkflowSemanticsEvidencePayload (..)
  , WorkflowSemanticsEvidenceStatus (..)
  , renderWorkflowSemanticsEvidencePayload
  , renderWorkflowSemanticsEvidencePayloadsJson
  , workflowSemanticsEvidencePayloadPassed
  )

main :: IO ()
main = do
  args <- getArgs
  payloads <- mapM runWorkflowSemanticsClaim workflowSemanticsClaims
  let concurrencyPayloads =
        runtimeConcurrencyEvidencePayloads payloads
      concurrencyFailures =
        filter (not . runtimeConcurrencyEvidencePayloadPassed) concurrencyPayloads
  let failures =
        filter (not . workflowSemanticsEvidencePayloadPassed) payloads
  case args of
    ["--json"] ->
      putStrLn (renderWorkflowSemanticsEvidencePayloadsJson payloads)
    ["--runtime-concurrency-json"] ->
      putStrLn (renderRuntimeConcurrencyEvidencePayloadsJson concurrencyPayloads)
    _ -> do
      putStrLn "[witness] workflow semantics evidence payloads"
      mapM_ putStrLn (concatMap renderPayloadBlock payloads)
      if null failures
        then putStrLn ("[witness] ok workflow semantics evidence " ++ show (length payloads) ++ " payload claims")
        else putStrLn ("[witness] failed workflow semantics evidence " ++ show (length failures) ++ " payload claims")
      putStrLn "[witness] runtime concurrency evidence payloads"
      mapM_ putStrLn (concatMap renderConcurrencyPayloadBlock concurrencyPayloads)
      if null concurrencyFailures
        then putStrLn ("[witness] ok runtime concurrency evidence " ++ show (length concurrencyPayloads) ++ " payload claims")
        else putStrLn ("[witness] failed runtime concurrency evidence " ++ show (length concurrencyFailures) ++ " payload claims")
  case failures ++ workflowFailuresFromConcurrency concurrencyFailures of
    [] ->
      pure ()
    failedPayloads ->
      ioError
        ( userError
            ( "workflow semantics evidence failed\n"
                ++ unlines (map workflowSemanticsEvidenceClaim failedPayloads)
            )
        )

data WorkflowSemanticsClaim = WorkflowSemanticsClaim
  { workflowSemanticsClaimName :: String
  , workflowSemanticsClaimExpected :: String
  , workflowSemanticsClaimObserved :: String
  , workflowSemanticsClaimArtifact :: String
  , workflowSemanticsClaimAction :: IO ()
  }

workflowSemanticsClaims :: [WorkflowSemanticsClaim]
workflowSemanticsClaims =
  [ WorkflowSemanticsClaim
      "workflow-parallel-concurrency"
      "parallel branches run concurrently and merge independent facts"
      "left and right branch facts are both available after parallel execution"
      "WorkflowParallelConcurrencyArtifact"
      parallelConcurrencyWitness
  , WorkflowSemanticsClaim
      "workflow-parallel-conflict"
      "parallel merge rejects conflicting writes to the same runtime value type"
      "RuntimeParallelMergeConflict is reported for shared output type"
      "WorkflowParallelConflictArtifact"
      parallelConflictWitness
  , WorkflowSemanticsClaim
      "workflow-race-cancellation"
      "race keeps the winning branch and excludes loser facts"
      "fast branch fact is available and slow branch fact is absent"
      "WorkflowRaceCancellationArtifact"
      raceCancellationWitness
  , WorkflowSemanticsClaim
      "workflow-race-exhausted"
      "race reports exhaustion when every branch fails"
      "RuntimeRaceExhausted is reported"
      "WorkflowRaceExhaustedArtifact"
      raceExhaustedWitness
  , WorkflowSemanticsClaim
      "workflow-fallback-isolation"
      "fallback isolates failed branch facts and claims"
      "success fact is available while failed fact and failed claim are absent"
      "WorkflowFallbackIsolationArtifact"
      fallbackIsolationWitness
  , WorkflowSemanticsClaim
      "workflow-choice-selected-branch"
      "choice executes only the selected branch"
      "selected fact is available and unselected fact is absent"
      "WorkflowChoiceSelectedBranchArtifact"
      choiceSelectedBranchWitness
  , WorkflowSemanticsClaim
      "workflow-fact-any-fallback"
      "factAny succeeds when one branch can produce the requested fact"
      "success fact is available and failed fact is absent"
      "WorkflowFactAnyFallbackArtifact"
      factAnyFallbackWitness
  , WorkflowSemanticsClaim
      "workflow-loop-fixed-point"
      "loop reaches a stable fixed point without duplicating facts forever"
      "loop fact is available and trace records loop fixed point"
      "WorkflowLoopFixedPointArtifact"
      loopFixedPointWitness
  , WorkflowSemanticsClaim
      "workflow-middleware-failure"
      "middleware entry and exit are recorded even when wrapped workflow fails"
      "middleware entered and exited events are both present"
      "WorkflowMiddlewareFailureArtifact"
      middlewareFailureWitness
  , WorkflowSemanticsClaim
      "workflow-suspense-snapshot"
      "suspense records target status and runtime snapshot"
      "suspense event carries completed target and rendered snapshot"
      "WorkflowSuspenseSnapshotArtifact"
      suspenseSnapshotWitness
  , WorkflowSemanticsClaim
      "workflow-callback-failure"
      "callback failure is recorded without erasing completed target flow"
      "callback failed event is present for target flow"
      "WorkflowCallbackFailureArtifact"
      callbackFailureWitness
  , WorkflowSemanticsClaim
      "workflow-native-framework-alignment"
      "native bootstrap runtime and framework runtime agree on final facts"
      "native and framework available facts render identically"
      "WorkflowNativeFrameworkAlignmentArtifact"
      nativeFrameworkAlignmentWitness
  , WorkflowSemanticsClaim
      "workflow-effect-system-boundary"
      "EffectSystemBoundary imports, private facts, and exports all participate in runtime execution"
      "import, private, and export facts are available while success facts remain exports"
      "WorkflowEffectSystemBoundaryArtifact"
      effectSystemBoundaryWitness
  ]

runWorkflowSemanticsClaim :: WorkflowSemanticsClaim -> IO WorkflowSemanticsEvidencePayload
runWorkflowSemanticsClaim currentClaim = do
  result <- try (workflowSemanticsClaimAction currentClaim)
  case result of
    Right () ->
      pure
        ( WorkflowSemanticsEvidencePayload
            { workflowSemanticsEvidenceClaim = workflowSemanticsClaimName currentClaim
            , workflowSemanticsEvidenceStatus = WorkflowSemanticsEvidencePassed
            , workflowSemanticsEvidenceExpected = workflowSemanticsClaimExpected currentClaim
            , workflowSemanticsEvidenceObserved = workflowSemanticsClaimObserved currentClaim
            , workflowSemanticsEvidenceArtifact = workflowSemanticsClaimArtifact currentClaim
            }
        )
    Left exception ->
      pure
        ( WorkflowSemanticsEvidencePayload
            { workflowSemanticsEvidenceClaim = workflowSemanticsClaimName currentClaim
            , workflowSemanticsEvidenceStatus = WorkflowSemanticsEvidenceFailed
            , workflowSemanticsEvidenceExpected = workflowSemanticsClaimExpected currentClaim
            , workflowSemanticsEvidenceObserved = displayException (exception :: SomeException)
            , workflowSemanticsEvidenceArtifact = workflowSemanticsClaimArtifact currentClaim
            }
        )

renderPayloadBlock :: WorkflowSemanticsEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderWorkflowSemanticsEvidencePayload payload)

renderConcurrencyPayloadBlock :: RuntimeConcurrencyEvidencePayload -> [String]
renderConcurrencyPayloadBlock payload =
  map ("  " ++) (renderRuntimeConcurrencyEvidencePayload payload)

workflowFailuresFromConcurrency :: [RuntimeConcurrencyEvidencePayload] -> [WorkflowSemanticsEvidencePayload]
workflowFailuresFromConcurrency [] =
  []
workflowFailuresFromConcurrency (_ : _) =
  [ WorkflowSemanticsEvidencePayload
      { workflowSemanticsEvidenceClaim = "runtime-concurrency-evidence"
      , workflowSemanticsEvidenceStatus = WorkflowSemanticsEvidenceFailed
      , workflowSemanticsEvidenceExpected = "runtime concurrency payloads derived from workflow semantics pass"
      , workflowSemanticsEvidenceObserved = "one or more runtime concurrency payloads failed"
      , workflowSemanticsEvidenceArtifact = "RuntimeConcurrencyEvidenceArtifact"
      }
  ]

parallelConcurrencyWitness :: IO ()
parallelConcurrencyWitness = do
  leftReady <- newEmptyMVar
  rightReady <- newEmptyMVar
  runtime <-
    runFrameworkSuccessWithTimeout
      "parallel concurrency"
      2000000
      ( frameworkEnvironment
          [ ( leftSend
            , synchronizedHandler leftReady rightReady leftType "left"
            )
          , ( rightSend
            , synchronizedHandler rightReady leftReady rightType "right"
            )
          ]
      )
      parallelBlueprint
      ( theory
          [ factUses leftFact leftSend
          , factUses rightFact rightSend
          , external leftSend leftType
          , external rightSend rightType
          ]
      )
  require "parallel left fact" (leftFact `elem` R.availableFacts runtime)
  require "parallel right fact" (rightFact `elem` R.availableFacts runtime)

parallelConflictWitness :: IO ()
parallelConflictWitness = do
  result <-
    R.runBlueprintWithEffectEnvironmentRuntimeResult
      ( frameworkEnvironment
          [ (leftSend, succeedHandler [value leftType "left", value sharedType "left-shared"])
          , (rightSend, succeedHandler [value rightType "right", value sharedType "right-shared"])
          ]
      )
      ( theory
          [ factUses leftFact leftSend
          , factUses rightFact rightSend
          , external leftSend leftType
          , external rightSend rightType
          ]
      )
      parallelBlueprint
  case result of
    R.RuntimeFailed (R.RuntimeParallelMergeConflict _) _ ->
      pure ()
    other ->
      failWitness "parallel conflict" (show other)

raceCancellationWitness :: IO ()
raceCancellationWitness = do
  slowStarted <- newEmptyMVar
  runtime <-
    runFrameworkSuccessWithTimeout
      "race cancellation"
      2000000
      ( frameworkEnvironment
          [ (slowSend, slowHandler slowStarted)
          , (fastSend, succeedHandler [value fastType "fast"])
          ]
      )
      raceBlueprint
      ( theory
          [ factUses slowFact slowSend
          , factUses fastFact fastSend
          , external slowSend slowType
          , external fastSend fastType
          ]
      )
  _ <- runWithTimeout "race slow branch started" 200000 (takeMVar slowStarted)
  require "race winner fact" (fastFact `elem` R.availableFacts runtime)
  require "race loser fact absent" (slowFact `notElem` R.availableFacts runtime)

raceExhaustedWitness :: IO ()
raceExhaustedWitness = do
  result <-
    R.runBlueprintWithEffectEnvironmentRuntimeResult
      ( frameworkEnvironment
          [ (leftSend, failHandler "left failed")
          , (rightSend, failHandler "right failed")
          ]
      )
      ( theory
          [ factUses leftFact leftSend
          , factUses rightFact rightSend
          , external leftSend leftType
          , external rightSend rightType
          ]
      )
      (blueprint (W.race [fact leftFact, fact rightFact]))
  case result of
    R.RuntimeFailed R.RuntimeRaceExhausted _ ->
      pure ()
    other ->
      failWitness "race exhausted" (show other)

fallbackIsolationWitness :: IO ()
fallbackIsolationWitness = do
  runtime <-
    runFrameworkSuccess
      "fallback isolation"
      ( frameworkEnvironment
          [ (failSend, failHandler "fallback branch failed")
          , (successSend, succeedHandler [value successType "success"])
          ]
      )
      (blueprint (W.fallback [fact failFact, fact successFact]))
      ( theory
          [ factUses failFact failSend
          , factUses successFact successSend
          , external failSend failType
          , external successSend successType
          ]
      )
  require "fallback success fact" (successFact `elem` R.availableFacts runtime)
  require "fallback failed fact absent" (failFact `notElem` R.availableFacts runtime)
  require "fallback failed claim absent" (not (any ((== failFact) . R.runtimeFactClaimFact) (R.runtimeFactClaims runtime)))

choiceSelectedBranchWitness :: IO ()
choiceSelectedBranchWitness = do
  runtime <-
    runFrameworkSuccess
      "choice selected branch"
      (frameworkEnvironment [])
      ( blueprint
          ( W.choice
              selectedChoice
              [ (unselectedChoice, fact unselectedFact)
              , (selectedChoice, fact selectedFact)
              ]
          )
      )
      (theory [factPure unselectedFact, factPure selectedFact])
  require "choice selected fact" (selectedFact `elem` R.availableFacts runtime)
  require "choice unselected fact absent" (unselectedFact `notElem` R.availableFacts runtime)

factAnyFallbackWitness :: IO ()
factAnyFallbackWitness = do
  runtime <-
    runFrameworkSuccess
      "factAny fallback"
      ( frameworkEnvironment
          [ (failSend, failHandler "any branch failed")
          , (successSend, succeedHandler [value successType "success"])
          ]
      )
      ( blueprint
          ( W.run
              ( W.effectSystem
                  (W.EffectSystemName "WorkflowSemanticsAnySystem")
                  (W.factAny [W.factItems [failFact], W.factItems [successFact]])
              )
          )
      )
      ( theory
          [ factUses failFact failSend
          , factUses successFact successSend
          , external failSend failType
          , external successSend successType
          ]
      )
  require "anyOf success fact" (successFact `elem` R.availableFacts runtime)
  require "anyOf failed fact absent" (failFact `notElem` R.availableFacts runtime)

loopFixedPointWitness :: IO ()
loopFixedPointWitness = do
  runtime <-
    runFrameworkSuccess
      "loop fixed point"
      (frameworkEnvironment [])
      ( W.AppBlueprint
          { W.blueprintApp = W.chain []
          , W.blueprintHanging = W.hanging [W.loop (fact loopFact)]
          }
      )
      (theory [factPure loopFact])
  require "loop fact" (loopFact `elem` R.availableFacts runtime)
  require "loop fixed point trace" ("[runtime] loop fixed point 2" `elem` R.runtimeTrace runtime)

middlewareFailureWitness :: IO ()
middlewareFailureWitness = do
  result <-
    R.runBlueprintWithEffectEnvironmentRuntimeResult
      (frameworkEnvironment [(failSend, failHandler "middleware failed")])
      (theory [factUses failFact failSend, external failSend failType])
      ( W.AppBlueprint
          { W.blueprintApp = W.chain []
          , W.blueprintHanging = W.hanging [W.middleware middlewareName (fact failFact)]
          }
      )
  case result of
    R.RuntimeFailed _ runtime -> do
      require
        "middleware entered"
        (R.RuntimeMiddlewareEntered middlewareName `elem` R.runtimeMiddlewareEvents runtime)
      require
        "middleware exited"
        (R.RuntimeMiddlewareExited middlewareName `elem` R.runtimeMiddlewareEvents runtime)
    other ->
      failWitness "middleware failure" (show other)

suspenseSnapshotWitness :: IO ()
suspenseSnapshotWitness = do
  runtime <-
    runFrameworkSuccess
      "suspense snapshot"
      (frameworkEnvironment [])
      ( W.AppBlueprint
          { W.blueprintApp = runFactAs targetFlow targetFact
          , W.blueprintHanging = W.hanging [W.suspense targetFlow]
          }
      )
      (theory [factPure targetFact])
  case R.runtimeSuspenseEvents runtime of
    [R.RuntimeSuspenseRequested target status snapshot] -> do
      require "suspense target" (target == targetFlow)
      require "suspense completed status" (status == R.RuntimeComponentCompleted)
      require "suspense snapshot fact" (targetFact `elem` R.snapshotAvailableFacts snapshot)
      require "suspense snapshot render" (not (null (R.renderRuntimeSnapshot snapshot)))
    other ->
      failWitness "suspense snapshot" (show other)

callbackFailureWitness :: IO ()
callbackFailureWitness = do
  runtime <-
    runFrameworkSuccess
      "callback failure"
      (frameworkEnvironment [(failSend, failHandler "callback failed")])
      ( W.AppBlueprint
          { W.blueprintApp = runFactAs targetFlow targetFact
          , W.blueprintHanging = W.hanging [W.callback targetFlow (fact failFact)]
          }
      )
      (theory [factPure targetFact, factUses failFact failSend, external failSend failType])
  require "callback failed event" (R.RuntimeCallbackFailed targetFlow `elem` R.runtimeCallbackEvents runtime)

nativeFrameworkAlignmentWitness :: IO ()
nativeFrameworkAlignmentWitness = do
  frameworkRuntime <-
    runFrameworkSuccess
      "framework alignment"
      (frameworkEnvironment [])
      alignmentBlueprint
      alignmentTheory
  nativeRuntimeResult <-
    Native.runNativeBlueprintWithEffectEnvironmentResult
      (Native.RuntimeEffectEnvironment (Native.HandlerRegistry []) (Native.TransformRegistry []))
      alignmentTheory
      alignmentBlueprint
  nativeRuntime <-
    case nativeRuntimeResult of
      Left message ->
        failWitness "native alignment" message
      Right runtime ->
        pure runtime
  require
    "native/framework facts align"
    (map show (R.availableFacts frameworkRuntime) == map show (Native.availableFacts nativeRuntime))

effectSystemBoundaryWitness :: IO ()
effectSystemBoundaryWitness = do
  let boundary =
        W.systemBoundary
          boundaryFlow
          [boundaryImportFact]
          [boundaryPrivateFact]
          [boundaryExportFact]
      system =
        W.effectSystemFromBoundary boundary
  runtime <-
    runFrameworkSuccess
      "effect system boundary"
      (frameworkEnvironment [])
      (blueprint (W.run system))
      (theory [factPure boundaryImportFact, factPure boundaryPrivateFact, factPure boundaryExportFact])
  require "boundary import fact" (boundaryImportFact `elem` R.availableFacts runtime)
  require "boundary private fact" (boundaryPrivateFact `elem` R.availableFacts runtime)
  require "boundary export fact" (boundaryExportFact `elem` R.availableFacts runtime)
  require "boundary success exports" (successFacts system == [boundaryExportFact])
  require "boundary runtime facts" (runtimeFacts system == [boundaryImportFact, boundaryPrivateFact, boundaryExportFact])

runFrameworkSuccess ::
  String ->
  R.RuntimeEffectEnvironment ->
  W.AppBlueprint ->
  E.EffectTheory ->
  IO R.Runtime
runFrameworkSuccess label environment appBlueprint effects = do
  result <- R.runBlueprintWithEffectEnvironmentRuntimeResult environment effects appBlueprint
  case result of
    R.RuntimeSucceeded runtime _ ->
      pure runtime
    R.RuntimeFailed errorReport runtime ->
      failWitness label (show errorReport ++ "\n" ++ unlines (R.runtimeTrace runtime))

runFrameworkSuccessWithTimeout ::
  String ->
  Int ->
  R.RuntimeEffectEnvironment ->
  W.AppBlueprint ->
  E.EffectTheory ->
  IO R.Runtime
runFrameworkSuccessWithTimeout label microseconds environment appBlueprint effects =
  runWithTimeout label microseconds (runFrameworkSuccess label environment appBlueprint effects)

runWithTimeout :: String -> Int -> IO value -> IO value
runWithTimeout label microseconds action = do
  result <- timeout microseconds action
  case result of
    Nothing ->
      failWitness label "timed out"
    Just resultValue ->
      pure resultValue

frameworkEnvironment :: [(E.SendName, R.RuntimeHandler)] -> R.RuntimeEffectEnvironment
frameworkEnvironment handlers =
  R.runtimeEffectEnvironment
    ( R.HandlerRegistry
        [ R.HandlerBinding currentSend (handlerName currentSend) currentHandler
        | (currentSend, currentHandler) <- handlers
        ]
    )

succeedHandler :: [R.RuntimeValue] -> R.RuntimeHandler
succeedHandler outputs =
  R.RuntimeHandler (\_ _ _ -> pure (R.HandlerSucceeded outputs))

failHandler :: String -> R.RuntimeHandler
failHandler message =
  R.RuntimeHandler (\_ _ _ -> pure (R.HandlerFailed message))

synchronizedHandler :: MVar () -> MVar () -> E.TypeName -> String -> R.RuntimeHandler
synchronizedHandler ownReady otherReady outputType outputText =
  R.RuntimeHandler $ \_ _ _ -> do
    putMVar ownReady ()
    _ <- takeMVar otherReady
    pure (R.HandlerSucceeded [value outputType outputText])

slowHandler :: MVar () -> R.RuntimeHandler
slowHandler started =
  R.RuntimeHandler $ \_ _ _ -> do
    putMVar started ()
    threadDelay 5000000
    pure (R.HandlerSucceeded [value slowType "slow"])

theory :: [E.EffectSection] -> E.EffectTheory
theory sections =
  E.theory [E.effect workflowSemanticsEffect sections]

factPure :: W.WorkflowFact -> E.EffectSection
factPure currentFact =
  E.fact currentFact ([] :: [E.ProducerStep])

factUses :: W.WorkflowFact -> E.SendName -> E.EffectSection
factUses currentFact currentSend =
  E.fact currentFact [E.uses currentSend]

external :: E.SendName -> E.TypeName -> E.EffectSection
external currentSend outputType =
  E.externalMake currentSend noInput outputType

blueprint :: W.App -> W.AppBlueprint
blueprint app =
  W.AppBlueprint
    { W.blueprintApp = app
    , W.blueprintHanging = W.hanging []
    }

fact :: W.WorkflowFact -> W.App
fact currentFact =
  runFactAs (W.EffectSystemName (show currentFact)) currentFact

runFactAs :: W.EffectSystemName -> W.WorkflowFact -> W.App
runFactAs name currentFact =
  W.run (W.effectSystem name (W.factItems [currentFact]))

successFacts :: W.EffectSystem W.WorkflowFact -> [W.WorkflowFact]
successFacts system =
  factExprFacts (W.effectSystemSuccess system)

runtimeFacts :: W.EffectSystem W.WorkflowFact -> [W.WorkflowFact]
runtimeFacts system =
  factExprFacts (W.effectSystemRuntimeFacts system)

factExprFacts :: W.FactExpr W.WorkflowFact -> [W.WorkflowFact]
factExprFacts expression =
  case expression of
    W.FactItems requirements ->
      W.requirementItems requirements
    W.FactAll expressions ->
      concatMap factExprFacts expressions
    W.FactAny expressions ->
      concatMap factExprFacts expressions

value :: E.TypeName -> String -> R.RuntimeValue
value currentType text =
  R.RuntimeValue currentType text

handlerName :: E.SendName -> E.HandlerName
handlerName currentSend =
  E.HandlerName ("WorkflowSemantics" ++ show currentSend ++ "Handler")

failWitness :: String -> String -> IO value
failWitness label details =
  ioError (userError ("[witness] failed " ++ label ++ ": " ++ details))

require :: String -> Bool -> IO ()
require _ True =
  pure ()
require label False =
  failWitness label "assertion failed"

parallelBlueprint :: W.AppBlueprint
parallelBlueprint =
  blueprint (W.parallel [fact leftFact, fact rightFact])

raceBlueprint :: W.AppBlueprint
raceBlueprint =
  blueprint (W.race [fact slowFact, fact fastFact])

alignmentBlueprint :: W.AppBlueprint
alignmentBlueprint =
  blueprint
    ( W.chain
        [ fact alignmentFirstFact
        , fact alignmentSecondFact
        ]
    )

alignmentTheory :: E.EffectTheory
alignmentTheory =
  theory
    [ factPure alignmentFirstFact
    , E.fact alignmentSecondFact [E.needs alignmentFirstFact]
    ]

workflowSemanticsEffect :: E.EffectName
workflowSemanticsEffect =
  E.EffectName "WorkflowSemanticsEffect"

noInput :: E.TypeName
noInput =
  E.TypeName "NoInput"

leftFact :: W.WorkflowFact
leftFact =
  W.WorkflowFact "WorkflowSemanticsLeftFact"

rightFact :: W.WorkflowFact
rightFact =
  W.WorkflowFact "WorkflowSemanticsRightFact"

slowFact :: W.WorkflowFact
slowFact =
  W.WorkflowFact "WorkflowSemanticsSlowFact"

fastFact :: W.WorkflowFact
fastFact =
  W.WorkflowFact "WorkflowSemanticsFastFact"

failFact :: W.WorkflowFact
failFact =
  W.WorkflowFact "WorkflowSemanticsFailFact"

successFact :: W.WorkflowFact
successFact =
  W.WorkflowFact "WorkflowSemanticsSuccessFact"

selectedFact :: W.WorkflowFact
selectedFact =
  W.WorkflowFact "WorkflowSemanticsSelectedFact"

unselectedFact :: W.WorkflowFact
unselectedFact =
  W.WorkflowFact "WorkflowSemanticsUnselectedFact"

loopFact :: W.WorkflowFact
loopFact =
  W.WorkflowFact "WorkflowSemanticsLoopFact"

targetFact :: W.WorkflowFact
targetFact =
  W.WorkflowFact "WorkflowSemanticsTargetFact"

alignmentFirstFact :: W.WorkflowFact
alignmentFirstFact =
  W.WorkflowFact "WorkflowSemanticsAlignmentFirstFact"

alignmentSecondFact :: W.WorkflowFact
alignmentSecondFact =
  W.WorkflowFact "WorkflowSemanticsAlignmentSecondFact"

leftSend :: E.SendName
leftSend =
  E.SendName "WorkflowSemanticsLeftSend"

rightSend :: E.SendName
rightSend =
  E.SendName "WorkflowSemanticsRightSend"

slowSend :: E.SendName
slowSend =
  E.SendName "WorkflowSemanticsSlowSend"

fastSend :: E.SendName
fastSend =
  E.SendName "WorkflowSemanticsFastSend"

failSend :: E.SendName
failSend =
  E.SendName "WorkflowSemanticsFailSend"

successSend :: E.SendName
successSend =
  E.SendName "WorkflowSemanticsSuccessSend"

leftType :: E.TypeName
leftType =
  E.TypeName "WorkflowSemanticsLeftType"

rightType :: E.TypeName
rightType =
  E.TypeName "WorkflowSemanticsRightType"

sharedType :: E.TypeName
sharedType =
  E.TypeName "WorkflowSemanticsSharedType"

slowType :: E.TypeName
slowType =
  E.TypeName "WorkflowSemanticsSlowType"

fastType :: E.TypeName
fastType =
  E.TypeName "WorkflowSemanticsFastType"

failType :: E.TypeName
failType =
  E.TypeName "WorkflowSemanticsFailType"

successType :: E.TypeName
successType =
  E.TypeName "WorkflowSemanticsSuccessType"

targetFlow :: W.EffectSystemName
targetFlow =
  W.EffectSystemName "WorkflowSemanticsTargetFlow"

boundaryFlow :: W.EffectSystemName
boundaryFlow =
  W.EffectSystemName "WorkflowSemanticsBoundaryFlow"

selectedChoice :: W.ChoiceKey
selectedChoice =
  W.ChoiceKey "selected"

unselectedChoice :: W.ChoiceKey
unselectedChoice =
  W.ChoiceKey "unselected"

middlewareName :: W.Interceptor
middlewareName =
  W.Interceptor "WorkflowSemanticsMiddleware"

boundaryImportFact :: W.WorkflowFact
boundaryImportFact =
  W.WorkflowFact "WorkflowSemanticsBoundaryImportFact"

boundaryPrivateFact :: W.WorkflowFact
boundaryPrivateFact =
  W.WorkflowFact "WorkflowSemanticsBoundaryPrivateFact"

boundaryExportFact :: W.WorkflowFact
boundaryExportFact =
  W.WorkflowFact "WorkflowSemanticsBoundaryExportFact"
