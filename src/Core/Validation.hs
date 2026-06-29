module Core.Validation
  ( AstError (..)
  , renderAstError
  , validateAst
  ) where

import AST.AppBlueprint
  ( AppBlueprint (..)
  )
import Control.Monad
  ( foldM
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
  | WorkflowNameOverlap WorkflowName [WorkflowName] [WorkflowName]
  deriving (Show)

type SeenWorkflowName = (WorkflowName, [WorkflowName])

validateAst :: AppBlueprint -> Either AstError AppBlueprint
validateAst blueprint = do
  _ <- validateWorkflow [] [] (blueprintApp blueprint)
  validateHanging (blueprintHanging blueprint)
  pure blueprint

validateWorkflow ::
  [SeenWorkflowName] ->
  [WorkflowName] ->
  Workflow fact hook ->
  Either AstError [SeenWorkflowName]
validateWorkflow seen ancestors currentWorkflow =
  case currentWorkflow of
    FactWorkflow _ ->
      pure seen

    ChainWorkflow label steps -> do
      (nextSeen, nextAncestors) <- enterNamedWorkflow seen label ancestors
      validateChain nextSeen nextAncestors steps

    ParallelWorkflow label branches -> do
      (nextSeen, nextAncestors) <- enterNamedWorkflow seen label ancestors
      validateParallel nextSeen nextAncestors branches

    FallbackWorkflow branches ->
      validateFallback seen ancestors branches

    RaceWorkflow branches ->
      validateRace seen ancestors branches

    ChoiceWorkflow _ branches ->
      validateChoice seen ancestors branches

    WaitWorkflow _ body ->
      validateWorkflow seen ancestors body

enterNamedWorkflow ::
  [SeenWorkflowName] ->
  WorkflowName ->
  [WorkflowName] ->
  Either AstError ([SeenWorkflowName], [WorkflowName])
enterNamedWorkflow seen label ancestors
  | label `elem` ancestors =
      Left (WorkflowSelfReference label currentPath)
  | otherwise =
      case lookup label seen of
        Just firstPath ->
          Left (WorkflowNameOverlap label firstPath currentPath)
        Nothing ->
          Right ((label, currentPath) : seen, label : ancestors)
  where
    currentPath = reverse (label : ancestors)

validateChain ::
  [SeenWorkflowName] ->
  [WorkflowName] ->
  Chain (Workflow fact hook) ->
  Either AstError [SeenWorkflowName]
validateChain seen ancestors steps =
  validateWorkflows seen ancestors (freeMonadSteps (chainSteps steps))

validateParallel ::
  [SeenWorkflowName] ->
  [WorkflowName] ->
  Parallel (Workflow fact hook) ->
  Either AstError [SeenWorkflowName]
validateParallel seen ancestors branches =
  validateWorkflows seen ancestors (freeApplicativeBranches (parallelBranches branches))

validateFallback ::
  [SeenWorkflowName] ->
  [WorkflowName] ->
  Fallback (Workflow fact hook) ->
  Either AstError [SeenWorkflowName]
validateFallback seen ancestors branches =
  validateWorkflows seen ancestors (freeAlternativeBranches (fallbackBranches branches))

validateRace ::
  [SeenWorkflowName] ->
  [WorkflowName] ->
  Race (Workflow fact hook) ->
  Either AstError [SeenWorkflowName]
validateRace seen ancestors branches =
  validateWorkflows seen ancestors (freeAlternativeBranches (raceBranches branches))

validateChoice ::
  [SeenWorkflowName] ->
  [WorkflowName] ->
  Choice (Workflow fact hook) ->
  Either AstError [SeenWorkflowName]
validateChoice seen ancestors branches =
  foldM validateChoiceBranch seen (freeChoiceBranches (choiceBranches branches))
  where
    validateChoiceBranch currentSeen (ChoiceBranch _ branch) =
      validateWorkflow currentSeen ancestors branch

validateWorkflows ::
  [SeenWorkflowName] ->
  [WorkflowName] ->
  [Workflow fact hook] ->
  Either AstError [SeenWorkflowName]
validateWorkflows seen ancestors =
  foldM (`validateWorkflow` ancestors) seen

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
    HangingCallback currentCallback -> do
      _ <- validateWorkflow [] [] (callbackBody currentCallback)
      pure ()

    HangingSuspense currentSuspense -> do
      _ <- validateWorkflow [] [] (suspenseTarget currentSuspense)
      pure ()

    HangingLoop currentLoop -> do
      _ <- validateWorkflow [] [] (loopBody currentLoop)
      pure ()

    HangingMiddleware _ body -> do
      _ <- validateWorkflow [] [] body
      pure ()

renderAstError :: AstError -> String
renderAstError (WorkflowSelfReference label path) =
  "workflow self-reference is not allowed: "
    ++ renderPath path
    ++ " repeats "
    ++ show label
    ++ ". Use hanging loop when repetition is intentional."
renderAstError (WorkflowNameOverlap label firstPath secondPath) =
  "workflow name overlap is not allowed in app workflow: "
    ++ show label
    ++ " appears at "
    ++ renderPath firstPath
    ++ " and "
    ++ renderPath secondPath
    ++ ". Move intentional reuse to hanging."

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
