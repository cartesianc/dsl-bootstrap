module Core.Effect.Constraint
  ( ConstraintError (..)
  , ConstraintFact (..)
  , RuleId (..)
  , WorkflowScope (..)
  , checkConstraintFacts
  , constraintsFromAppPlan
  , renderConstraintError
  , renderConstraintFacts
  ) where

import AST.Vocabulary
  ( WorkflowFact
  , WorkflowName
  )
import qualified AST.AppBlueprint as AppBlueprint
import Core.App
  ( AppPlan (..)
  )
import Core.Architecture
  ( Callback (..)
  , Chain (..)
  , Choice (..)
  , FactExpr (..)
  , Fallback (..)
  , Hanging (..)
  , HangingAction (..)
  , Loop (..)
  , Parallel (..)
  , Requirement (..)
  , Race (..)
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
  ( BoundarySource (..)
  , EffectBoundary (..)
  , EffectSemantics (..)
  , PipeTake (..)
  , SendContract (..)
  , TakeMakeRule (..)
  , TakeMakeSource (..)
  , TransformUse (..)
  )
import Effects.EffectTheory
  ( SendName
  , TransformName
  , TypeName
  )

newtype RuleId = RuleId WorkflowFact
  deriving (Eq, Show)

data WorkflowScope
  = RootScope
  | NamedScope WorkflowName
  deriving (Eq, Show)

data ConstraintFact
  = RequiresFact WorkflowFact
  | EffectBoundaryExternalMake WorkflowFact SendName TypeName TypeName BoundarySource
  | EffectBoundaryInternalTake WorkflowFact TypeName BoundarySource
  | EffectBoundaryInternalMake WorkflowFact TypeName BoundarySource
  | EffectBoundaryExternalTake WorkflowFact (Maybe TypeName) BoundarySource
  | ExternalMakeDeclared SendName
  | Makes RuleId WorkflowFact
  | Takes RuleId WorkflowFact
  | PipeNeeds RuleId TypeName
  | PipeMakes RuleId TypeName
  | PipeTakes RuleId TypeName WorkflowFact
  | UsesExternalMake RuleId SendName
  | UsesTransform RuleId TransformName TypeName TypeName
  | HandlesError RuleId SendName
  | FailureMakes RuleId WorkflowFact
  | ExternalTakeFact WorkflowFact
  | WaitsFor WorkflowScope WorkflowFact
  deriving (Eq, Show)

data ConstraintError
  = MissingFactSource WorkflowFact
  | MissingTakeSource RuleId WorkflowFact
  | MissingPipeSource RuleId TypeName
  | MissingPipeTakeSource RuleId TypeName WorkflowFact
  | MissingExternalMake RuleId SendName
  | ExternalTakeAutoMake WorkflowFact
  | DuplicateMaker WorkflowFact [RuleId]
  | DuplicatePipeMaker TypeName [RuleId]
  | DependencyCycle [WorkflowFact]
  | DeadWaitCandidate WorkflowScope WorkflowFact
  deriving (Eq, Show)

constraintsFromAppPlan :: AppPlan -> [ConstraintFact]
constraintsFromAppPlan appPlan =
  unique
    ( map RequiresFact (appPlanFacts appPlan)
        ++ boundaryConstraints (appPlanEffectSemantics appPlan)
        ++ declaredExternalMakes (appPlanEffectSemantics appPlan)
        ++ ruleConstraints (appPlanTakeMakeRules appPlan)
        ++ waitConstraints appPlan
    )

declaredExternalMakes :: EffectSemantics -> [ConstraintFact]
declaredExternalMakes semantics =
  [ ExternalMakeDeclared (sendContractName currentContract)
  | currentContract <- semanticSendContracts semantics
  ]

boundaryConstraints :: EffectSemantics -> [ConstraintFact]
boundaryConstraints semantics =
  map boundaryConstraint (semanticEffectBoundaries semantics)

boundaryConstraint :: EffectBoundary -> ConstraintFact
boundaryConstraint currentBoundary =
  case currentBoundary of
    BoundaryExternalMake currentFact currentSend currentInput currentOutput currentSource ->
      EffectBoundaryExternalMake currentFact currentSend currentInput currentOutput currentSource
    BoundaryInternalTake currentFact currentInput currentSource ->
      EffectBoundaryInternalTake currentFact currentInput currentSource
    BoundaryInternalMake currentFact currentOutput currentSource ->
      EffectBoundaryInternalMake currentFact currentOutput currentSource
    BoundaryExternalTake currentFact currentOutput currentSource ->
      EffectBoundaryExternalTake currentFact currentOutput currentSource

ruleConstraints :: [TakeMakeRule] -> [ConstraintFact]
ruleConstraints =
  concatMap ruleConstraint

ruleConstraint :: TakeMakeRule -> [ConstraintFact]
ruleConstraint currentRule =
  case takeMakeSource currentRule of
    ExternalTake ->
      map ExternalTakeFact (makeFacts currentRule)
        ++ map (PipeMakes ruleId) (pipeOutputTypes currentRule)
    InternalMake ->
      map (Makes ruleId) (makeFacts currentRule)
        ++ map (Takes ruleId) (takeFacts currentRule)
        ++ map (PipeNeeds ruleId) (pipeInputTypes currentRule)
        ++ map (PipeMakes ruleId) (pipeOutputTypes currentRule)
        ++ map pipeTakeConstraint (pipeTakeFacts currentRule)
        ++ map (UsesExternalMake ruleId) (externalMakeNames currentRule)
        ++ map transformConstraint (transformUses currentRule)
        ++ map (HandlesError ruleId) (errorHandlerNames currentRule)
        ++ map (FailureMakes ruleId) (failureMakeFacts currentRule)
  where
    ruleId =
      RuleId (takeMakeRuleFact currentRule)
    pipeTakeConstraint currentPipeTake =
      PipeTakes ruleId (pipeTakeInput currentPipeTake) (pipeTakeFact currentPipeTake)
    transformConstraint currentTransform =
      UsesTransform
        ruleId
        (transformUseName currentTransform)
        (transformUseInput currentTransform)
        (transformUseOutput currentTransform)

waitConstraints :: AppPlan -> [ConstraintFact]
waitConstraints =
  waitConstraintsFromBlueprint . appPlanBlueprint

waitConstraintsFromBlueprint :: AppBlueprint.AppBlueprint -> [ConstraintFact]
waitConstraintsFromBlueprint blueprint =
  collectWorkflowWaits RootScope (AppBlueprint.blueprintApp blueprint)
    ++ collectHangingWaits (AppBlueprint.blueprintHanging blueprint)

collectWorkflowWaits :: WorkflowScope -> Workflow WorkflowFact hook -> [ConstraintFact]
collectWorkflowWaits currentScope currentWorkflow =
  case currentWorkflow of
    FactWorkflow _ ->
      []
    ChainWorkflow label steps ->
      concatMap (collectWorkflowWaits (NamedScope label)) (freeMonadSteps (chainSteps steps))
    ParallelWorkflow label branches ->
      concatMap (collectWorkflowWaits (NamedScope label)) (freeApplicativeBranches (parallelBranches branches))
    FallbackWorkflow branches ->
      concatMap (collectWorkflowWaits currentScope) (freeAlternativeBranches (fallbackBranches branches))
    RaceWorkflow branches ->
      concatMap (collectWorkflowWaits currentScope) (freeAlternativeBranches (raceBranches branches))
    ChoiceWorkflow _ choices ->
      concatMap (collectChoiceWaits currentScope) (freeChoiceBranches (choiceBranches choices))
    WaitWorkflow currentWait body ->
      map (WaitsFor currentScope) (collectFactExpr (waitFacts currentWait))
        ++ collectWorkflowWaits currentScope body

collectChoiceWaits ::
  WorkflowScope ->
  ChoiceBranch key (Workflow WorkflowFact hook) ->
  [ConstraintFact]
collectChoiceWaits currentScope (ChoiceBranch _ branch) =
  collectWorkflowWaits currentScope branch

collectHangingWaits ::
  Hanging (HangingAction WorkflowFact hook (Workflow WorkflowFact hook)) ->
  [ConstraintFact]
collectHangingWaits actions =
  concatMap collectHangingActionWaits (freeMonoidItems (hangingActions actions))

collectHangingActionWaits ::
  HangingAction WorkflowFact hook (Workflow WorkflowFact hook) ->
  [ConstraintFact]
collectHangingActionWaits currentAction =
  case currentAction of
    HangingCallback currentCallback ->
      collectWorkflowWaits RootScope (callbackBody currentCallback)
    HangingSuspense _ ->
      []
    HangingLoop currentLoop ->
      collectWorkflowWaits RootScope (loopBody currentLoop)
    HangingMiddleware _ body ->
      collectWorkflowWaits RootScope body

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

checkConstraintFacts :: [ConstraintFact] -> [ConstraintError]
checkConstraintFacts facts =
  unique
    ( missingFactSources facts
        ++ missingTakeSources facts
        ++ missingPipeSources facts
        ++ missingPipeTakeSources facts
        ++ missingExternalMakes facts
        ++ externalTakeAutoMakes facts
        ++ duplicateMakers facts
        ++ duplicatePipeMakers facts
        ++ dependencyCycles facts
        ++ deadWaitCandidates facts
    )

missingFactSources :: [ConstraintFact] -> [ConstraintError]
missingFactSources facts =
  [ MissingFactSource currentFact
  | currentFact <- requiredFacts facts
  , not (hasFactSource facts currentFact)
  ]

missingTakeSources :: [ConstraintFact] -> [ConstraintError]
missingTakeSources facts =
  [ MissingTakeSource currentRule currentFact
  | (currentRule, currentFact) <- takenFacts facts
  , not (hasFactSource facts currentFact)
  ]

missingPipeSources :: [ConstraintFact] -> [ConstraintError]
missingPipeSources facts =
  [ MissingPipeSource currentRule currentType
  | (currentRule, currentType) <- pipeNeededTypes facts
  , currentType `notElem` pipeMadeTypes facts
  ]

missingPipeTakeSources :: [ConstraintFact] -> [ConstraintError]
missingPipeTakeSources facts =
  [ MissingPipeTakeSource currentRule currentType currentFact
  | (currentRule, currentType, currentFact) <- pipeTakenFacts facts
  , not (hasFactSource facts currentFact)
  ]

missingExternalMakes :: [ConstraintFact] -> [ConstraintError]
missingExternalMakes facts =
  [ MissingExternalMake currentRule currentSend
  | (currentRule, currentSend) <- usedExternalMakes facts ++ errorHandlers facts
  , currentSend `notElem` declaredExternalMakeNames facts
  ]

externalTakeAutoMakes :: [ConstraintFact] -> [ConstraintError]
externalTakeAutoMakes facts =
  [ ExternalTakeAutoMake currentFact
  | currentFact <- externalTakeFacts facts
  , currentFact `elem` internallyMadeFacts facts
  ]

duplicateMakers :: [ConstraintFact] -> [ConstraintError]
duplicateMakers facts =
  [ DuplicateMaker currentFact currentRules
  | currentFact <- unique (internallyMadeFacts facts)
  , let currentRules = makerRulesFor facts currentFact
  , length currentRules > 1
  ]

duplicatePipeMakers :: [ConstraintFact] -> [ConstraintError]
duplicatePipeMakers facts =
  [ DuplicatePipeMaker currentType currentRules
  | currentType <- unique (pipeMadeTypes facts)
  , let currentRules = pipeMakerRulesFor facts currentType
  , length currentRules > 1
  ]

dependencyCycles :: [ConstraintFact] -> [ConstraintError]
dependencyCycles facts =
  map DependencyCycle (unique (concatMap (cyclesFrom facts []) (internallyMadeFacts facts)))

deadWaitCandidates :: [ConstraintFact] -> [ConstraintError]
deadWaitCandidates facts =
  [ DeadWaitCandidate currentScope currentFact
  | (currentScope, currentFact) <- waitedFacts facts
  , not (hasFactSource facts currentFact)
  ]

requiredFacts :: [ConstraintFact] -> [WorkflowFact]
requiredFacts facts =
  [ currentFact
  | RequiresFact currentFact <- facts
  ]

internallyMadeFacts :: [ConstraintFact] -> [WorkflowFact]
internallyMadeFacts facts =
  [ currentFact
  | Makes _ currentFact <- facts
  ]

externalTakeFacts :: [ConstraintFact] -> [WorkflowFact]
externalTakeFacts facts =
  [ currentFact
  | ExternalTakeFact currentFact <- facts
  ]

hasFactSource :: [ConstraintFact] -> WorkflowFact -> Bool
hasFactSource facts currentFact =
  currentFact `elem` internallyMadeFacts facts
    || currentFact `elem` externalTakeFacts facts

takenFacts :: [ConstraintFact] -> [(RuleId, WorkflowFact)]
takenFacts facts =
  [ (currentRule, currentFact)
  | Takes currentRule currentFact <- facts
  ]

pipeNeededTypes :: [ConstraintFact] -> [(RuleId, TypeName)]
pipeNeededTypes facts =
  [ (currentRule, currentType)
  | PipeNeeds currentRule currentType <- facts
  ]

pipeMadeTypes :: [ConstraintFact] -> [TypeName]
pipeMadeTypes facts =
  [ currentType
  | PipeMakes _ currentType <- facts
  ]

pipeTakenFacts :: [ConstraintFact] -> [(RuleId, TypeName, WorkflowFact)]
pipeTakenFacts facts =
  [ (currentRule, currentType, currentFact)
  | PipeTakes currentRule currentType currentFact <- facts
  ]

usedExternalMakes :: [ConstraintFact] -> [(RuleId, SendName)]
usedExternalMakes facts =
  [ (currentRule, currentSend)
  | UsesExternalMake currentRule currentSend <- facts
  ]

errorHandlers :: [ConstraintFact] -> [(RuleId, SendName)]
errorHandlers facts =
  [ (currentRule, currentSend)
  | HandlesError currentRule currentSend <- facts
  ]

declaredExternalMakeNames :: [ConstraintFact] -> [SendName]
declaredExternalMakeNames facts =
  [ currentSend
  | ExternalMakeDeclared currentSend <- facts
  ]

waitedFacts :: [ConstraintFact] -> [(WorkflowScope, WorkflowFact)]
waitedFacts facts =
  [ (currentScope, currentFact)
  | WaitsFor currentScope currentFact <- facts
  ]

makerRulesFor :: [ConstraintFact] -> WorkflowFact -> [RuleId]
makerRulesFor facts currentFact =
  [ currentRule
  | Makes currentRule madeFact <- facts
  , madeFact == currentFact
  ]

pipeMakerRulesFor :: [ConstraintFact] -> TypeName -> [RuleId]
pipeMakerRulesFor facts currentType =
  [ currentRule
  | PipeMakes currentRule madeType <- facts
  , madeType == currentType
  ]

cyclesFrom :: [ConstraintFact] -> [WorkflowFact] -> WorkflowFact -> [[WorkflowFact]]
cyclesFrom facts stack currentFact
  | currentFact `elem` stack =
      [reverse (currentFact : takeUntil currentFact stack)]
  | otherwise =
      concatMap (cyclesFrom facts (currentFact : stack)) (dependenciesForFact facts currentFact)

dependenciesForFact :: [ConstraintFact] -> WorkflowFact -> [WorkflowFact]
dependenciesForFact facts currentFact =
  unique
    ( [ neededFact
      | currentRule <- makerRulesFor facts currentFact
      , (takenByRule, neededFact) <- takenFacts facts
      , takenByRule == currentRule
      ]
        ++ [ neededFact
           | currentRule <- makerRulesFor facts currentFact
           , (takenByRule, _, neededFact) <- pipeTakenFacts facts
           , takenByRule == currentRule
           ]
    )

takeUntil :: Eq item => item -> [item] -> [item]
takeUntil _ [] =
  []
takeUntil item (currentItem : rest)
  | item == currentItem =
      [currentItem]
  | otherwise =
      currentItem : takeUntil item rest

renderConstraintFacts :: [ConstraintFact] -> String
renderConstraintFacts =
  joinWith "\n" . map renderConstraintFact

renderConstraintFact :: ConstraintFact -> String
renderConstraintFact (RequiresFact currentFact) =
  "requiresFact " ++ show currentFact
renderConstraintFact (EffectBoundaryExternalMake currentFact currentSend currentInput currentOutput currentSource) =
  "effectBoundary externalMake "
    ++ show currentFact
    ++ " "
    ++ show currentSend
    ++ " "
    ++ show currentInput
    ++ " "
    ++ show currentOutput
    ++ " "
    ++ renderBoundarySource currentSource
renderConstraintFact (EffectBoundaryInternalTake currentFact currentInput currentSource) =
  "effectBoundary internalTake "
    ++ show currentFact
    ++ " "
    ++ show currentInput
    ++ " "
    ++ renderBoundarySource currentSource
renderConstraintFact (EffectBoundaryInternalMake currentFact currentOutput currentSource) =
  "effectBoundary internalMake "
    ++ show currentFact
    ++ " "
    ++ show currentOutput
    ++ " "
    ++ renderBoundarySource currentSource
renderConstraintFact (EffectBoundaryExternalTake currentFact currentOutput currentSource) =
  "effectBoundary externalTake "
    ++ show currentFact
    ++ " "
    ++ renderMaybeTypeName currentOutput
    ++ " "
    ++ renderBoundarySource currentSource
renderConstraintFact (ExternalMakeDeclared currentSend) =
  "externalMakeDeclared " ++ show currentSend
renderConstraintFact (Makes currentRule currentFact) =
  "makes " ++ renderRuleId currentRule ++ " " ++ show currentFact
renderConstraintFact (Takes currentRule currentFact) =
  "takes " ++ renderRuleId currentRule ++ " " ++ show currentFact
renderConstraintFact (PipeNeeds currentRule currentType) =
  "pipeNeeds " ++ renderRuleId currentRule ++ " " ++ show currentType
renderConstraintFact (PipeMakes currentRule currentType) =
  "pipeMakes " ++ renderRuleId currentRule ++ " " ++ show currentType
renderConstraintFact (PipeTakes currentRule currentType currentFact) =
  "pipeTakes " ++ renderRuleId currentRule ++ " " ++ show currentType ++ " " ++ show currentFact
renderConstraintFact (UsesExternalMake currentRule currentSend) =
  "usesExternalMake " ++ renderRuleId currentRule ++ " " ++ show currentSend
renderConstraintFact (UsesTransform currentRule currentTransform currentInput currentOutput) =
  "usesTransform "
    ++ renderRuleId currentRule
    ++ " "
    ++ show currentTransform
    ++ " "
    ++ show currentInput
    ++ " "
    ++ show currentOutput
renderConstraintFact (HandlesError currentRule currentSend) =
  "handlesError " ++ renderRuleId currentRule ++ " " ++ show currentSend
renderConstraintFact (FailureMakes currentRule currentFact) =
  "failureMakes " ++ renderRuleId currentRule ++ " " ++ show currentFact
renderConstraintFact (ExternalTakeFact currentFact) =
  "externalTake " ++ show currentFact
renderConstraintFact (WaitsFor currentScope currentFact) =
  "waitsFor " ++ renderWorkflowScope currentScope ++ " " ++ show currentFact

renderConstraintError :: ConstraintError -> String
renderConstraintError (MissingFactSource currentFact) =
  "missing source for fact " ++ show currentFact
renderConstraintError (MissingTakeSource currentRule currentFact) =
  renderRuleId currentRule ++ " takes fact without source " ++ show currentFact
renderConstraintError (MissingPipeSource currentRule currentType) =
  renderRuleId currentRule ++ " needs pipe input without output source " ++ show currentType
renderConstraintError (MissingPipeTakeSource currentRule currentType currentFact) =
  renderRuleId currentRule ++ " takes pipe input " ++ show currentType ++ " from fact without source " ++ show currentFact
renderConstraintError (MissingExternalMake currentRule currentSend) =
  renderRuleId currentRule ++ " uses undeclared externalMake " ++ show currentSend
renderConstraintError (ExternalTakeAutoMake currentFact) =
  "externalTake fact is also internally made " ++ show currentFact
renderConstraintError (DuplicateMaker currentFact currentRules) =
  "duplicate makers for fact " ++ show currentFact ++ ": " ++ joinWith ", " (map renderRuleId currentRules)
renderConstraintError (DuplicatePipeMaker currentType currentRules) =
  "duplicate pipe makers for " ++ show currentType ++ ": " ++ joinWith ", " (map renderRuleId currentRules)
renderConstraintError (DependencyCycle currentFacts) =
  "take/make dependency cycle: " ++ joinWith " -> " (map show currentFacts)
renderConstraintError (DeadWaitCandidate currentScope currentFact) =
  "wait in " ++ renderWorkflowScope currentScope ++ " has no visible source for " ++ show currentFact

renderRuleId :: RuleId -> String
renderRuleId (RuleId currentFact) =
  "rule(" ++ show currentFact ++ ")"

renderWorkflowScope :: WorkflowScope -> String
renderWorkflowScope RootScope =
  "root"
renderWorkflowScope (NamedScope currentName) =
  show currentName

renderMaybeTypeName :: Maybe TypeName -> String
renderMaybeTypeName Nothing =
  "NoOutput"
renderMaybeTypeName (Just currentType) =
  show currentType

renderBoundarySource :: BoundarySource -> String
renderBoundarySource currentSource =
  case currentSource of
    DerivedFromUses currentSend ->
      "derivedFromUses(" ++ show currentSend ++ ")"
    DerivedFromTransform currentTransform ->
      "derivedFromTransform(" ++ show currentTransform ++ ")"
    DeclaredExplicitly ->
      "declaredExplicitly"
    DeclaredExternalTake ->
      "declaredExternalTake"

unique :: Eq item => [item] -> [item]
unique =
  foldl addUnique []
  where
    addUnique items item
      | item `elem` items = items
      | otherwise = items ++ [item]

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
