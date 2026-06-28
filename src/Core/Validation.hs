module Core.Validation
  ( AstError (..)
  , validateAst
  , checkedAst
  , reportAstError
  ) where

import AST.AppBlueprint
  ( AppBlueprint (..)
  )
import Core.Architecture
import Core.Architecture.Internal
  ( ChoiceBranch (..)
  , freeAlternativeBranches
  , freeApplicativeBranches
  , freeChoiceBranches
  , freeMonadSteps
  , freeMonoidItems
  )

data AstError
  = WorkflowSelfReference WorkflowName [WorkflowName]
  deriving (Show)

validateAst :: AppBlueprint -> Either AstError AppBlueprint
validateAst ast = do
  validateWorkflow [] (blueprintApp ast)
  validateHanging (blueprintHanging ast)
  pure ast

checkedAst :: (AppBlueprint -> IO ()) -> AppBlueprint -> IO ()
checkedAst continue ast =
  case validateAst ast of
    Left errorReport ->
      reportAstError errorReport

    Right astAfterCheck ->
      continue astAfterCheck

reportAstError :: AstError -> IO ()
reportAstError errorReport =
  putStrLn ("Invalid AST: " ++ renderAstError errorReport)

validateWorkflow :: [WorkflowName] -> Workflow fact hook -> Either AstError ()
validateWorkflow ancestors currentWorkflow =
  case currentWorkflow of
    FactWorkflow _ ->
      pure ()

    ChainWorkflow label steps -> do
      nextAncestors <- enterNamedWorkflow label ancestors
      validateChain nextAncestors steps

    ParallelWorkflow label branches -> do
      nextAncestors <- enterNamedWorkflow label ancestors
      validateParallel nextAncestors branches

    FallbackWorkflow branches ->
      validateFallback ancestors branches

    RaceWorkflow branches ->
      validateRace ancestors branches

    ChoiceWorkflow _ branches ->
      validateChoice ancestors branches

    WaitWorkflow _ body ->
      validateWorkflow ancestors body

enterNamedWorkflow ::
  WorkflowName ->
  [WorkflowName] ->
  Either AstError [WorkflowName]
enterNamedWorkflow label ancestors
  | label `elem` ancestors =
      Left (WorkflowSelfReference label (reverse (label : ancestors)))
  | otherwise =
      Right (label : ancestors)

validateChain :: [WorkflowName] -> Chain (Workflow fact hook) -> Either AstError ()
validateChain ancestors steps =
  mapM_ (validateWorkflow ancestors) (freeMonadSteps (chainSteps steps))

validateParallel ::
  [WorkflowName] ->
  Parallel (Workflow fact hook) ->
  Either AstError ()
validateParallel ancestors branches =
  mapM_ (validateWorkflow ancestors) (freeApplicativeBranches (parallelBranches branches))

validateFallback ::
  [WorkflowName] ->
  Fallback (Workflow fact hook) ->
  Either AstError ()
validateFallback ancestors branches =
  mapM_ (validateWorkflow ancestors) (freeAlternativeBranches (fallbackBranches branches))

validateRace ::
  [WorkflowName] ->
  Race (Workflow fact hook) ->
  Either AstError ()
validateRace ancestors branches =
  mapM_ (validateWorkflow ancestors) (freeAlternativeBranches (raceBranches branches))

validateChoice ::
  [WorkflowName] ->
  Choice (Workflow fact hook) ->
  Either AstError ()
validateChoice ancestors branches =
  mapM_ validateChoiceBranch (freeChoiceBranches (choiceBranches branches))
  where
    validateChoiceBranch (ChoiceBranch _ branch) =
      validateWorkflow ancestors branch

validateHanging ::
  Hanging (HangingAction fact hook (Workflow fact hook)) ->
  Either AstError ()
validateHanging actions =
  mapM_ validateHangingAction (freeMonoidItems (hangingActions actions))

validateHangingAction ::
  HangingAction fact hook (Workflow fact hook) ->
  Either AstError ()
validateHangingAction currentAction =
  case currentAction of
    HangingCallback currentCallback ->
      validateWorkflow [] (callbackBody currentCallback)

    HangingSuspense currentSuspense ->
      validateWorkflow [] (suspenseTarget currentSuspense)

    HangingLoop currentLoop ->
      validateWorkflow [] (loopBody currentLoop)

    HangingMiddleware _ body ->
      validateWorkflow [] body

renderAstError :: AstError -> String
renderAstError (WorkflowSelfReference label path) =
  "workflow self-reference is not allowed: "
    ++ renderPath path
    ++ " repeats "
    ++ show label
    ++ ". Use hanging loop when repetition is intentional."

renderPath :: [WorkflowName] -> String
renderPath =
  joinWith " -> " . map show

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
