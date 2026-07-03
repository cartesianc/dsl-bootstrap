module Bootstrap.Runtime.Interpreter
  ( handlerFor
  , runNativeBlueprintWithEffectEnvironment
  , runNativeBlueprintWithEffectEnvironmentResult
  ) where

import Control.Concurrent
  ( MVar
  , ThreadId
  , forkIO
  , killThread
  , newEmptyMVar
  , putMVar
  , takeMVar
  )
import Control.Exception
  ( SomeException
  , try
  )

import Bootstrap.Effect
  ( EffectTheory
  , SendName
  , SendSignature (..)
  , TypeName
  )
import Bootstrap.Runtime.Build
  ( buildNativeApp
  , isPipeType
  , nativePlanPassed
  , renderNativePlanErrors
  , ruleFor
  , sendContractFor
  , sourceFactsForType
  )
import Bootstrap.Runtime.Types
import Bootstrap.Workflow
  ( AppBlueprint (..)
  , ChoiceKey (..)
  , FactExpr (..)
  , Workflow (..)
  , WorkflowFact
  , chainItems
  , choiceItems
  , fallbackItems
  , parallelItems
  , raceItems
  , requirementItems
  )
import qualified Bootstrap.Workflow as Workflow

data NativeBranchResult
  = NativeBranchSucceeded Int NativeRuntime
  | NativeBranchFailed Int String NativeRuntime

runNativeBlueprintWithEffectEnvironment :: RuntimeEffectEnvironment -> EffectTheory -> AppBlueprint -> IO ()
runNativeBlueprintWithEffectEnvironment environment effects blueprint = do
  result <- runNativeBlueprintWithEffectEnvironmentResult environment effects blueprint
  case result of
    Left message ->
      ioError (userError message)
    Right runtime ->
      mapM_ putStrLn (runtimeTrace runtime)

runNativeBlueprintWithEffectEnvironmentResult ::
  RuntimeEffectEnvironment ->
  EffectTheory ->
  AppBlueprint ->
  IO (Either String NativeRuntime)
runNativeBlueprintWithEffectEnvironmentResult environment effects blueprint =
  case buildNativeApp blueprint effects of
    Left message ->
      pure (Left message)
    Right plan
      | not (nativePlanPassed plan) ->
          pure (Left (renderNativePlanErrors plan))
      | otherwise -> do
          result <- runNativeWorkflow environment plan emptyNativeRuntime (blueprintApp blueprint)
          pure
            ( case result of
                Left message ->
                  Left message
                Right runtime ->
                  Right runtime
            )

handlerFor :: HandlerRegistry -> SendName -> Maybe HandlerBinding
handlerFor registry currentSend =
  firstJust
    [ Just binding
    | binding <- handlerRegistryBindings registry
    , handlerBindingSend binding == currentSend
    ]

runNativeWorkflow ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  Workflow.Workflow WorkflowFact Workflow.Interceptor ->
  IO (Either String NativeRuntime)
runNativeWorkflow environment plan runtime workflow =
  case workflow of
    RunWorkflow system ->
      runFactExpr
        environment
        plan
        (traceRuntime ("run " ++ show (Workflow.effectSystemName system)) runtime)
        (Workflow.effectSystemSuccess system)
    ChainWorkflow steps ->
      runSequential environment plan (traceRuntime "chain" runtime) (chainItems steps)
    ParallelWorkflow branches ->
      runNativeParallel environment plan (traceRuntime "parallel" runtime) (parallelItems branches)
    FallbackWorkflow branches ->
      runNativeFallback environment plan runtime (fallbackItems branches)
    RaceWorkflow branches ->
      runNativeRace environment plan runtime (raceItems branches)
    ChoiceWorkflow selectedKey branches ->
      runNativeChoice environment plan runtime selectedKey (choiceItems branches)
    WaitWorkflow wait body -> do
      waited <- runFactExpr environment plan runtime (Workflow.waitFacts wait)
      case waited of
        Left message ->
          pure (Left message)
        Right waitedRuntime ->
          runNativeWorkflow environment plan waitedRuntime body

runSequential ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [Workflow.Workflow WorkflowFact Workflow.Interceptor] ->
  IO (Either String NativeRuntime)
runSequential _ _ runtime [] =
  pure (Right runtime)
runSequential environment plan runtime (workflow : rest) = do
  result <- runNativeWorkflow environment plan runtime workflow
  case result of
    Left message ->
      pure (Left message)
    Right nextRuntime ->
      runSequential environment plan nextRuntime rest

runNativeParallel ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [Workflow.Workflow WorkflowFact Workflow.Interceptor] ->
  IO (Either String NativeRuntime)
runNativeParallel environment plan runtime branches = do
  results <- runNativeParallelBranches environment plan runtime (zip [0 ..] branches)
  case firstNativeBranchFailure results of
    Just (index, message, failedRuntime) ->
      pure (Left ("parallel branch " ++ show index ++ " failed: " ++ message ++ "\n" ++ joinLines (runtimeTrace failedRuntime)))
    Nothing ->
      pure (mergeNativeParallelRuntimes runtime (nativeBranchSuccessRuntimesInOrder (length branches) results))

runNativeFallback ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [Workflow.Workflow WorkflowFact Workflow.Interceptor] ->
  IO (Either String NativeRuntime)
runNativeFallback _ _ _ [] =
  pure (Left "fallback exhausted")
runNativeFallback environment plan runtime (branch : rest) = do
  result <- runNativeWorkflow environment plan runtime branch
  case result of
    Right nextRuntime ->
      pure (Right nextRuntime)
    Left _ ->
      runNativeFallback environment plan runtime rest

runNativeRace ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [Workflow.Workflow WorkflowFact Workflow.Interceptor] ->
  IO (Either String NativeRuntime)
runNativeRace _ _ _ [] =
  pure (Left "race empty")
runNativeRace environment plan runtime branches = do
  result <- runNativeRaceBranches environment plan runtime (zip [0 ..] branches)
  case result of
    Just winnerRuntime ->
      pure (Right winnerRuntime)
    Nothing ->
      pure (Left "race exhausted")

runNativeChoice ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  ChoiceKey ->
  [(ChoiceKey, Workflow.Workflow WorkflowFact Workflow.Interceptor)] ->
  IO (Either String NativeRuntime)
runNativeChoice environment plan runtime selectedKey branches =
  case firstJust (map selectedBranch branches) of
    Just branch ->
      runNativeWorkflow environment plan runtime branch
    Nothing ->
      pure (Left ("missing choice branch " ++ choiceKeyText selectedKey))
  where
    selectedBranch (currentKey, branch)
      | currentKey == selectedKey =
          Just branch
      | otherwise =
          Nothing

runFactAny ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [FactExpr WorkflowFact] ->
  IO (Either String NativeRuntime)
runFactAny _ _ _ [] =
  pure (Left "anyOf could not be satisfied")
runFactAny environment plan runtime (expression : rest) = do
  result <- runFactExpr environment plan runtime expression
  case result of
    Right nextRuntime ->
      pure (Right nextRuntime)
    Left _ ->
      runFactAny environment plan runtime rest

runNativeParallelBranches ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [(Int, Workflow.Workflow WorkflowFact Workflow.Interceptor)] ->
  IO [NativeBranchResult]
runNativeParallelBranches environment plan runtime branches = do
  resultVars <- mapM (forkNativeWorkflowBranch environment plan runtime) branches
  mapM takeMVar resultVars

runNativeRaceBranches ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [(Int, Workflow.Workflow WorkflowFact Workflow.Interceptor)] ->
  IO (Maybe NativeRuntime)
runNativeRaceBranches environment plan runtime branches = do
  resultVar <- newEmptyMVar
  threadIds <- mapM (forkRaceNativeWorkflowBranch environment plan runtime resultVar) branches
  waitForNativeRaceWinner (length branches) 0 threadIds resultVar

forkNativeWorkflowBranch ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  (Int, Workflow.Workflow WorkflowFact Workflow.Interceptor) ->
  IO (MVar NativeBranchResult)
forkNativeWorkflowBranch environment plan runtime branch = do
  resultVar <- newEmptyMVar
  _ <- forkNativeWorkflowBranchInto environment plan runtime resultVar branch
  pure resultVar

forkRaceNativeWorkflowBranch ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  MVar NativeBranchResult ->
  (Int, Workflow.Workflow WorkflowFact Workflow.Interceptor) ->
  IO (Int, ThreadId)
forkRaceNativeWorkflowBranch environment plan runtime resultVar branch@(index, _) = do
  threadId <- forkNativeWorkflowBranchInto environment plan runtime resultVar branch
  pure (index, threadId)

forkNativeWorkflowBranchInto ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  MVar NativeBranchResult ->
  (Int, Workflow.Workflow WorkflowFact Workflow.Interceptor) ->
  IO ThreadId
forkNativeWorkflowBranchInto environment plan runtime resultVar (index, branch) =
  forkIO $ do
    result <- tryNativeBranch (runNativeWorkflow environment plan runtime branch)
    putMVar resultVar (nativeBranchResultFromEither index runtime result)

tryNativeBranch :: IO (Either String NativeRuntime) -> IO (Either SomeException (Either String NativeRuntime))
tryNativeBranch =
  try

nativeBranchResultFromEither ::
  Int ->
  NativeRuntime ->
  Either SomeException (Either String NativeRuntime) ->
  NativeBranchResult
nativeBranchResultFromEither index runtime result =
  case result of
    Left exception ->
      NativeBranchFailed index (show exception) runtime
    Right (Left message) ->
      NativeBranchFailed index message runtime
    Right (Right nextRuntime) ->
      NativeBranchSucceeded index nextRuntime

waitForNativeRaceWinner ::
  Int ->
  Int ->
  [(Int, ThreadId)] ->
  MVar NativeBranchResult ->
  IO (Maybe NativeRuntime)
waitForNativeRaceWinner totalBranches failedCount threadIds resultVar = do
  result <- takeMVar resultVar
  case result of
    NativeBranchSucceeded winnerIndex winnerRuntime -> do
      killNativeRaceLosers winnerIndex threadIds
      pure (Just winnerRuntime)
    NativeBranchFailed _ _ _ ->
      if failedCount + 1 >= totalBranches
        then pure Nothing
        else waitForNativeRaceWinner totalBranches (failedCount + 1) threadIds resultVar

killNativeRaceLosers :: Int -> [(Int, ThreadId)] -> IO ()
killNativeRaceLosers winnerIndex threadIds =
  mapM_ killThread
    [ threadId
    | (index, threadId) <- threadIds
    , index /= winnerIndex
    ]

firstNativeBranchFailure :: [NativeBranchResult] -> Maybe (Int, String, NativeRuntime)
firstNativeBranchFailure results =
  firstJust
    [ nativeBranchFailureFor index results
    | index <- [0 .. length results - 1]
    ]

nativeBranchFailureFor :: Int -> [NativeBranchResult] -> Maybe (Int, String, NativeRuntime)
nativeBranchFailureFor _ [] =
  Nothing
nativeBranchFailureFor expectedIndex (result : rest) =
  case result of
    NativeBranchFailed index message runtime
      | index == expectedIndex ->
          Just (index, message, runtime)
    _ ->
      nativeBranchFailureFor expectedIndex rest

nativeBranchSuccessRuntimesInOrder :: Int -> [NativeBranchResult] -> [NativeRuntime]
nativeBranchSuccessRuntimesInOrder branchCount results =
  [ runtime
  | index <- [0 .. branchCount - 1]
  , Just runtime <- [nativeBranchSuccessFor index results]
  ]

nativeBranchSuccessFor :: Int -> [NativeBranchResult] -> Maybe NativeRuntime
nativeBranchSuccessFor _ [] =
  Nothing
nativeBranchSuccessFor expectedIndex (result : rest) =
  case result of
    NativeBranchSucceeded index runtime
      | index == expectedIndex ->
          Just runtime
    _ ->
      nativeBranchSuccessFor expectedIndex rest

mergeNativeParallelRuntimes :: NativeRuntime -> [NativeRuntime] -> Either String NativeRuntime
mergeNativeParallelRuntimes baseRuntime =
  mergeNativeParallelRuntimesFrom baseRuntime baseRuntime

mergeNativeParallelRuntimesFrom :: NativeRuntime -> NativeRuntime -> [NativeRuntime] -> Either String NativeRuntime
mergeNativeParallelRuntimesFrom _ mergedRuntime [] =
  Right mergedRuntime
mergeNativeParallelRuntimesFrom baseRuntime mergedRuntime (branchRuntime : rest) =
  case mergeNativeParallelRuntime baseRuntime mergedRuntime branchRuntime of
    Left message ->
      Left message
    Right nextRuntime ->
      mergeNativeParallelRuntimesFrom baseRuntime nextRuntime rest

mergeNativeParallelRuntime :: NativeRuntime -> NativeRuntime -> NativeRuntime -> Either String NativeRuntime
mergeNativeParallelRuntime baseRuntime mergedRuntime branchRuntime = do
  mergedArtifacts <- mergeRuntimeArtifactsChecked (runtimeArtifacts mergedRuntime) (runtimeArtifacts branchRuntime)
  pure
    mergedRuntime
      { availableFacts = unique (availableFacts mergedRuntime ++ availableFacts branchRuntime)
      , runtimeArtifacts = mergedArtifacts
      , runtimeTrace = runtimeTrace mergedRuntime ++ listDelta (runtimeTrace baseRuntime) (runtimeTrace branchRuntime)
      , runtimeFailures = runtimeFailures mergedRuntime ++ listDelta (runtimeFailures baseRuntime) (runtimeFailures branchRuntime)
      }

mergeRuntimeArtifactsChecked :: [RuntimeArtifact] -> [RuntimeArtifact] -> Either String [RuntimeArtifact]
mergeRuntimeArtifactsChecked =
  foldlEither mergeRuntimeArtifactChecked

mergeRuntimeArtifactChecked :: [RuntimeArtifact] -> RuntimeArtifact -> Either String [RuntimeArtifact]
mergeRuntimeArtifactChecked [] artifact =
  Right [artifact]
mergeRuntimeArtifactChecked (existing : rest) artifact
  | artifactType existing == artifactType artifact =
      if existing == artifact
        then Right (existing : rest)
        else Left ("runtime artifact conflict for " ++ show (artifactType artifact))
  | otherwise =
      case mergeRuntimeArtifactChecked rest artifact of
        Left message ->
          Left message
        Right mergedRest ->
          Right (existing : mergedRest)

foldlEither :: (accumulator -> item -> Either error accumulator) -> accumulator -> [item] -> Either error accumulator
foldlEither _ accumulator [] =
  Right accumulator
foldlEither step accumulator (item : rest) =
  case step accumulator item of
    Left errorReport ->
      Left errorReport
    Right nextAccumulator ->
      foldlEither step nextAccumulator rest

listDelta :: Eq item => [item] -> [item] -> [item]
listDelta prefix items =
  case stripListPrefix prefix items of
    Just rest ->
      rest
    Nothing ->
      items

stripListPrefix :: Eq item => [item] -> [item] -> Maybe [item]
stripListPrefix [] items =
  Just items
stripListPrefix (_ : _) [] =
  Nothing
stripListPrefix (prefixItem : prefixRest) (item : rest)
  | prefixItem == item =
      stripListPrefix prefixRest rest
  | otherwise =
      Nothing

choiceKeyText :: ChoiceKey -> String
choiceKeyText (ChoiceKey text) =
  text

runFactExpr ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  FactExpr WorkflowFact ->
  IO (Either String NativeRuntime)
runFactExpr environment plan runtime expression =
  case expression of
    FactItems requirements ->
      ensureFacts environment plan runtime (requirementItems requirements)
    FactAll expressions ->
      runFactExprs environment plan runtime expressions
    FactAny [] ->
      pure (Left "empty factAny cannot be satisfied")
    FactAny expressions ->
      runFactAny environment plan runtime expressions

runFactExprs ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [FactExpr WorkflowFact] ->
  IO (Either String NativeRuntime)
runFactExprs _ _ runtime [] =
  pure (Right runtime)
runFactExprs environment plan runtime (expression : rest) = do
  result <- runFactExpr environment plan runtime expression
  case result of
    Left message ->
      pure (Left message)
    Right nextRuntime ->
      runFactExprs environment plan nextRuntime rest

ensureFacts ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [WorkflowFact] ->
  IO (Either String NativeRuntime)
ensureFacts _ _ runtime [] =
  pure (Right runtime)
ensureFacts environment plan runtime (currentFact : rest) = do
  result <- ensureFact environment plan runtime [] currentFact
  case result of
    Left message ->
      pure (Left message)
    Right nextRuntime ->
      ensureFacts environment plan nextRuntime rest

ensureFact ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [WorkflowFact] ->
  WorkflowFact ->
  IO (Either String NativeRuntime)
ensureFact environment plan runtime stack currentFact
  | currentFact `elem` availableFacts runtime =
      pure (Right runtime)
  | currentFact `elem` stack =
      pure (Left ("fact dependency cycle: " ++ show (reverse (currentFact : stack))))
  | otherwise =
      case ruleFor plan currentFact of
        Nothing ->
          pure (Left ("missing native fact rule for " ++ show currentFact))
        Just rule -> do
          dependencies <- ensureRuleDependencies environment plan runtime (currentFact : stack) rule
          case dependencies of
            Left message ->
              pure (Left message)
            Right dependencyRuntime -> do
              sendResult <- runRuleSends environment plan dependencyRuntime rule
              case sendResult of
                Left message ->
                  pure (Left message)
                Right sentRuntime ->
                  pure (Right (markRuleSucceeded rule sentRuntime))

ensureRuleDependencies ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [WorkflowFact] ->
  NativeFactRule ->
  IO (Either String NativeRuntime)
ensureRuleDependencies environment plan runtime stack rule = do
  needed <- ensureFactsWithStack environment plan runtime stack (nativeRuleNeeds rule)
  case needed of
    Left message ->
      pure (Left message)
    Right neededRuntime ->
      ensureTakes environment plan neededRuntime stack rule

ensureFactsWithStack ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  IO (Either String NativeRuntime)
ensureFactsWithStack _ _ runtime _ [] =
  pure (Right runtime)
ensureFactsWithStack environment plan runtime stack (currentFact : rest) = do
  result <- ensureFact environment plan runtime stack currentFact
  case result of
    Left message ->
      pure (Left message)
    Right nextRuntime ->
      ensureFactsWithStack environment plan nextRuntime stack rest

ensureTakes ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [WorkflowFact] ->
  NativeFactRule ->
  IO (Either String NativeRuntime)
ensureTakes _ _ runtime _ rule
  | all (`artifactAvailable` runtime) nativeTakes =
      pure (Right runtime)
  where
    nativeTakes =
      filter isPipeType (nativeRuleTakes rule)
ensureTakes environment plan runtime stack rule =
  ensureTakeTypes environment plan runtime stack (filter isPipeType (nativeRuleTakes rule))

ensureTakeTypes ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [WorkflowFact] ->
  [TypeName] ->
  IO (Either String NativeRuntime)
ensureTakeTypes _ _ runtime _ [] =
  pure (Right runtime)
ensureTakeTypes environment plan runtime stack (currentType : rest)
  | artifactAvailable currentType runtime =
      ensureTakeTypes environment plan runtime stack rest
  | otherwise =
      case sourceFactsForType plan currentType of
        [] ->
          pure (Left ("missing producer for pipe type " ++ show currentType))
        [sourceFact] -> do
          result <- ensureFact environment plan runtime stack sourceFact
          case result of
            Left message ->
              pure (Left message)
            Right nextRuntime ->
              ensureTakeTypes environment plan nextRuntime stack rest
        sources ->
          pure (Left ("duplicate producers for pipe type " ++ show currentType ++ ": " ++ show sources))

runRuleSends ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  NativeFactRule ->
  IO (Either String NativeRuntime)
runRuleSends _ _ runtime rule
  | null (nativeRuleUses rule) =
      pure (Right runtime)
runRuleSends environment plan runtime rule =
  runSends environment plan runtime (nativeRuleUses rule)

runSends ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [SendName] ->
  IO (Either String NativeRuntime)
runSends _ _ runtime [] =
  pure (Right runtime)
runSends environment plan runtime (currentSend : rest) =
  case sendContractFor plan currentSend of
    Nothing ->
      pure (Left ("missing send boundary for " ++ show currentSend))
    Just contract ->
      case handlerFor (runtimeEffectHandlers environment) currentSend of
        Nothing ->
          pure (Left ("missing native handler for " ++ show currentSend))
        Just binding -> do
          let inputArtifacts =
                handlerInputArtifacts runtime (sendInput (sendContractSignature contract))
          result <-
            runNativeHandler
              (handlerBindingHandler binding)
              currentSend
              inputArtifacts
              runtime
          case result of
            HandlerFailed message ->
              pure (Left ("native handler failed for " ++ show currentSend ++ ": " ++ message))
            HandlerSucceeded outputs ->
              let nextRuntime =
                    traceRuntime ("externalMake " ++ show currentSend ++ " using " ++ show (handlerBindingName binding))
                      (recordArtifacts outputs runtime)
               in runSends environment plan nextRuntime rest

handlerInputArtifacts :: NativeRuntime -> TypeName -> [RuntimeArtifact]
handlerInputArtifacts runtime inputType
  | not (isPipeType inputType) =
      []
  | otherwise =
      [ artifact
      | artifact <- runtimeArtifacts runtime
      , artifactType artifact == inputType
      ]

markRuleSucceeded :: NativeFactRule -> NativeRuntime -> NativeRuntime
markRuleSucceeded rule =
  markFact (nativeRuleFact rule)
    . recordArtifacts
      [ RuntimeArtifact currentType ("produced by " ++ show (nativeRuleFact rule))
      | currentType <- nativeRuleMakes rule
      , isPipeType currentType
      ]

markFact :: WorkflowFact -> NativeRuntime -> NativeRuntime
markFact currentFact runtime =
  traceRuntime ("fact [" ++ show currentFact ++ "]") runtime
    { availableFacts = unique (availableFacts runtime ++ [currentFact])
    }

recordArtifacts :: [RuntimeArtifact] -> NativeRuntime -> NativeRuntime
recordArtifacts artifacts runtime =
  runtime {runtimeArtifacts = foldl upsertArtifact (runtimeArtifacts runtime) artifacts}

traceRuntime :: String -> NativeRuntime -> NativeRuntime
traceRuntime message runtime =
  runtime {runtimeTrace = runtimeTrace runtime ++ ["[native-runtime] " ++ message]}

emptyNativeRuntime :: NativeRuntime
emptyNativeRuntime =
  NativeRuntime [] [] [] []

artifactAvailable :: TypeName -> NativeRuntime -> Bool
artifactAvailable currentType runtime =
  any ((== currentType) . artifactType) (runtimeArtifacts runtime)

upsertArtifact :: [RuntimeArtifact] -> RuntimeArtifact -> [RuntimeArtifact]
upsertArtifact [] artifact =
  [artifact]
upsertArtifact (existing : rest) artifact
  | artifactType existing == artifactType artifact =
      artifact : rest
  | otherwise =
      existing : upsertArtifact rest artifact

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest

unique :: Eq item => [item] -> [item]
unique =
  foldl appendUnique []

appendUnique :: Eq item => [item] -> item -> [item]
appendUnique items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

joinLines :: [String] -> String
joinLines [] =
  ""
joinLines [line] =
  line
joinLines (line : rest) =
  line ++ "\n" ++ joinLines rest
