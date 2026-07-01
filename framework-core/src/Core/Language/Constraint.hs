module Core.Language.Constraint
  ( LanguageConstraintError (..)
  , LanguageConstraintFact (..)
  , checkDefaultLanguageConstraints
  , checkLanguageConstraints
  , defaultLanguageConstraints
  , languageConstraintsFromSpec
  , renderLanguageConstraintError
  , renderLanguageConstraintFact
  , renderLanguageConstraintFacts
  ) where

import Core.Language.Spec
  ( ArgumentCardinality (..)
  , ArgumentSpec (..)
  , KeywordName
  , KeywordSpec (..)
  , LanguageSpec (..)
  , LoweringTarget
  , SyntaxKind
  , defaultLanguageSpec
  , keywordNameText
  )
import Core.Language.Validation
  ( LanguageError
  , checkLanguageSpec
  , renderLanguageError
  )

data LanguageConstraintFact
  = LanguageKeywordDeclared KeywordName
  | LanguageArgumentAccepted KeywordName Int SyntaxKind
  | LanguageArgumentMany KeywordName Int SyntaxKind
  | LanguageArgumentOptional KeywordName Int SyntaxKind
  | LanguageResultKind KeywordName SyntaxKind
  | LanguageParentAllowed KeywordName SyntaxKind
  | LanguageLoweringDefined KeywordName LoweringTarget
  deriving (Eq, Show)

newtype LanguageConstraintError = LanguageSpecError LanguageError
  deriving (Eq, Show)

defaultLanguageConstraints :: [LanguageConstraintFact]
defaultLanguageConstraints =
  languageConstraintsFromSpec defaultLanguageSpec

languageConstraintsFromSpec :: LanguageSpec -> [LanguageConstraintFact]
languageConstraintsFromSpec spec =
  unique (concatMap keywordConstraints (languageKeywords spec))

checkDefaultLanguageConstraints :: [LanguageConstraintError]
checkDefaultLanguageConstraints =
  checkLanguageConstraints defaultLanguageSpec

checkLanguageConstraints :: LanguageSpec -> [LanguageConstraintError]
checkLanguageConstraints =
  map LanguageSpecError . checkLanguageSpec

keywordConstraints :: KeywordSpec -> [LanguageConstraintFact]
keywordConstraints currentKeyword =
  [ LanguageKeywordDeclared (keywordName currentKeyword)
  , LanguageResultKind (keywordName currentKeyword) (keywordResult currentKeyword)
  , LanguageLoweringDefined (keywordName currentKeyword) (keywordLowering currentKeyword)
  ]
    ++ argumentConstraints currentKeyword
    ++ parentConstraints currentKeyword

argumentConstraints :: KeywordSpec -> [LanguageConstraintFact]
argumentConstraints currentKeyword =
  [ argumentConstraint (keywordName currentKeyword) index currentArgument
  | (index, currentArgument) <- zip [0 ..] (keywordArguments currentKeyword)
  ]

argumentConstraint :: KeywordName -> Int -> ArgumentSpec -> LanguageConstraintFact
argumentConstraint currentName index currentArgument =
  case argumentCardinality currentArgument of
    RequiredArgument ->
      LanguageArgumentAccepted currentName index (argumentKind currentArgument)
    ManyArguments ->
      LanguageArgumentMany currentName index (argumentKind currentArgument)
    OptionalArgument ->
      LanguageArgumentOptional currentName index (argumentKind currentArgument)

parentConstraints :: KeywordSpec -> [LanguageConstraintFact]
parentConstraints currentKeyword =
  [ LanguageParentAllowed (keywordName currentKeyword) currentParent
  | currentParent <- keywordParents currentKeyword
  ]

renderLanguageConstraintFacts :: [LanguageConstraintFact] -> String
renderLanguageConstraintFacts =
  joinWith "\n" . map renderLanguageConstraintFact

renderLanguageConstraintFact :: LanguageConstraintFact -> String
renderLanguageConstraintFact currentFact =
  case currentFact of
    LanguageKeywordDeclared currentName ->
      "keywordDeclared " ++ keywordNameText currentName
    LanguageArgumentAccepted currentName index currentKind ->
      "argumentAccepted " ++ keywordNameText currentName ++ " " ++ show index ++ " " ++ show currentKind
    LanguageArgumentMany currentName index currentKind ->
      "argumentMany " ++ keywordNameText currentName ++ " " ++ show index ++ " " ++ show currentKind
    LanguageArgumentOptional currentName index currentKind ->
      "argumentOptional " ++ keywordNameText currentName ++ " " ++ show index ++ " " ++ show currentKind
    LanguageResultKind currentName currentKind ->
      "resultKind " ++ keywordNameText currentName ++ " " ++ show currentKind
    LanguageParentAllowed currentName currentKind ->
      "parentAllowed " ++ keywordNameText currentName ++ " " ++ show currentKind
    LanguageLoweringDefined currentName currentLowering ->
      "loweringDefined " ++ keywordNameText currentName ++ " " ++ show currentLowering

renderLanguageConstraintError :: LanguageConstraintError -> String
renderLanguageConstraintError (LanguageSpecError currentError) =
  renderLanguageError currentError

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
