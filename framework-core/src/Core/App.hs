module Core.App
  ( AppError (..)
  , AppPlan (..)
  , app
  , buildApp
  , renderAppError
  ) where

import AST.AppBlueprint
  ( AppBlueprint (..)
  )
import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Architecture
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
  ( EffectSemantics (..)
  , FactContract (..)
  , PipeTake (..)
  , ProducerRequirement (..)
  , SendContract (..)
  , SendUse (..)
  , TakeMakeRule (..)
  , effectSemantics
  , factContractFor
  , sendContractFor
  , takeMakeRuleFor
  , takeMakeRulesFor
  )
import Core.App.ClaimScope
  ( ClaimScopeError
  , checkClaimScopes
  , renderClaimScopeError
  )
import Core.Validation
  ( AstError
  , renderAstError
  , validateAst
  )
import Effects.EffectTheory
  ( EffectTheory
  , SendName
  )

data AppPlan = AppPlan
  { appPlanBlueprint :: AppBlueprint
  , appPlanEffects :: EffectTheory
  , appPlanEffectSemantics :: EffectSemantics
  , appPlanFacts :: [WorkflowFact]
  , appPlanSendBoundaries :: [SendName]
  , appPlanTakeMakeRules :: [TakeMakeRule]
  }

data AppError
  = InvalidAst AstError
  | DuplicateFactProducer WorkflowFact
  | DuplicateSendBoundary SendName
  | MissingFactProducer WorkflowFact
  | InvalidClaimScope ClaimScopeError
  | FactDependencyCycle [WorkflowFact]
  | MissingSendBoundary WorkflowFact SendName
  deriving (Show)

app :: AppBlueprint -> EffectTheory -> Either AppError AppPlan
app =
  buildApp

buildApp :: AppBlueprint -> EffectTheory -> Either AppError AppPlan
buildApp blueprint effects = do
  checkedBlueprint <- mapLeft InvalidAst (validateAst blueprint)
  let semantics = effectSemantics effects
  checkEffectTheory semantics
  mapLeft InvalidClaimScope (checkClaimScopes semantics checkedBlueprint)
  let rootFacts = unique (collectBlueprintFacts checkedBlueprint)
  closure <- closeFacts semantics [] [] rootFacts
  let requiredFacts = unique (rootFacts ++ closureFacts closure)
      requiredSendBoundaries = unique (closureSendBoundaries closure)
  mapM_ (checkSendBoundary semantics) (closureSendUses closure)
  pure
    AppPlan
      { appPlanBlueprint = checkedBlueprint
      , appPlanEffects = effects
      , appPlanEffectSemantics = semantics
      , appPlanFacts = requiredFacts
      , appPlanSendBoundaries = requiredSendBoundaries
      , appPlanTakeMakeRules = takeMakeRulesFor semantics requiredFacts
      }

data Closure = Closure
  { closureFacts :: [WorkflowFact]
  , closureSendBoundaries :: [SendName]
  , closureSendUses :: [(WorkflowFact, SendName)]
  }

emptyClosure :: Closure
emptyClosure =
  Closure
    { closureFacts = []
    , closureSendBoundaries = []
    , closureSendUses = []
    }

mergeClosure :: Closure -> Closure -> Closure
mergeClosure left right =
  Closure
    { closureFacts = unique (closureFacts left ++ closureFacts right)
    , closureSendBoundaries = unique (closureSendBoundaries left ++ closureSendBoundaries right)
    , closureSendUses = closureSendUses left ++ closureSendUses right
    }

closeFacts ::
  EffectSemantics ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  Either AppError Closure
closeFacts _ _ _ [] =
  pure emptyClosure
closeFacts effects seen stack (currentFact : rest)
  | currentFact `elem` seen =
      closeFacts effects seen stack rest
  | currentFact `elem` stack =
      Left (FactDependencyCycle (reverse (currentFact : stack)))
  | otherwise = do
      currentClosure <- closeFact effects seen stack currentFact
      restClosure <- closeFacts effects (currentFact : seen) stack rest
      pure (mergeClosure currentClosure restClosure)

closeFact ::
  EffectSemantics ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  WorkflowFact ->
  Either AppError Closure
closeFact effects seen stack currentFact =
  case factContractFor effects currentFact of
    Nothing ->
      Left (MissingFactProducer currentFact)
    Just currentContract ->
      closeFactContract effects (currentFact : seen) (currentFact : stack) currentContract

closeFactContract ::
  EffectSemantics ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  FactContract ->
  Either AppError Closure
closeFactContract effects seen stack currentContract = do
  let neededFacts = concatMap requirementFactList (factContractRequirements currentContract)
      pipeFacts = pipeSourceFacts effects currentContract
      dependencyFacts = unique (neededFacts ++ pipeFacts)
      currentSendUses = factContractSendUses currentContract
      usedSendBoundaries = map sendUseName currentSendUses
      errorSendBoundaries = factContractErrorHandlers currentContract
      sendUses =
        [ (sendUseFact currentUse, sendUseName currentUse)
        | currentUse <- currentSendUses
        ]
      errorUses =
        [ (factContractFact currentContract, currentSend)
        | currentSend <- errorSendBoundaries
        ]
  dependencyClosure <- closeFacts effects seen stack dependencyFacts
  pure
    ( mergeClosure
        dependencyClosure
        Closure
          { closureFacts = factContractFact currentContract : dependencyFacts
          , closureSendBoundaries = usedSendBoundaries ++ errorSendBoundaries
          , closureSendUses = sendUses ++ errorUses
          }
    )

requirementFactList :: ProducerRequirement -> [WorkflowFact]
requirementFactList (NeedsFact currentFact) =
  [currentFact]
requirementFactList (OnFailureFact currentFact) =
  [currentFact]

pipeSourceFacts :: EffectSemantics -> FactContract -> [WorkflowFact]
pipeSourceFacts effects currentContract =
  case takeMakeRuleFor effects (factContractFact currentContract) of
    Nothing ->
      []
    Just currentRule ->
      unique
        [ pipeTakeFact currentPipeTake
        | currentPipeTake <- pipeTakeFacts currentRule
        ]

checkEffectTheory :: EffectSemantics -> Either AppError ()
checkEffectTheory effects = do
  checkDuplicateFactProducers effects
  checkDuplicateSendBoundaries effects

checkDuplicateFactProducers :: EffectSemantics -> Either AppError ()
checkDuplicateFactProducers effects =
  case findDuplicate (map factContractFact (semanticFactContracts effects)) of
    Just currentFact ->
      Left (DuplicateFactProducer currentFact)
    Nothing ->
      pure ()

checkDuplicateSendBoundaries :: EffectSemantics -> Either AppError ()
checkDuplicateSendBoundaries effects =
  case findDuplicate (map sendContractName (semanticSendContracts effects)) of
    Just currentSend ->
      Left (DuplicateSendBoundary currentSend)
    Nothing ->
      pure ()

checkSendBoundary :: EffectSemantics -> (WorkflowFact, SendName) -> Either AppError ()
checkSendBoundary effects (currentFact, currentSend)
  | Just _ <- sendContractFor effects currentSend =
      pure ()
  | otherwise =
      Left (MissingSendBoundary currentFact currentSend)

collectBlueprintFacts :: AppBlueprint -> [WorkflowFact]
collectBlueprintFacts blueprint =
  collectWorkflowFacts (blueprintApp blueprint)
    ++ collectHangingFacts (blueprintHanging blueprint)

collectWorkflowFacts :: Workflow WorkflowFact hook -> [WorkflowFact]
collectWorkflowFacts currentWorkflow =
  case currentWorkflow of
    FactWorkflow currentFact ->
      collectFactExpr (factExpression currentFact)
    ChainWorkflow _ steps ->
      concatMap collectWorkflowFacts (freeMonadSteps (chainSteps steps))
    ParallelWorkflow _ branches ->
      concatMap collectWorkflowFacts (freeApplicativeBranches (parallelBranches branches))
    FallbackWorkflow branches ->
      concatMap collectWorkflowFacts (freeAlternativeBranches (fallbackBranches branches))
    RaceWorkflow branches ->
      concatMap collectWorkflowFacts (freeAlternativeBranches (raceBranches branches))
    ChoiceWorkflow _ choices ->
      concatMap collectChoiceFacts (freeChoiceBranches (choiceBranches choices))
    WaitWorkflow currentWait body ->
      collectFactExpr (waitFacts currentWait) ++ collectWorkflowFacts body

collectChoiceFacts :: ChoiceBranch ChoiceKey (Workflow WorkflowFact hook) -> [WorkflowFact]
collectChoiceFacts (ChoiceBranch _ branch) =
  collectWorkflowFacts branch

collectHangingFacts :: Hanging (HangingAction WorkflowFact hook (Workflow WorkflowFact hook)) -> [WorkflowFact]
collectHangingFacts actions =
  concatMap collectHangingActionFacts (freeMonoidItems (hangingActions actions))

collectHangingActionFacts :: HangingAction WorkflowFact hook (Workflow WorkflowFact hook) -> [WorkflowFact]
collectHangingActionFacts currentAction =
  case currentAction of
    HangingCallback currentCallback ->
      collectWorkflowFacts (callbackBody currentCallback)
    HangingSuspense _ ->
      []
    HangingLoop currentLoop ->
      collectWorkflowFacts (loopBody currentLoop)
    HangingMiddleware _ body ->
      collectWorkflowFacts body

collectFactExpr :: FactExpr WorkflowFact -> [WorkflowFact]
collectFactExpr (FactItems currentFacts) =
  requirementEffectItems (requirementFacts currentFacts)
collectFactExpr (FactAll currentFacts) =
  concatMap collectFactExpr currentFacts
collectFactExpr (FactAny currentFacts) =
  concatMap collectFactExpr currentFacts

renderAppError :: AppError -> String
renderAppError (InvalidAst astError) =
  renderAstError astError
renderAppError (DuplicateFactProducer currentFact) =
  "duplicate producer for fact " ++ show currentFact
renderAppError (DuplicateSendBoundary currentSend) =
  "duplicate send boundary " ++ show currentSend
renderAppError (MissingFactProducer currentFact) =
  "missing producer for fact " ++ show currentFact
renderAppError (InvalidClaimScope errorReport) =
  renderClaimScopeError errorReport
renderAppError (FactDependencyCycle currentFacts) =
  "fact dependency cycle: " ++ joinWith " -> " (map show currentFacts)
renderAppError (MissingSendBoundary currentFact currentSend) =
  "producer for " ++ show currentFact ++ " uses undeclared send boundary " ++ show currentSend

unique :: Eq item => [item] -> [item]
unique =
  foldl addUnique []
  where
    addUnique items item
      | item `elem` items = items
      | otherwise = items ++ [item]

findDuplicate :: Eq item => [item] -> Maybe item
findDuplicate =
  findDuplicateWithSeen []
  where
    findDuplicateWithSeen _ [] =
      Nothing
    findDuplicateWithSeen seen (item : rest)
      | item `elem` seen = Just item
      | otherwise = findDuplicateWithSeen (item : seen) rest

mapLeft :: (left -> nextLeft) -> Either left right -> Either nextLeft right
mapLeft transform currentEither =
  case currentEither of
    Left value ->
      Left (transform value)
    Right value ->
      Right value

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
