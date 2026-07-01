module Core.Language.Elaboration
  ( ElaborationConstraintFact (..)
  , ElaborationContract (..)
  , ElaborationError (..)
  , ElaboratorBinding (..)
  , ElaboratorImplementation (..)
  , checkDefaultElaborationContract
  , checkElaborationContract
  , defaultElaborationConstraints
  , defaultElaborationContract
  , elaborationConstraintsFromSpec
  , elaborationContractValid
  , elaborator
  , renderElaborationConstraintFact
  , renderElaborationConstraintFacts
  , renderElaborationError
  ) where

import Core.Language.Spec
  ( KeywordName
  , KeywordSpec (..)
  , LanguageSpec (..)
  , LoweringTarget (..)
  , SyntaxKind (..)
  , defaultLanguageSpec
  , keywordNameText
  )

newtype ElaboratorImplementation = ElaboratorImplementation String
  deriving (Eq, Show)

data ElaboratorBinding = ElaboratorBinding
  { elaboratorTarget :: LoweringTarget
  , elaboratorImplementation :: ElaboratorImplementation
  , elaboratorResult :: SyntaxKind
  }
  deriving (Eq, Show)

newtype ElaborationContract = ElaborationContract
  { elaborationBindings :: [ElaboratorBinding]
  }
  deriving (Eq, Show)

data ElaborationError
  = MissingElaborator KeywordName LoweringTarget
  | DuplicateElaborator LoweringTarget [ElaboratorImplementation]
  | UnusedElaborator LoweringTarget ElaboratorImplementation
  | ElaborationResultMismatch KeywordName LoweringTarget SyntaxKind SyntaxKind
  | PendingElaboration KeywordName String
  deriving (Eq, Show)

data ElaborationConstraintFact
  = ElaboratorDeclared LoweringTarget ElaboratorImplementation
  | ElaboratorResultKind LoweringTarget SyntaxKind
  | KeywordElaborates KeywordName LoweringTarget
  deriving (Eq, Show)

elaborator :: LoweringTarget -> String -> SyntaxKind -> ElaboratorBinding
elaborator target implementation result =
  ElaboratorBinding
    { elaboratorTarget = target
    , elaboratorImplementation = ElaboratorImplementation implementation
    , elaboratorResult = result
    }

defaultElaborationContract :: ElaborationContract
defaultElaborationContract =
  ElaborationContract
    { elaborationBindings =
        [ elaborator LowerToAppBuild "Core.App.app" AppPlanSyntax
        , elaborator LowerToCurrentAst "Domain.AppBlueprint.blueprint" AppBlueprintSyntax
        , elaborator LowerToCurrentEffects "Effects.Theory.effectTheory" EffectTheorySyntax
        , elaborator LowerToInterpretConfig "Interpreter.Runtime.runBlueprintWithEffects" RuntimeProgramSyntax
        , elaborator LowerToTheory "Effects.EffectTheory.theory" EffectTheorySyntax
        , elaborator LowerToEffect "Effects.EffectTheory.effect" EffectUnitSyntax
        , elaborator LowerToEffectFact "Effects.EffectTheory.fact" EffectSectionSyntax
        , elaborator LowerToNeeds "Effects.EffectTheory.needs" ProducerStepSyntax
        , elaborator LowerToUses "Effects.EffectTheory.uses" ProducerStepSyntax
        , elaborator LowerToTake "Effects.EffectTheory.take" ProducerStepSyntax
        , elaborator LowerToMake "Effects.EffectTheory.make" ProducerStepSyntax
        , elaborator LowerToTransform "Effects.EffectTheory.transform" ProducerStepSyntax
        , elaborator LowerToError "Effects.EffectTheory.error" ProducerStepSyntax
        , elaborator LowerToOnFailure "Effects.EffectTheory.onFailure" ProducerStepSyntax
        , elaborator LowerToExternalMake "Effects.EffectTheory.externalMake" EffectSectionSyntax
        , elaborator LowerToIdempotent "Effects.EffectTheory.idempotent" EffectSectionSyntax
        , elaborator LowerToRetry "Effects.EffectTheory.retry" EffectSectionSyntax
        , elaborator LowerToExternalTake "Effects.EffectTheory.externalTake" EffectSectionSyntax
        , elaborator LowerToHanging "Framework.Workflow.hanging" HangingBlockSyntax
        , elaborator LowerToChain "Framework.Workflow.chain" WorkflowComponentSyntax
        , elaborator LowerToParallel "Framework.Workflow.parallel" WorkflowComponentSyntax
        , elaborator LowerToWorkflowFact "Framework.Workflow.fact" WorkflowComponentSyntax
        , elaborator LowerToAllOf "Framework.Workflow.factAll" FactExprSyntax
        , elaborator LowerToAnyOf "Framework.Workflow.factAny" FactExprSyntax
        , elaborator LowerToWait "Framework.Workflow.wait" WorkflowComponentSyntax
        , elaborator LowerToFallback "Framework.Workflow.fallback" WorkflowComponentSyntax
        , elaborator LowerToRace "Framework.Workflow.race" WorkflowComponentSyntax
        , elaborator LowerToChoice "Framework.Workflow.choice" WorkflowComponentSyntax
        , elaborator LowerToChoiceBranch "Core.Architecture.choiceBranch" ChoiceBranchSyntax
        , elaborator LowerToMiddleware "Framework.Workflow.middleware" HangingComponentSyntax
        , elaborator LowerToCallback "Framework.Workflow.callback" HangingComponentSyntax
        , elaborator LowerToSuspense "Framework.Workflow.suspense" HangingComponentSyntax
        , elaborator LowerToLoop "Framework.Workflow.loop" HangingComponentSyntax
        ]
    }

checkDefaultElaborationContract :: [ElaborationError]
checkDefaultElaborationContract =
  checkElaborationContract defaultLanguageSpec defaultElaborationContract

checkElaborationContract :: LanguageSpec -> ElaborationContract -> [ElaborationError]
checkElaborationContract spec contract =
  unique
    ( concatMap (checkKeywordElaboration bindings) (languageKeywords spec)
        ++ duplicateElaborators bindings
        ++ unusedElaborators (languageKeywords spec) bindings
    )
  where
    bindings =
      elaborationBindings contract

elaborationContractValid :: LanguageSpec -> ElaborationContract -> Bool
elaborationContractValid spec contract =
  null (checkElaborationContract spec contract)

checkKeywordElaboration :: [ElaboratorBinding] -> KeywordSpec -> [ElaborationError]
checkKeywordElaboration bindings currentKeyword =
  case keywordLowering currentKeyword of
    LoweringPending reason ->
      [PendingElaboration (keywordName currentKeyword) reason]
    currentTarget ->
      case bindingForTarget bindings currentTarget of
        Nothing ->
          [MissingElaborator (keywordName currentKeyword) currentTarget]
        Just currentBinding
          | elaboratorResult currentBinding == keywordResult currentKeyword ->
              []
          | otherwise ->
              [ ElaborationResultMismatch
                  (keywordName currentKeyword)
                  currentTarget
                  (keywordResult currentKeyword)
                  (elaboratorResult currentBinding)
              ]

duplicateElaborators :: [ElaboratorBinding] -> [ElaborationError]
duplicateElaborators bindings =
  [ DuplicateElaborator currentTarget (map elaboratorImplementation currentBindings)
  | currentTarget <- unique (map elaboratorTarget bindings)
  , let currentBindings = bindingsForTarget bindings currentTarget
  , length currentBindings > 1
  ]

unusedElaborators :: [KeywordSpec] -> [ElaboratorBinding] -> [ElaborationError]
unusedElaborators keywords bindings =
  [ UnusedElaborator (elaboratorTarget currentBinding) (elaboratorImplementation currentBinding)
  | currentBinding <- bindings
  , elaboratorTarget currentBinding `notElem` keywordTargets keywords
  ]

keywordTargets :: [KeywordSpec] -> [LoweringTarget]
keywordTargets keywords =
  [ currentTarget
  | currentKeyword <- keywords
  , let currentTarget = keywordLowering currentKeyword
  , not (isPending currentTarget)
  ]

isPending :: LoweringTarget -> Bool
isPending target =
  case target of
    LoweringPending _ ->
      True
    _ ->
      False

bindingForTarget :: [ElaboratorBinding] -> LoweringTarget -> Maybe ElaboratorBinding
bindingForTarget bindings target =
  case bindingsForTarget bindings target of
    currentBinding : _ ->
      Just currentBinding
    [] ->
      Nothing

bindingsForTarget :: [ElaboratorBinding] -> LoweringTarget -> [ElaboratorBinding]
bindingsForTarget bindings target =
  [ currentBinding
  | currentBinding <- bindings
  , elaboratorTarget currentBinding == target
  ]

defaultElaborationConstraints :: [ElaborationConstraintFact]
defaultElaborationConstraints =
  elaborationConstraintsFromSpec defaultLanguageSpec defaultElaborationContract

elaborationConstraintsFromSpec ::
  LanguageSpec ->
  ElaborationContract ->
  [ElaborationConstraintFact]
elaborationConstraintsFromSpec spec contract =
  unique
    ( concatMap bindingConstraints (elaborationBindings contract)
        ++ keywordElaborationConstraints (languageKeywords spec)
    )

bindingConstraints :: ElaboratorBinding -> [ElaborationConstraintFact]
bindingConstraints currentBinding =
  [ ElaboratorDeclared (elaboratorTarget currentBinding) (elaboratorImplementation currentBinding)
  , ElaboratorResultKind (elaboratorTarget currentBinding) (elaboratorResult currentBinding)
  ]

keywordElaborationConstraints :: [KeywordSpec] -> [ElaborationConstraintFact]
keywordElaborationConstraints keywords =
  [ KeywordElaborates (keywordName currentKeyword) currentTarget
  | currentKeyword <- keywords
  , let currentTarget = keywordLowering currentKeyword
  , not (isPending currentTarget)
  ]

renderElaborationConstraintFacts :: [ElaborationConstraintFact] -> String
renderElaborationConstraintFacts =
  joinWith "\n" . map renderElaborationConstraintFact

renderElaborationConstraintFact :: ElaborationConstraintFact -> String
renderElaborationConstraintFact currentFact =
  case currentFact of
    ElaboratorDeclared currentTarget implementation ->
      "elaboratorDeclared " ++ show currentTarget ++ " " ++ renderImplementation implementation
    ElaboratorResultKind currentTarget currentKind ->
      "elaboratorResultKind " ++ show currentTarget ++ " " ++ show currentKind
    KeywordElaborates currentName currentTarget ->
      "keywordElaborates " ++ keywordNameText currentName ++ " " ++ show currentTarget

renderElaborationError :: ElaborationError -> String
renderElaborationError currentError =
  case currentError of
    MissingElaborator currentName currentTarget ->
      "missing elaborator for " ++ keywordNameText currentName ++ " -> " ++ show currentTarget
    DuplicateElaborator currentTarget implementations ->
      "duplicate elaborator for "
        ++ show currentTarget
        ++ ": "
        ++ joinWith ", " (map renderImplementation implementations)
    UnusedElaborator currentTarget implementation ->
      "unused elaborator "
        ++ renderImplementation implementation
        ++ " for "
        ++ show currentTarget
    ElaborationResultMismatch currentName currentTarget expected actual ->
      "elaborator result mismatch for "
        ++ keywordNameText currentName
        ++ " -> "
        ++ show currentTarget
        ++ ": expected "
        ++ show expected
        ++ ", got "
        ++ show actual
    PendingElaboration currentName reason ->
      "pending elaboration for " ++ keywordNameText currentName ++ " (" ++ reason ++ ")"

renderImplementation :: ElaboratorImplementation -> String
renderImplementation (ElaboratorImplementation implementation) =
  implementation

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
