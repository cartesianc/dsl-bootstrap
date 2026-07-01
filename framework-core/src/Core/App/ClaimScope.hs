module Core.App.ClaimScope
  ( ClaimScopeError (..)
  , checkClaimScopes
  , renderClaimScopeError
  ) where

import Control.Monad
  ( foldM
  )

import AST.AppBlueprint
  ( AppBlueprint (..)
  )
import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Architecture
  ( Callback (..)
  , Chain (..)
  , Choice (..)
  , Fact (..)
  , FactExpr (..)
  , Fallback (..)
  , Hanging (..)
  , HangingAction (..)
  , Loop (..)
  , Parallel (..)
  , Race (..)
  , Requirement (..)
  , Wait (..)
  , Workflow (..)
  )
import Core.Architecture.Internal
  ( ChoiceBranch (..)
  , FreeAlternative (..)
  , FreeApplicative (..)
  , FreeChoice (..)
  , FreeMonad (..)
  , FreeMonoid (..)
  , RequirementEffect (..)
  )
import Core.Effect.Semantics
  ( EffectSemantics
  , FactContract (..)
  , FactSource (..)
  , ProducerRequirement (..)
  , factContractFor
  )

data ClaimScopeError
  = MissingVisibleFactClaim WorkflowFact WorkflowFact
  | WaitWithoutFactClaim WorkflowFact
  deriving (Eq, Show)

checkClaimScopes :: EffectSemantics -> AppBlueprint -> Either ClaimScopeError ()
checkClaimScopes semantics blueprint = do
  let globalClaims = collectBlueprintClaimFacts blueprint
  _ <- checkWorkflowClaimScope semantics globalClaims [] (blueprintApp blueprint)
  mapM_ (checkHangingActionClaimScope semantics globalClaims) (freeMonoidItems (hangingActions (blueprintHanging blueprint)))

checkWorkflowClaimScope ::
  EffectSemantics ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  Workflow WorkflowFact hook ->
  Either ClaimScopeError [WorkflowFact]
checkWorkflowClaimScope semantics globalClaims visibleClaims currentWorkflow =
  case currentWorkflow of
    FactWorkflow currentFact -> do
      let currentFacts = collectFactExpr (factExpression currentFact)
      mapM_ (checkFactClaimDependencies semantics visibleClaims) currentFacts
      pure currentFacts
    ChainWorkflow _ steps ->
      checkChainClaimScope semantics globalClaims visibleClaims (freeMonadSteps (chainSteps steps))
    ParallelWorkflow _ branches ->
      unique . concat
        <$> mapM
          (checkWorkflowClaimScope semantics globalClaims visibleClaims)
          (freeApplicativeBranches (parallelBranches branches))
    FallbackWorkflow branches ->
      unique . concat
        <$> mapM
          (checkWorkflowClaimScope semantics globalClaims visibleClaims)
          (freeAlternativeBranches (fallbackBranches branches))
    RaceWorkflow branches ->
      unique . concat
        <$> mapM
          (checkWorkflowClaimScope semantics globalClaims visibleClaims)
          (freeAlternativeBranches (raceBranches branches))
    ChoiceWorkflow _ choices ->
      unique . concat
        <$> mapM
          (checkChoiceClaimScope semantics globalClaims visibleClaims)
          (freeChoiceBranches (choiceBranches choices))
    WaitWorkflow currentWait body -> do
      let waitedFacts = collectFactExpr (waitFacts currentWait)
      mapM_ (checkWaitClaimSource semantics globalClaims visibleClaims) waitedFacts
      bodyClaims <-
        checkWorkflowClaimScope
          semantics
          globalClaims
          (unique (visibleClaims ++ waitedFacts))
          body
      pure (unique (waitedFacts ++ bodyClaims))

checkChainClaimScope ::
  EffectSemantics ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  [Workflow WorkflowFact hook] ->
  Either ClaimScopeError [WorkflowFact]
checkChainClaimScope semantics globalClaims visibleClaims steps =
  snd
    <$> foldM
      step
      (visibleClaims, [])
      steps
  where
    step (currentVisible, exportedClaims) currentStep = do
      stepClaims <- checkWorkflowClaimScope semantics globalClaims currentVisible currentStep
      let nextVisible = unique (currentVisible ++ stepClaims)
          nextExports = unique (exportedClaims ++ stepClaims)
      pure (nextVisible, nextExports)

checkChoiceClaimScope ::
  EffectSemantics ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  ChoiceBranch key (Workflow WorkflowFact hook) ->
  Either ClaimScopeError [WorkflowFact]
checkChoiceClaimScope semantics globalClaims visibleClaims (ChoiceBranch _ branch) =
  checkWorkflowClaimScope semantics globalClaims visibleClaims branch

checkHangingActionClaimScope ::
  EffectSemantics ->
  [WorkflowFact] ->
  HangingAction WorkflowFact hook (Workflow WorkflowFact hook) ->
  Either ClaimScopeError ()
checkHangingActionClaimScope semantics globalClaims currentAction =
  case currentAction of
    HangingCallback currentCallback ->
      discardClaims (checkWorkflowClaimScope semantics globalClaims globalClaims (callbackBody currentCallback))
    HangingSuspense _ ->
      pure ()
    HangingLoop currentLoop ->
      discardClaims (checkWorkflowClaimScope semantics globalClaims globalClaims (loopBody currentLoop))
    HangingMiddleware _ body ->
      discardClaims (checkWorkflowClaimScope semantics globalClaims globalClaims body)

discardClaims :: Either ClaimScopeError [WorkflowFact] -> Either ClaimScopeError ()
discardClaims result =
  case result of
    Left errorReport ->
      Left errorReport
    Right _ ->
      pure ()

checkFactClaimDependencies ::
  EffectSemantics ->
  [WorkflowFact] ->
  WorkflowFact ->
  Either ClaimScopeError ()
checkFactClaimDependencies semantics visibleClaims currentFact =
  case factContractFor semantics currentFact of
    Nothing ->
      pure ()
    Just currentContract ->
      mapM_ (checkProducerRequirement semantics visibleClaims currentFact []) (factContractRequirements currentContract)

checkProducerRequirement ::
  EffectSemantics ->
  [WorkflowFact] ->
  WorkflowFact ->
  [WorkflowFact] ->
  ProducerRequirement ->
  Either ClaimScopeError ()
checkProducerRequirement semantics visibleClaims currentFact stack currentRequirement =
  case currentRequirement of
    NeedsFact neededFact ->
      checkReachableRequirement semantics visibleClaims currentFact stack neededFact
    OnFailureFact _ ->
      pure ()

checkReachableRequirement ::
  EffectSemantics ->
  [WorkflowFact] ->
  WorkflowFact ->
  [WorkflowFact] ->
  WorkflowFact ->
  Either ClaimScopeError ()
checkReachableRequirement semantics visibleClaims rootFact stack neededFact
  | factClaimVisible semantics visibleClaims neededFact =
      pure ()
  | neededFact `elem` stack =
      pure ()
  | otherwise =
      case factContractFor semantics neededFact of
        Nothing ->
          Left (MissingVisibleFactClaim rootFact neededFact)
        Just currentContract
          | factContractSource currentContract == ReceivedExternally ->
              pure ()
          | otherwise ->
              mapM_
                (checkProducerRequirement semantics visibleClaims rootFact (neededFact : stack))
                (factContractRequirements currentContract)

checkWaitClaimSource ::
  EffectSemantics ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  WorkflowFact ->
  Either ClaimScopeError ()
checkWaitClaimSource semantics globalClaims visibleClaims currentFact
  | currentFact `elem` visibleClaims =
      pure ()
  | currentFact `elem` globalClaims =
      pure ()
  | factIsExternalTake semantics currentFact =
      pure ()
  | otherwise =
      Left (WaitWithoutFactClaim currentFact)

factClaimVisible :: EffectSemantics -> [WorkflowFact] -> WorkflowFact -> Bool
factClaimVisible semantics visibleClaims currentFact =
  currentFact `elem` visibleClaims
    || factIsExternalTake semantics currentFact

factIsExternalTake :: EffectSemantics -> WorkflowFact -> Bool
factIsExternalTake semantics currentFact =
  case factContractFor semantics currentFact of
    Just currentContract ->
      factContractSource currentContract == ReceivedExternally
    Nothing ->
      False

collectBlueprintClaimFacts :: AppBlueprint -> [WorkflowFact]
collectBlueprintClaimFacts blueprint =
  unique
    ( collectWorkflowClaimFacts (blueprintApp blueprint)
        ++ collectHangingClaimFacts (blueprintHanging blueprint)
    )

collectWorkflowClaimFacts :: Workflow WorkflowFact hook -> [WorkflowFact]
collectWorkflowClaimFacts currentWorkflow =
  case currentWorkflow of
    FactWorkflow currentFact ->
      collectFactExpr (factExpression currentFact)
    ChainWorkflow _ steps ->
      concatMap collectWorkflowClaimFacts (freeMonadSteps (chainSteps steps))
    ParallelWorkflow _ branches ->
      concatMap collectWorkflowClaimFacts (freeApplicativeBranches (parallelBranches branches))
    FallbackWorkflow branches ->
      concatMap collectWorkflowClaimFacts (freeAlternativeBranches (fallbackBranches branches))
    RaceWorkflow branches ->
      concatMap collectWorkflowClaimFacts (freeAlternativeBranches (raceBranches branches))
    ChoiceWorkflow _ choices ->
      concatMap collectChoiceClaimFacts (freeChoiceBranches (choiceBranches choices))
    WaitWorkflow _ body ->
      collectWorkflowClaimFacts body

collectChoiceClaimFacts :: ChoiceBranch key (Workflow WorkflowFact hook) -> [WorkflowFact]
collectChoiceClaimFacts (ChoiceBranch _ branch) =
  collectWorkflowClaimFacts branch

collectHangingClaimFacts :: Hanging (HangingAction WorkflowFact hook (Workflow WorkflowFact hook)) -> [WorkflowFact]
collectHangingClaimFacts actions =
  concatMap collectHangingActionClaimFacts (freeMonoidItems (hangingActions actions))

collectHangingActionClaimFacts :: HangingAction WorkflowFact hook (Workflow WorkflowFact hook) -> [WorkflowFact]
collectHangingActionClaimFacts currentAction =
  case currentAction of
    HangingCallback currentCallback ->
      collectWorkflowClaimFacts (callbackBody currentCallback)
    HangingSuspense _ ->
      []
    HangingLoop currentLoop ->
      collectWorkflowClaimFacts (loopBody currentLoop)
    HangingMiddleware _ body ->
      collectWorkflowClaimFacts body

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

renderClaimScopeError :: ClaimScopeError -> String
renderClaimScopeError (MissingVisibleFactClaim currentFact neededFact) =
  "fact "
    ++ show currentFact
    ++ " needs "
    ++ show neededFact
    ++ ", but no visible AST claim was found"
renderClaimScopeError (WaitWithoutFactClaim currentFact) =
  "wait references fact without AST claim " ++ show currentFact

unique :: Eq item => [item] -> [item]
unique =
  foldl addUnique []
  where
    addUnique items item
      | item `elem` items = items
      | otherwise = items ++ [item]
