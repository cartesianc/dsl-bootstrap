module Core.Language.Validation
  ( LanguageError (..)
  , checkDefaultLanguageSpec
  , checkLanguageSpec
  , languageSpecValid
  , renderLanguageError
  ) where

import Core.Language.Spec
  ( ArgumentCardinality
  , ArgumentSpec (..)
  , KeywordName (..)
  , KeywordSpec (..)
  , LanguageSpec (..)
  , LoweringTarget (..)
  , SyntaxKind
  , defaultLanguageSpec
  , keywordNameText
  )

data LanguageError
  = EmptyKeywordName
  | EmptyArgumentLabel KeywordName Int
  | DuplicateArgumentLabel KeywordName String
  | KeywordWithoutParent KeywordName
  | PendingLowering KeywordName String
  | AmbiguousKeyword KeywordName [ArgumentShape] [SyntaxKind]
  deriving (Eq, Show)

data ArgumentShape = ArgumentShape SyntaxKind ArgumentCardinality
  deriving (Eq, Show)

checkDefaultLanguageSpec :: [LanguageError]
checkDefaultLanguageSpec =
  checkLanguageSpec defaultLanguageSpec

checkLanguageSpec :: LanguageSpec -> [LanguageError]
checkLanguageSpec spec =
  unique
    ( concatMap checkKeyword (languageKeywords spec)
        ++ ambiguousKeywords (languageKeywords spec)
    )

languageSpecValid :: LanguageSpec -> Bool
languageSpecValid =
  null . checkLanguageSpec

checkKeyword :: KeywordSpec -> [LanguageError]
checkKeyword currentKeyword =
  emptyKeywordName currentKeyword
    ++ emptyArgumentLabels currentKeyword
    ++ duplicateArgumentLabels currentKeyword
    ++ missingParents currentKeyword
    ++ pendingLowering currentKeyword

emptyKeywordName :: KeywordSpec -> [LanguageError]
emptyKeywordName currentKeyword =
  case keywordName currentKeyword of
    KeywordName "" ->
      [EmptyKeywordName]
    _ ->
      []

emptyArgumentLabels :: KeywordSpec -> [LanguageError]
emptyArgumentLabels currentKeyword =
  [ EmptyArgumentLabel (keywordName currentKeyword) index
  | (index, currentArgument) <- zip [0 ..] (keywordArguments currentKeyword)
  , null (argumentLabel currentArgument)
  ]

duplicateArgumentLabels :: KeywordSpec -> [LanguageError]
duplicateArgumentLabels currentKeyword =
  [ DuplicateArgumentLabel (keywordName currentKeyword) currentLabel
  | currentLabel <- unique (argumentLabels currentKeyword)
  , count currentLabel (argumentLabels currentKeyword) > 1
  ]

missingParents :: KeywordSpec -> [LanguageError]
missingParents currentKeyword =
  case keywordParents currentKeyword of
    [] ->
      [KeywordWithoutParent (keywordName currentKeyword)]
    _ ->
      []

pendingLowering :: KeywordSpec -> [LanguageError]
pendingLowering currentKeyword =
  case keywordLowering currentKeyword of
    LoweringPending reason ->
      [PendingLowering (keywordName currentKeyword) reason]
    _ ->
      []

ambiguousKeywords :: [KeywordSpec] -> [LanguageError]
ambiguousKeywords keywords =
  [ AmbiguousKeyword
      (keywordName left)
      (argumentShape left)
      (overlappingParents left right)
  | (left, right) <- keywordPairs keywords
  , keywordName left == keywordName right
  , argumentShape left == argumentShape right
  , not (null (overlappingParents left right))
  ]

keywordPairs :: [KeywordSpec] -> [(KeywordSpec, KeywordSpec)]
keywordPairs [] =
  []
keywordPairs (currentKeyword : rest) =
  map ((,) currentKeyword) rest ++ keywordPairs rest

argumentShape :: KeywordSpec -> [ArgumentShape]
argumentShape currentKeyword =
  [ ArgumentShape (argumentKind currentArgument) (argumentCardinality currentArgument)
  | currentArgument <- keywordArguments currentKeyword
  ]

overlappingParents :: KeywordSpec -> KeywordSpec -> [SyntaxKind]
overlappingParents left right =
  [ currentParent
  | currentParent <- keywordParents left
  , currentParent `elem` keywordParents right
  ]

argumentLabels :: KeywordSpec -> [String]
argumentLabels =
  map argumentLabel . keywordArguments

renderLanguageError :: LanguageError -> String
renderLanguageError currentError =
  case currentError of
    EmptyKeywordName ->
      "empty frontend keyword name"
    EmptyArgumentLabel currentName index ->
      "empty argument label in " ++ keywordNameText currentName ++ " at " ++ show index
    DuplicateArgumentLabel currentName currentLabel ->
      "duplicate argument label in " ++ keywordNameText currentName ++ ": " ++ currentLabel
    KeywordWithoutParent currentName ->
      "keyword has no parent context: " ++ keywordNameText currentName
    PendingLowering currentName reason ->
      "keyword lowering is pending: " ++ keywordNameText currentName ++ " (" ++ reason ++ ")"
    AmbiguousKeyword currentName currentShape currentParents ->
      "ambiguous keyword contract: "
        ++ keywordNameText currentName
        ++ " "
        ++ show currentShape
        ++ " in parents "
        ++ show currentParents

count :: Eq item => item -> [item] -> Int
count item =
  length . filter (== item)

unique :: Eq item => [item] -> [item]
unique =
  foldl addUnique []
  where
    addUnique items item
      | item `elem` items = items
      | otherwise = items ++ [item]
