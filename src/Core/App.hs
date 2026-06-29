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
import Core.Validation
  ( AstError
  , renderAstError
  , validateAst
  )
import Effects.EffectTheory
  ( EffectProfile (..)
  , EffectSection (..)
  , EffectTheory (..)
  , EffectUnit (..)
  , FactProducer (..)
  , ImplementationBinding (..)
  , ProducerStep (..)
  , ProfileName
  , SendBoundary (..)
  , SendName
  )

data AppPlan = AppPlan
  { appPlanBlueprint :: AppBlueprint
  , appPlanEffects :: EffectTheory
  , appPlanProfile :: ProfileName
  , appPlanFacts :: [WorkflowFact]
  , appPlanSendBoundaries :: [SendName]
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
  checkEffectTheory effects
  let rootFacts = unique (collectBlueprintFacts checkedBlueprint)
  closure <- closeFacts effects [] [] rootFacts
  let requiredFacts = unique (rootFacts ++ closureFacts closure)
      requiredSendBoundaries = unique (closureSendBoundaries closure)
  mapM_ (checkSendBoundary effects) (closureSendUses closure)
  checkProfile effects currentProfile
  mapM_ (checkImplementation effects currentProfile) requiredSendBoundaries
  pure
    AppPlan
      { appPlanBlueprint = checkedBlueprint
      , appPlanEffects = effects
      , appPlanProfile = currentProfile
      , appPlanFacts = requiredFacts
      , appPlanSendBoundaries = requiredSendBoundaries
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
  EffectTheory ->
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
  EffectTheory ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  WorkflowFact ->
  Either AppError Closure
closeFact effects seen stack currentFact =
  case findProducer effects currentFact of
    Nothing ->
      Left (MissingFactProducer currentFact)
    Just currentProducer ->
      closeProducer effects (currentFact : seen) (currentFact : stack) currentProducer

closeProducer ::
  EffectTheory ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  FactProducer ->
  Either AppError Closure
closeProducer effects seen stack currentProducer = do
  let steps = producerSteps currentProducer
      neededFacts = concatMap stepFacts steps
      usedSendBoundaries = concatMap stepSendBoundaries steps
      sendUses = [(producerFact currentProducer, currentSend) | currentSend <- usedSendBoundaries]
  dependencyClosure <- closeFacts effects seen stack neededFacts
  pure
    ( mergeClosure
        dependencyClosure
        Closure
          { closureFacts = producerFact currentProducer : neededFacts
          , closureSendBoundaries = usedSendBoundaries
          , closureSendUses = sendUses
          }
    )

stepFacts :: ProducerStep -> [WorkflowFact]
stepFacts (Needs currentFact) =
  [currentFact]
stepFacts (OnFailure currentFact) =
  [currentFact]
stepFacts _ =
  []

stepSendBoundaries :: ProducerStep -> [SendName]
stepSendBoundaries (Uses currentSend) =
  [currentSend]
stepSendBoundaries _ =
  []

findProducer :: EffectTheory -> WorkflowFact -> Maybe FactProducer
findProducer effects currentFact =
  firstJust
    [ Just currentProducer
    | currentProducer <- allProducers effects
    , producerFact currentProducer == currentFact
    ]

checkEffectTheory :: EffectTheory -> Either AppError ()
checkEffectTheory effects = do
  checkDuplicateFactProducers effects
  checkDuplicateSendBoundaries effects
  checkDuplicateImplementations effects

checkDuplicateFactProducers :: EffectTheory -> Either AppError ()
checkDuplicateFactProducers effects =
  case findDuplicate (map producerFact (allProducers effects)) of
    Just currentFact ->
      Left (DuplicateFactProducer currentFact)
    Nothing ->
      pure ()

checkDuplicateSendBoundaries :: EffectTheory -> Either AppError ()
checkDuplicateSendBoundaries effects =
  case findDuplicate (map sendBoundaryName (allSendBoundaries effects)) of
    Just currentSend ->
      Left (DuplicateSendBoundary currentSend)
    Nothing ->
      pure ()

checkDuplicateImplementations :: EffectTheory -> Either AppError ()
checkDuplicateImplementations effects =
  case findDuplicate implementationKeys of
    Just (currentProfile, currentSend) ->
      Left (DuplicateImplementation currentProfile currentSend)
    Nothing ->
      pure ()
  where
    implementationKeys =
      [ (profileName currentProfile, implementedSend currentImplementation)
      | currentProfile <- allProfiles effects
      , currentImplementation <- profileImplementations currentProfile
      ]

checkSendBoundary :: EffectTheory -> (WorkflowFact, SendName) -> Either AppError ()
checkSendBoundary effects (currentFact, currentSend)
  | currentSend `elem` map sendBoundaryName (allSendBoundaries effects) =
      pure ()
  | otherwise =
      Left (MissingSendBoundary currentFact currentSend)

checkProfile :: EffectTheory -> ProfileName -> Either AppError ()
checkProfile effects currentProfile
  | currentProfile `elem` map profileName (allProfiles effects) =
      pure ()
  | otherwise =
      Left (MissingProfile currentProfile)

checkImplementation :: EffectTheory -> ProfileName -> SendName -> Either AppError ()
checkImplementation effects currentProfile currentSend
  | currentSend `elem` map implementedSend (profileImplementationsFor effects currentProfile) =
      pure ()
  | otherwise =
      Left (MissingImplementation currentProfile currentSend)

allProducers :: EffectTheory -> [FactProducer]
allProducers effects =
  concatMap unitProducers (theoryUnits effects)

allSendBoundaries :: EffectTheory -> [SendBoundary]
allSendBoundaries effects =
  concatMap unitSendBoundaries (theoryUnits effects)

allProfiles :: EffectTheory -> [EffectProfile]
allProfiles effects =
  concatMap unitProfiles (theoryUnits effects)

profileImplementationsFor :: EffectTheory -> ProfileName -> [ImplementationBinding]
profileImplementationsFor effects currentProfile =
  concat
    [ profileImplementations currentProfileImplementations
    | currentProfileImplementations <- allProfiles effects
    , profileName currentProfileImplementations == currentProfile
    ]

unitProducers :: EffectUnit -> [FactProducer]
unitProducers =
  concatMap sectionProducers . effectUnitSections

unitSendBoundaries :: EffectUnit -> [SendBoundary]
unitSendBoundaries =
  concatMap sectionSendBoundaries . effectUnitSections

unitProfiles :: EffectUnit -> [EffectProfile]
unitProfiles =
  concatMap sectionProfiles . effectUnitSections

sectionProducers :: EffectSection -> [FactProducer]
sectionProducers (FactClaimSection currentProducer) =
  [currentProducer]
sectionProducers _ =
  []

sectionSendBoundaries :: EffectSection -> [SendBoundary]
sectionSendBoundaries (SendSection currentSend) =
  [currentSend]
sectionSendBoundaries _ =
  []

sectionProfiles :: EffectSection -> [EffectProfile]
sectionProfiles (ProfileSection currentProfile) =
  [currentProfile]
sectionProfiles _ =
  []

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

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest

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
