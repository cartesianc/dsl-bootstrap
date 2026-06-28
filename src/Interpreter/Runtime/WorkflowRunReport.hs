module Interpreter.Runtime.WorkflowRunReport
  ( WorkflowRunReport (..)
  , printBlueprintRunReport
  , printWorkflowRunReport
  , blueprintRunReport
  , workflowRunReport
  ) where

import AST.AppBlueprint
  ( AppBlueprint (..)
  )
import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Architecture
import Core.Architecture.Cata
  ( WorkflowAlgebra (..)
  , cataWorkflow
  )
import Core.Architecture.Internal
  ( ChoiceBranch (..)
  , FreeAlternative (..)
  , FreeApplicative (..)
  , FreeChoice (..)
  , FreeMonad (..)
  , RequirementEffect (..)
  )

data WorkflowRunReport = WorkflowRunReport
  { runSucceeded :: Bool
  , runFinalFacts :: [WorkflowFact]
  , runTrace :: [String]
  }

data RenderState = RenderState
  { renderFacts :: [WorkflowFact]
  , renderLines :: [String]
  , renderDepth :: Int
  }

data RenderResult = RenderResult
  { resultState :: RenderState
  , resultFailure :: Maybe String
  }

type WorkflowRunProgram = RenderState -> IO RenderResult

blueprintRunReport :: AppBlueprint -> IO WorkflowRunReport
blueprintRunReport =
  workflowRunReport . blueprintApp

workflowRunReport :: Workflow WorkflowFact hook -> IO WorkflowRunReport
workflowRunReport workflow = do
  result <- cataWorkflow workflowRunReportAlgebra workflow emptyRenderState
  pure (reportFromResult result)

printBlueprintRunReport :: AppBlueprint -> IO ()
printBlueprintRunReport blueprint =
  blueprintRunReport blueprint >>= printReport

printWorkflowRunReport :: Workflow WorkflowFact hook -> IO ()
printWorkflowRunReport workflow =
  workflowRunReport workflow >>= printReport

workflowRunReportAlgebra :: WorkflowAlgebra WorkflowFact WorkflowRunProgram
workflowRunReportAlgebra =
  WorkflowAlgebra
    { onFact = renderFact
    , onChain = renderChain
    , onParallel = renderParallel
    , onFallback = renderFallback
    , onRace = renderRace
    , onChoice = renderChoice
    , onWait = renderWait
    }

emptyRenderState :: RenderState
emptyRenderState =
  RenderState
    { renderFacts = []
    , renderLines = []
    , renderDepth = 0
    }

reportFromResult :: RenderResult -> WorkflowRunReport
reportFromResult result =
  WorkflowRunReport
    { runSucceeded = resultFailure result == Nothing
    , runFinalFacts = renderFacts (resultState result)
    , runTrace = renderLines (resultState result)
    }

printReport :: WorkflowRunReport -> IO ()
printReport report = do
  putStrLn ("workflow-run: " ++ renderStatus (runSucceeded report))
  putStrLn ("facts: " ++ show (runFinalFacts report))
  putStrLn "trace:"
  mapM_ putStrLn (runTrace report)

renderStatus :: Bool -> String
renderStatus True =
  "success"
renderStatus False =
  "failed"

renderFact :: Fact WorkflowFact -> WorkflowRunProgram
renderFact currentFact state =
  pure (succeed (recordFacts currentFact state))

renderChain :: WorkflowName -> Chain WorkflowRunProgram -> WorkflowRunProgram
renderChain label steps state = do
  let startDepth = renderDepth state
      start = descend (line ("chain " ++ show label ++ " begin") state)
  result <- runChain start (freeMonadSteps (chainSteps steps))
  pure (finishNode startDepth ("chain " ++ show label) result)

renderParallel :: WorkflowName -> Parallel WorkflowRunProgram -> WorkflowRunProgram
renderParallel label branches state = do
  let branchEffects = freeApplicativeBranches (parallelBranches branches)
      startDepth = renderDepth state
      start = line ("parallel " ++ show label ++ " fork " ++ show (length branchEffects)) state
  branchResults <- mapM (runParallelBranch start) (zip [(1 :: Int) ..] branchEffects)
  pure (finishParallel startDepth label start branchResults)

renderFallback :: Fallback WorkflowRunProgram -> WorkflowRunProgram
renderFallback branches state = do
  let startDepth = renderDepth state
      start = descend (line "fallback begin" state)
  result <- runFallback start (freeAlternativeBranches (fallbackBranches branches))
  pure (finishNode startDepth "fallback" result)

renderRace :: Race WorkflowRunProgram -> WorkflowRunProgram
renderRace branches state = do
  let branchEffects = freeAlternativeBranches (raceBranches branches)
      startDepth = renderDepth state
      start = line ("race fork " ++ show (length branchEffects)) state
  branchResults <- mapM (runRaceBranch start) (zip [(1 :: Int) ..] branchEffects)
  pure (finishRace startDepth start branchResults)

renderChoice :: ChoiceKey -> Choice WorkflowRunProgram -> WorkflowRunProgram
renderChoice selectedKey choices state =
  runChoice selectedKey (freeChoiceBranches (choiceBranches choices)) (descend (line ("choice " ++ renderChoiceKey selectedKey) state))

renderWait :: Wait WorkflowFact -> WorkflowRunProgram -> WorkflowRunProgram
renderWait currentWait body state
  | factExprAvailable (renderFacts state) (waitFacts currentWait) = do
      let startDepth = renderDepth state
          start = descend (line ("wait ok " ++ renderFactExpr (waitFacts currentWait)) state)
      result <- body start
      pure (finishNode startDepth "wait body" result)
  | otherwise =
      pure (failWith ("wait blocked " ++ renderFactExpr (waitFacts currentWait)) state)

runChain :: RenderState -> [WorkflowRunProgram] -> IO RenderResult
runChain state [] =
  pure (succeed state)
runChain state (step : rest) = do
  result <- step state
  case resultFailure result of
    Nothing ->
      runChain (resultState result) rest
    Just _ ->
      pure result

runParallelBranch ::
  RenderState ->
  (Int, WorkflowRunProgram) ->
  IO RenderResult
runParallelBranch start (branchIndex, branch) =
  branch (descend (line ("branch " ++ show branchIndex ++ " begin") start))

finishParallel ::
  Int ->
  WorkflowName ->
  RenderState ->
  [RenderResult] ->
  RenderResult
finishParallel startDepth label start branchResults =
  case firstFailure branchResults of
    Just failure ->
      failResult (line ("parallel " ++ show label ++ " failed: " ++ failure) (restoreDepth startDepth (mergeBranchLogs start branchResults))) failure
    Nothing ->
      succeed (line ("parallel " ++ show label ++ " join ok") (restoreDepth startDepth (mergeBranchFacts start branchResults)))

runFallback :: RenderState -> [WorkflowRunProgram] -> IO RenderResult
runFallback state [] =
  pure (failWith "fallback has no successful branch" state)
runFallback state (branch : rest) = do
  result <- branch (line "fallback branch begin" state)
  case resultFailure result of
    Nothing ->
      pure (succeed (line "fallback branch ok" (resultState result)))
    Just failure ->
      runFallback (line ("fallback branch failed: " ++ failure) state {renderLines = renderLines (resultState result)}) rest

runRaceBranch ::
  RenderState ->
  (Int, WorkflowRunProgram) ->
  IO RenderResult
runRaceBranch start (branchIndex, branch) =
  branch (descend (line ("race branch " ++ show branchIndex ++ " begin") start))

finishRace ::
  Int ->
  RenderState ->
  [RenderResult] ->
  RenderResult
finishRace startDepth start branchResults =
  case firstSuccess branchResults of
    Just winner ->
      succeed (line "race winner ok" (restoreDepth startDepth (mergeBranchLogs start [winner])))
    Nothing ->
      failResult (line "race failed: no successful branch" (restoreDepth startDepth (mergeBranchLogs start branchResults))) "race has no successful branch"

runChoice ::
  ChoiceKey ->
  [ChoiceBranch ChoiceKey WorkflowRunProgram] ->
  RenderState ->
  IO RenderResult
runChoice selectedKey [] state =
  pure (failWith ("choice has no branch for " ++ renderChoiceKey selectedKey) state)
runChoice selectedKey (ChoiceBranch branchKey branch : rest) state
  | selectedKey == branchKey =
      branch (line ("choice branch " ++ renderChoiceKey branchKey ++ " selected") state)
  | otherwise =
      runChoice selectedKey rest state

finishNode :: Int -> String -> RenderResult -> RenderResult
finishNode startDepth label result =
  case resultFailure result of
    Nothing ->
      succeed (line (label ++ " ok") (restoreDepth startDepth (resultState result)))
    Just failure ->
      failResult (line (label ++ " failed: " ++ failure) (restoreDepth startDepth (resultState result))) failure

recordFacts :: Fact WorkflowFact -> RenderState -> RenderState
recordFacts currentFact state =
  line ("fact " ++ renderFactExpr (factExpression currentFact))
    state {renderFacts = mergeFacts (renderFacts state) (collectFactExpr (factExpression currentFact))}

failWith :: String -> RenderState -> RenderResult
failWith failure state =
  failResult (line failure state) failure

succeed :: RenderState -> RenderResult
succeed state =
  RenderResult
    { resultState = state
    , resultFailure = Nothing
    }

failResult :: RenderState -> String -> RenderResult
failResult state failure =
  RenderResult
    { resultState = state
    , resultFailure = Just failure
    }

firstFailure :: [RenderResult] -> Maybe String
firstFailure [] =
  Nothing
firstFailure (result : rest) =
  case resultFailure result of
    Just failure ->
      Just failure
    Nothing ->
      firstFailure rest

firstSuccess :: [RenderResult] -> Maybe RenderResult
firstSuccess [] =
  Nothing
firstSuccess (result : rest) =
  case resultFailure result of
    Nothing ->
      Just result
    Just _ ->
      firstSuccess rest

mergeBranchLogs :: RenderState -> [RenderResult] -> RenderState
mergeBranchLogs start branchResults =
  start {renderLines = renderLines start ++ concatMap (newLinesAfter start . resultState) branchResults}

mergeBranchFacts :: RenderState -> [RenderResult] -> RenderState
mergeBranchFacts start branchResults =
  (mergeBranchLogs start branchResults)
    { renderFacts = foldl mergeFacts (renderFacts start) (map (renderFacts . resultState) branchResults)
    }

newLinesAfter :: RenderState -> RenderState -> [String]
newLinesAfter before after =
  drop (length (renderLines before)) (renderLines after)

line :: String -> RenderState -> RenderState
line message state =
  state {renderLines = renderLines state ++ [indent (renderDepth state) ++ "- " ++ message]}

descend :: RenderState -> RenderState
descend state =
  state {renderDepth = renderDepth state + 1}

restoreDepth :: Int -> RenderState -> RenderState
restoreDepth depth state =
  state {renderDepth = depth}

indent :: Int -> String
indent depth =
  replicate (depth * 2) ' '

factExprAvailable :: [WorkflowFact] -> FactExpr WorkflowFact -> Bool
factExprAvailable facts (FactItems currentFacts) =
  all (`elem` facts) (collectFacts currentFacts)
factExprAvailable facts (FactAll currentFacts) =
  all (factExprAvailable facts) currentFacts
factExprAvailable facts (FactAny currentFacts) =
  any (factExprAvailable facts) currentFacts

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
  foldl addFact
  where
    addFact facts currentFact
      | currentFact `elem` facts = facts
      | otherwise = currentFact : facts

renderFactExpr :: Show fact => FactExpr fact -> String
renderFactExpr (FactItems currentFacts) =
  renderRequirementFacts currentFacts
renderFactExpr (FactAll currentFacts) =
  "allOf " ++ show (map renderFactExpr currentFacts)
renderFactExpr (FactAny currentFacts) =
  "anyOf " ++ show (map renderFactExpr currentFacts)

renderRequirementFacts :: Show fact => Requirement fact -> String
renderRequirementFacts currentFacts =
  show (requirementEffectItems (requirementFacts currentFacts))

renderChoiceKey :: ChoiceKey -> String
renderChoiceKey (ChoiceKey value) =
  value

