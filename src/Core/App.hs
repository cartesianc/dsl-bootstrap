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
  , HandlerContract (..)
  , ProducerRequirement (..)
  , ProfileContract (..)
  , SendContract (..)
  , SendUse (..)
  , TakeMakeRule (..)
  , effectSemantics
  , factContractFor
  , handlerContractFor
  , handlerContractsFor
  , profileContractFor
  , sendContractFor
  , takeMakeRulesFor
  )
import Core.Validation
  ( AstError
  , renderAstError
  , validateAst
  )
import Effects.EffectTheory
  ( EffectTheory
  , ProfileName
  , SendName
  )

data AppPlan = AppPlan
  { appPlanBlueprint :: AppBlueprint
  , appPlanEffects :: EffectTheory
  , appPlanEffectSemantics :: EffectSemantics
  , appPlanProfile :: ProfileName
  , appPlanFacts :: [WorkflowFact]
  , appPlanSendBoundaries :: [SendName]
  , appPlanHandlerContracts :: [HandlerContract]
  , appPlanTakeMakeRules :: [TakeMakeRule]
  }

data AppError
  = InvalidAst AstError
  | DuplicateFactProducer WorkflowFact
  | DuplicateSendBoundary SendName
  | DuplicateImplementation ProfileName SendName
  | MissingFactProducer WorkflowFact
  | FactDependencyCycle [WorkflowFact]
  | MissingSendBoundary WorkflowFact SendName
  | MissingProfile ProfileName
  | MissingImplementation ProfileName SendName
  deriving (Show)

app :: AppBlueprint -> EffectTheory -> ProfileName -> Either AppError AppPlan
app =
  buildApp

buildApp :: AppBlueprint -> EffectTheory -> ProfileName -> Either AppError AppPlan
buildApp blueprint effects currentProfile = do
  checkedBlueprint <- mapLeft InvalidAst (validateAst blueprint)
  let semantics = effectSemantics effects
  checkEffectTheory semantics
  let rootFacts = unique (collectBlueprintFacts checkedBlueprint)
  closure <- closeFacts semantics [] [] rootFacts
  let requiredFacts = unique (rootFacts ++ closureFacts closure)
      requiredSendBoundaries = unique (closureSendBoundaries closure)
  mapM_ (checkSendBoundary semantics) (closureSendUses closure)
  checkProfile semantics currentProfile
  mapM_ (checkImplementation semantics currentProfile) requiredSendBoundaries
  pure
    AppPlan
      { appPlanBlueprint = checkedBlueprint
      , appPlanEffects = effects
      , appPlanEffectSemantics = semantics
      , appPlanProfile = currentProfile
      , appPlanFacts = requiredFacts
      , appPlanSendBoundaries = requiredSendBoundaries
      , appPlanHandlerContracts = handlerContractsFor semantics currentProfile requiredSendBoundaries
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
      currentSendUses = factContractSendUses currentContract
      usedSendBoundaries = map sendUseName currentSendUses
      sendUses =
        [ (sendUseFact currentUse, sendUseName currentUse)
        | currentUse <- currentSendUses
        ]
  dependencyClosure <- closeFacts effects seen stack neededFacts
  pure
    ( mergeClosure
        dependencyClosure
        Closure
          { closureFacts = factContractFact currentContract : neededFacts
          , closureSendBoundaries = usedSendBoundaries
          , closureSendUses = sendUses
          }
    )

requirementFactList :: ProducerRequirement -> [WorkflowFact]
requirementFactList (NeedsFact currentFact) =
  [currentFact]
requirementFactList (OnFailureFact currentFact) =
  [currentFact]

checkEffectTheory :: EffectSemantics -> Either AppError ()
checkEffectTheory effects = do
  checkDuplicateFactProducers effects
  checkDuplicateSendBoundaries effects
  checkDuplicateImplementations effects

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

checkDuplicateImplementations :: EffectSemantics -> Either AppError ()
checkDuplicateImplementations effects =
  case findDuplicate implementationKeys of
    Just (currentProfile, currentSend) ->
      Left (DuplicateImplementation currentProfile currentSend)
    Nothing ->
      pure ()
  where
    implementationKeys =
      [ (profileContractName currentProfile, handlerContractSend currentImplementation)
      | currentProfile <- semanticProfileContracts effects
      , currentImplementation <- profileContractHandlers currentProfile
      ]

checkSendBoundary :: EffectSemantics -> (WorkflowFact, SendName) -> Either AppError ()
checkSendBoundary effects (currentFact, currentSend)
  | Just _ <- sendContractFor effects currentSend =
      pure ()
  | otherwise =
      Left (MissingSendBoundary currentFact currentSend)

checkProfile :: EffectSemantics -> ProfileName -> Either AppError ()
checkProfile effects currentProfile
  | Just _ <- profileContractFor effects currentProfile =
      pure ()
  | otherwise =
      Left (MissingProfile currentProfile)

checkImplementation :: EffectSemantics -> ProfileName -> SendName -> Either AppError ()
checkImplementation effects currentProfile currentSend
  | Just _ <- handlerContractFor effects currentProfile currentSend =
      pure ()
  | otherwise =
      Left (MissingImplementation currentProfile currentSend)

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
      collectFactExpr (callbackFacts currentCallback) ++ collectWorkflowFacts (callbackBody currentCallback)
    HangingSuspense currentSuspense ->
      collectFactExpr (suspenseFacts currentSuspense) ++ collectWorkflowFacts (suspenseTarget currentSuspense)
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
renderAppError (DuplicateImplementation currentProfile currentSend) =
  "duplicate implementation for send boundary " ++ show currentSend ++ " in profile " ++ show currentProfile
renderAppError (MissingFactProducer currentFact) =
  "missing producer for fact " ++ show currentFact
renderAppError (FactDependencyCycle currentFacts) =
  "fact dependency cycle: " ++ joinWith " -> " (map show currentFacts)
renderAppError (MissingSendBoundary currentFact currentSend) =
  "producer for " ++ show currentFact ++ " uses undeclared send boundary " ++ show currentSend
renderAppError (MissingProfile currentProfile) =
  "missing profile " ++ show currentProfile
renderAppError (MissingImplementation currentProfile currentSend) =
  "missing implementation for send boundary " ++ show currentSend ++ " in profile " ++ show currentProfile

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
