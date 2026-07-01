module Core.Language.Spec
  ( ArgumentCardinality (..)
  , ArgumentSpec (..)
  , KeywordName (..)
  , KeywordSpec (..)
  , LanguageSpec (..)
  , LoweringTarget (..)
  , SyntaxKind (..)
  , defaultLanguageSpec
  , keyword
  , keywordNameText
  , required
  , many
  , optional
  ) where

newtype KeywordName = KeywordName String
  deriving (Eq, Show)

data SyntaxKind
  = RootSyntax
  | AppBlueprintSyntax
  | AppPlanSyntax
  | RuntimeProgramSyntax
  | EffectTheorySyntax
  | EffectUnitSyntax
  | EffectSectionSyntax
  | ProducerStepSyntax
  | WorkflowComponentSyntax
  | ChoiceBranchSyntax
  | HangingBlockSyntax
  | HangingComponentSyntax
  | FactExprSyntax
  | FactNameSyntax
  | WorkflowNameSyntax
  | InterceptorSyntax
  | ChoiceKeySyntax
  | EffectNameSyntax
  | SendNameSyntax
  | TransformNameSyntax
  | TypeNameSyntax
  deriving (Eq, Show)

data ArgumentCardinality
  = RequiredArgument
  | OptionalArgument
  | ManyArguments
  deriving (Eq, Show)

data ArgumentSpec = ArgumentSpec
  { argumentLabel :: String
  , argumentKind :: SyntaxKind
  , argumentCardinality :: ArgumentCardinality
  }
  deriving (Eq, Show)

data LoweringTarget
  = LowerToAppBuild
  | LowerToCurrentAst
  | LowerToCurrentEffects
  | LowerToInterpretConfig
  | LowerToTheory
  | LowerToEffect
  | LowerToEffectFact
  | LowerToNeeds
  | LowerToUses
  | LowerToTake
  | LowerToMake
  | LowerToTransform
  | LowerToError
  | LowerToOnFailure
  | LowerToExternalMake
  | LowerToExternalTake
  | LowerToIdempotent
  | LowerToRetry
  | LowerToHanging
  | LowerToChain
  | LowerToParallel
  | LowerToWorkflowFact
  | LowerToAllOf
  | LowerToAnyOf
  | LowerToWait
  | LowerToFallback
  | LowerToRace
  | LowerToChoice
  | LowerToChoiceBranch
  | LowerToMiddleware
  | LowerToCallback
  | LowerToSuspense
  | LowerToLoop
  | LoweringPending String
  deriving (Eq, Show)

data KeywordSpec = KeywordSpec
  { keywordName :: KeywordName
  , keywordArguments :: [ArgumentSpec]
  , keywordResult :: SyntaxKind
  , keywordParents :: [SyntaxKind]
  , keywordLowering :: LoweringTarget
  }
  deriving (Eq, Show)

newtype LanguageSpec = LanguageSpec
  { languageKeywords :: [KeywordSpec]
  }
  deriving (Eq, Show)

keyword ::
  String ->
  [ArgumentSpec] ->
  SyntaxKind ->
  [SyntaxKind] ->
  LoweringTarget ->
  KeywordSpec
keyword name arguments result parents lowering =
  KeywordSpec
    { keywordName = KeywordName name
    , keywordArguments = arguments
    , keywordResult = result
    , keywordParents = parents
    , keywordLowering = lowering
    }

required :: String -> SyntaxKind -> ArgumentSpec
required label kind =
  ArgumentSpec label kind RequiredArgument

many :: String -> SyntaxKind -> ArgumentSpec
many label kind =
  ArgumentSpec label kind ManyArguments

optional :: String -> SyntaxKind -> ArgumentSpec
optional label kind =
  ArgumentSpec label kind OptionalArgument

keywordNameText :: KeywordName -> String
keywordNameText (KeywordName name) =
  name

defaultLanguageSpec :: LanguageSpec
defaultLanguageSpec =
  LanguageSpec
    { languageKeywords =
        [ keyword "ast"
            [ required "workflow" WorkflowComponentSyntax
            , required "hanging" HangingBlockSyntax
            ]
            AppBlueprintSyntax
            [RootSyntax]
            LowerToCurrentAst
        , keyword "effects"
            [many "units" EffectUnitSyntax]
            EffectTheorySyntax
            [RootSyntax]
            LowerToCurrentEffects
        , keyword "interpret"
            [ required "ast" AppBlueprintSyntax
            , required "effects" EffectTheorySyntax
            ]
            RuntimeProgramSyntax
            [RootSyntax]
            LowerToInterpretConfig
        , keyword "app"
            [ required "ast" AppBlueprintSyntax
            , required "effects" EffectTheorySyntax
            ]
            AppPlanSyntax
            [RootSyntax]
            LowerToAppBuild
        , keyword "theory"
            [many "units" EffectUnitSyntax]
            EffectTheorySyntax
            [EffectTheorySyntax]
            LowerToTheory
        , keyword "effect"
            [ required "name" EffectNameSyntax
            , many "sections" EffectSectionSyntax
            ]
            EffectUnitSyntax
            [EffectTheorySyntax]
            LowerToEffect
        , keyword "fact"
            [ required "fact" FactNameSyntax
            , many "steps" ProducerStepSyntax
            ]
            EffectSectionSyntax
            [EffectUnitSyntax]
            LowerToEffectFact
        , keyword "needs"
            [required "fact" FactNameSyntax]
            ProducerStepSyntax
            [EffectSectionSyntax]
            LowerToNeeds
        , keyword "uses"
            [required "send" SendNameSyntax]
            ProducerStepSyntax
            [EffectSectionSyntax]
            LowerToUses
        , keyword "take"
            [required "input" TypeNameSyntax]
            ProducerStepSyntax
            [EffectSectionSyntax]
            LowerToTake
        , keyword "make"
            [required "output" TypeNameSyntax]
            ProducerStepSyntax
            [EffectSectionSyntax]
            LowerToMake
        , keyword "transform"
            [ required "input" TypeNameSyntax
            , required "output" TypeNameSyntax
            , required "transform" TransformNameSyntax
            ]
            ProducerStepSyntax
            [EffectSectionSyntax]
            LowerToTransform
        , keyword "error"
            [required "send" SendNameSyntax]
            ProducerStepSyntax
            [EffectSectionSyntax]
            LowerToError
        , keyword "onFailure"
            [required "fact" FactNameSyntax]
            ProducerStepSyntax
            [EffectSectionSyntax]
            LowerToOnFailure
        , keyword "externalMake"
            [ required "send" SendNameSyntax
            , required "input" TypeNameSyntax
            , required "output" TypeNameSyntax
            ]
            EffectSectionSyntax
            [EffectUnitSyntax]
            LowerToExternalMake
        , keyword "idempotent"
            [required "send" SendNameSyntax]
            EffectSectionSyntax
            [EffectUnitSyntax]
            LowerToIdempotent
        , keyword "retry"
            [required "send" SendNameSyntax]
            EffectSectionSyntax
            [EffectUnitSyntax]
            LowerToRetry
        , keyword "externalTake"
            [ required "fact" FactNameSyntax
            , optional "output" TypeNameSyntax
            ]
            EffectSectionSyntax
            [EffectUnitSyntax]
            LowerToExternalTake
        , keyword "hanging"
            [many "actions" HangingComponentSyntax]
            HangingBlockSyntax
            [AppBlueprintSyntax]
            LowerToHanging
        , keyword "chain"
            [ required "name" WorkflowNameSyntax
            , many "steps" WorkflowComponentSyntax
            ]
            WorkflowComponentSyntax
            [WorkflowComponentSyntax]
            LowerToChain
        , keyword "parallel"
            [ required "name" WorkflowNameSyntax
            , many "branches" WorkflowComponentSyntax
            ]
            WorkflowComponentSyntax
            [WorkflowComponentSyntax]
            LowerToParallel
        , keyword "fact"
            [required "facts" FactExprSyntax]
            WorkflowComponentSyntax
            [WorkflowComponentSyntax]
            LowerToWorkflowFact
        , keyword "wait"
            [ required "facts" FactExprSyntax
            , required "body" WorkflowComponentSyntax
            ]
            WorkflowComponentSyntax
            [WorkflowComponentSyntax]
            LowerToWait
        , keyword "fallback"
            [many "branches" WorkflowComponentSyntax]
            WorkflowComponentSyntax
            [WorkflowComponentSyntax]
            LowerToFallback
        , keyword "race"
            [many "branches" WorkflowComponentSyntax]
            WorkflowComponentSyntax
            [WorkflowComponentSyntax]
            LowerToRace
        , keyword "choice"
            [ required "selected" ChoiceKeySyntax
            , many "branches" ChoiceBranchSyntax
            ]
            WorkflowComponentSyntax
            [WorkflowComponentSyntax]
            LowerToChoice
        , keyword "choiceBranch"
            [ required "key" ChoiceKeySyntax
            , required "body" WorkflowComponentSyntax
            ]
            ChoiceBranchSyntax
            [WorkflowComponentSyntax]
            LowerToChoiceBranch
        , keyword "middleware"
            [ required "hook" InterceptorSyntax
            , required "body" WorkflowComponentSyntax
            ]
            HangingComponentSyntax
            [HangingBlockSyntax]
            LowerToMiddleware
        , keyword "callback"
            [ required "target" WorkflowNameSyntax
            , required "body" WorkflowComponentSyntax
            ]
            HangingComponentSyntax
            [HangingBlockSyntax]
            LowerToCallback
        , keyword "suspense"
            [required "target" WorkflowNameSyntax]
            HangingComponentSyntax
            [HangingBlockSyntax]
            LowerToSuspense
        , keyword "loop"
            [required "body" WorkflowComponentSyntax]
            HangingComponentSyntax
            [HangingBlockSyntax]
            LowerToLoop
        , keyword "allOf"
            [many "facts" FactExprSyntax]
            FactExprSyntax
            [WorkflowComponentSyntax]
            LowerToAllOf
        , keyword "anyOf"
            [many "facts" FactExprSyntax]
            FactExprSyntax
            [WorkflowComponentSyntax]
            LowerToAnyOf
        ]
    }
