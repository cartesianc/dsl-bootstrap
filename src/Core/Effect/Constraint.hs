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
  , Suspense (..)
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
  ( EffectSemantics (..)
  , HandlerContract (..)
  , ProfileContract (..)
  , SendContract (..)
  , TakeMakeRule (..)
  , TakeMakeSource (..)
  )
import Effects.EffectTheory
  ( ProfileName
  , SendName
  )

newtype RuleId = RuleId WorkflowFact
  deriving (Eq, Show)

data WorkflowScope
  = RootScope
  | NamedScope WorkflowName
  deriving (Eq, Show)

data ConstraintFact
  = ActiveProfile ProfileName
  | RequiresFact WorkflowFact
  | ExternalMakeDeclared SendName
  | Makes RuleId WorkflowFact
  | Takes RuleId WorkflowFact
  | UsesExternalMake RuleId SendName
  | FailureMakes RuleId WorkflowFact
  | Implements ProfileName SendName
  | ExternalTakeFact WorkflowFact
  | WaitsFor WorkflowScope WorkflowFact
  deriving (Eq, Show)

data ConstraintError
  = MissingFactSource WorkflowFact
  | MissingTakeSource RuleId WorkflowFact
  | MissingExternalMake RuleId SendName
  | MissingImplementation ProfileName SendName
  | ExternalTakeAutoMake WorkflowFact
  | DuplicateMaker WorkflowFact [RuleId]
  | DependencyCycle [WorkflowFact]
  | DeadWaitCandidate WorkflowScope WorkflowFact
  deriving (Eq, Show)

constraintsFromAppPlan :: AppPlan -> [ConstraintFact]
constraintsFromAppPlan appPlan =
  unique
    ( [ActiveProfile (appPlanProfile appPlan)]
        ++ map RequiresFact (appPlanFacts appPlan)
        ++ declaredExternalMakes (appPlanEffectSemantics appPlan)
        ++ ruleConstraints (appPlanTakeMakeRules appPlan)
        ++ implementationConstraints (appPlanEffectSemantics appPlan)
        ++ waitConstraints appPlan
    )

declaredExternalMakes :: EffectSemantics -> [ConstraintFact]
declaredExternalMakes semantics =
  [ ExternalMakeDeclared (sendContractName currentContract)
  | currentContract <- semanticSendContracts semantics
  ]

ruleConstraints :: [TakeMakeRule] -> [ConstraintFact]
ruleConstraints =
  concatMap ruleConstraint

ruleConstraint :: TakeMakeRule -> [ConstraintFact]
ruleConstraint currentRule =
  case takeMakeSource currentRule of
    ExternalTake ->
      map ExternalTakeFact (makeFacts currentRule)
    InternalMake ->
      map (Makes ruleId) (makeFacts currentRule)
        ++ map (Takes ruleId) (takeFacts currentRule)
        ++ map (UsesExternalMake ruleId) (externalMakeNames currentRule)
        ++ map (FailureMakes ruleId) (failureMakeFacts currentRule)
  where
    ruleId =
      RuleId (takeMakeRuleFact currentRule)

implementationConstraints :: EffectSemantics -> [ConstraintFact]
implementationConstraints semantics =
  [ Implements (profileContractName currentProfile) (handlerContractSend currentHandler)
  | currentProfile <- semanticProfileContracts semantics
  , currentHandler <- profileContractHandlers currentProfile
  ]

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
      map (WaitsFor RootScope) (collectFactExpr (callbackFacts currentCallback))
        ++ collectWorkflowWaits RootScope (callbackBody currentCallback)
    HangingSuspense currentSuspense ->
      map (WaitsFor RootScope) (collectFactExpr (suspenseFacts currentSuspense))
        ++ collectWorkflowWaits RootScope (suspenseTarget currentSuspense)
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
        ++ missingExternalMakes facts
        ++ missingImplementations facts
        ++ externalTakeAutoMakes facts
        ++ duplicateMakers facts
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

missingExternalMakes :: [ConstraintFact] -> [ConstraintError]
missingExternalMakes facts =
  [ MissingExternalMake currentRule currentSend
  | (currentRule, currentSend) <- usedExternalMakes facts
  , currentSend `notElem` declaredExternalMakeNames facts
  ]

missingImplementations :: [ConstraintFact] -> [ConstraintError]
missingImplementations facts =
  [ MissingImplementation currentProfile currentSend
  | currentProfile <- activeProfiles facts
  , currentSend <- unique (map snd (usedExternalMakes facts))
  , (currentProfile, currentSend) `notElem` implementedSends facts
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

usedExternalMakes :: [ConstraintFact] -> [(RuleId, SendName)]
usedExternalMakes facts =
  [ (currentRule, currentSend)
  | UsesExternalMake currentRule currentSend <- facts
  ]

declaredExternalMakeNames :: [ConstraintFact] -> [SendName]
declaredExternalMakeNames facts =
  [ currentSend
  | ExternalMakeDeclared currentSend <- facts
  ]

implementedSends :: [ConstraintFact] -> [(ProfileName, SendName)]
implementedSends facts =
  [ (currentProfile, currentSend)
  | Implements currentProfile currentSend <- facts
  ]

activeProfiles :: [ConstraintFact] -> [ProfileName]
activeProfiles facts =
  [ currentProfile
  | ActiveProfile currentProfile <- facts
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

cyclesFrom :: [ConstraintFact] -> [WorkflowFact] -> WorkflowFact -> [[WorkflowFact]]
cyclesFrom facts stack currentFact
  | currentFact `elem` stack =
      [reverse (currentFact : takeUntil currentFact stack)]
  | otherwise =
      concatMap (cyclesFrom facts (currentFact : stack)) (dependenciesForFact facts currentFact)

dependenciesForFact :: [ConstraintFact] -> WorkflowFact -> [WorkflowFact]
dependenciesForFact facts currentFact =
  [ neededFact
  | currentRule <- makerRulesFor facts currentFact
  , (takenByRule, neededFact) <- takenFacts facts
  , takenByRule == currentRule
  ]

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
renderConstraintFact (ActiveProfile currentProfile) =
  "activeProfile " ++ show currentProfile
renderConstraintFact (RequiresFact currentFact) =
  "requiresFact " ++ show currentFact
renderConstraintFact (ExternalMakeDeclared currentSend) =
  "externalMakeDeclared " ++ show currentSend
renderConstraintFact (Makes currentRule currentFact) =
  "makes " ++ renderRuleId currentRule ++ " " ++ show currentFact
renderConstraintFact (Takes currentRule currentFact) =
  "takes " ++ renderRuleId currentRule ++ " " ++ show currentFact
renderConstraintFact (UsesExternalMake currentRule currentSend) =
  "usesExternalMake " ++ renderRuleId currentRule ++ " " ++ show currentSend
renderConstraintFact (FailureMakes currentRule currentFact) =
  "failureMakes " ++ renderRuleId currentRule ++ " " ++ show currentFact
renderConstraintFact (Implements currentProfile currentSend) =
  "implements " ++ show currentProfile ++ " " ++ show currentSend
renderConstraintFact (ExternalTakeFact currentFact) =
  "externalTake " ++ show currentFact
renderConstraintFact (WaitsFor currentScope currentFact) =
  "waitsFor " ++ renderWorkflowScope currentScope ++ " " ++ show currentFact

renderConstraintError :: ConstraintError -> String
renderConstraintError (MissingFactSource currentFact) =
  "missing source for fact " ++ show currentFact
renderConstraintError (MissingTakeSource currentRule currentFact) =
  renderRuleId currentRule ++ " takes fact without source " ++ show currentFact
renderConstraintError (MissingExternalMake currentRule currentSend) =
  renderRuleId currentRule ++ " uses undeclared externalMake " ++ show currentSend
renderConstraintError (MissingImplementation currentProfile currentSend) =
  "profile " ++ show currentProfile ++ " does not implement externalMake " ++ show currentSend
renderConstraintError (ExternalTakeAutoMake currentFact) =
  "externalTake fact is also internally made " ++ show currentFact
renderConstraintError (DuplicateMaker currentFact currentRules) =
  "duplicate makers for fact " ++ show currentFact ++ ": " ++ joinWith ", " (map renderRuleId currentRules)
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
