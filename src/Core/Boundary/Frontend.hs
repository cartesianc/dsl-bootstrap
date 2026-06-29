module Core.Boundary.Frontend
  ( FrontendBoundaryError (..)
  , FrontendBoundaryPolicy (..)
  , FrontendBoundaryRules (..)
  , FrontendImport (..)
  , ModulePattern (..)
  , checkFrontendBoundary
  , checkFrontendBoundaryWith
  , checkFrontendImports
  , checkFrontendImportsWithRules
  , defaultFrontendBoundaryPolicy
  , defaultFrontendBoundaryRules
  , extractFrontendImports
  , frontendBoundaryPolicyRules
  , matchesModulePattern
  , renderFrontendBoundaryError
  , renderFrontendImport
  ) where

import Data.Char
  ( isAlphaNum
  , isSpace
  )
import Data.List
  ( isPrefixOf
  )
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , listDirectory
  )
import System.FilePath
  ( (</>)
  , normalise
  , takeExtension
  )

data FrontendBoundaryPolicy = FrontendBoundaryPolicy
  { frontendBoundaryRoots :: [FilePath]
  , frontendBoundaryExcludedPaths :: [FilePath]
  , frontendBoundaryAllowedImports :: [ModulePattern]
  , frontendBoundaryForbiddenImports :: [ModulePattern]
  }
  deriving (Eq, Show)

data FrontendBoundaryRules = FrontendBoundaryRules
  { frontendBoundaryRuleAllowedImports :: [ModulePattern]
  , frontendBoundaryRuleForbiddenImports :: [ModulePattern]
  }
  deriving (Eq, Show)

data ModulePattern
  = ExactModule String
  | PrefixModule String
  deriving (Eq, Show)

data FrontendImport = FrontendImport
  { frontendImportFile :: FilePath
  , frontendImportLine :: Int
  , frontendImportModule :: String
  }
  deriving (Eq, Show)

data FrontendBoundaryError
  = ForbiddenFrontendImport FrontendImport ModulePattern
  | UnknownFrontendImport FrontendImport
  deriving (Eq, Show)

defaultFrontendBoundaryPolicy :: FrontendBoundaryPolicy
defaultFrontendBoundaryPolicy =
  FrontendBoundaryPolicy
    { frontendBoundaryRoots =
        [ "app/Main.hs"
        , "app/CurrentAst.hs"
        , "app/CurrentEffects.hs"
        , "src/AST"
        , "src/Plugins"
        , "src/Effects"
        ]
    , frontendBoundaryExcludedPaths =
        [ "src/Effects/EffectTheory.hs"
        , "src/Effects/Theory.hs"
        ]
    , frontendBoundaryAllowedImports =
        [ ExactModule "Framework.Workflow"
        , ExactModule "Framework.Effect"
        , ExactModule "Framework.Hylo"
        , ExactModule "AST.AppBlueprint"
        , ExactModule "AST.Facts"
        , ExactModule "AST.Interceptors"
        , ExactModule "AST.Names"
        , ExactModule "AST.Vocabulary"
        , ExactModule "Effects.Names"
        , ExactModule "Effects.Theory"
        , ExactModule "Plugins"
        , PrefixModule "Plugins."
        , ExactModule "CurrentAst"
        , ExactModule "CurrentEffects"
        , ExactModule "InterpretConfig"
        ]
    , frontendBoundaryForbiddenImports =
        [ ExactModule "Core"
        , PrefixModule "Core."
        , ExactModule "Interpreter"
        , PrefixModule "Interpreter."
        , ExactModule "Framework.Background"
        , PrefixModule "Framework.Background."
        , ExactModule "Blueprint"
        , ExactModule "Effects.EffectTheory"
        ]
    }

checkFrontendBoundary :: IO [FrontendBoundaryError]
checkFrontendBoundary =
  checkFrontendBoundaryWith defaultFrontendBoundaryPolicy

checkFrontendBoundaryWith :: FrontendBoundaryPolicy -> IO [FrontendBoundaryError]
checkFrontendBoundaryWith policy = do
  currentImports <- extractFrontendImports policy
  pure (checkFrontendImports policy currentImports)

checkFrontendImports :: FrontendBoundaryPolicy -> [FrontendImport] -> [FrontendBoundaryError]
checkFrontendImports policy =
  checkFrontendImportsWithRules (frontendBoundaryPolicyRules policy)

checkFrontendImportsWithRules :: FrontendBoundaryRules -> [FrontendImport] -> [FrontendBoundaryError]
checkFrontendImportsWithRules rules =
  concatMap (checkFrontendImport rules)

extractFrontendImports :: FrontendBoundaryPolicy -> IO [FrontendImport]
extractFrontendImports policy = do
  files <- collectFrontendFiles policy
  concat <$> mapM extractFileImports files

defaultFrontendBoundaryRules :: FrontendBoundaryRules
defaultFrontendBoundaryRules =
  frontendBoundaryPolicyRules defaultFrontendBoundaryPolicy

frontendBoundaryPolicyRules :: FrontendBoundaryPolicy -> FrontendBoundaryRules
frontendBoundaryPolicyRules policy =
  FrontendBoundaryRules
    { frontendBoundaryRuleAllowedImports = frontendBoundaryAllowedImports policy
    , frontendBoundaryRuleForbiddenImports = frontendBoundaryForbiddenImports policy
    }

matchesModulePattern :: ModulePattern -> String -> Bool
matchesModulePattern pattern currentModule =
  case pattern of
    ExactModule expectedModule ->
      currentModule == expectedModule
    PrefixModule expectedPrefix ->
      expectedPrefix `isPrefixOf` currentModule

renderFrontendBoundaryError :: FrontendBoundaryError -> String
renderFrontendBoundaryError currentError =
  case currentError of
    ForbiddenFrontendImport currentImport pattern ->
      "forbidden frontend import: "
        ++ renderFrontendImport currentImport
        ++ " matches "
        ++ renderModulePattern pattern
    UnknownFrontendImport currentImport ->
      "unknown frontend import: "
        ++ renderFrontendImport currentImport

renderFrontendImport :: FrontendImport -> String
renderFrontendImport currentImport =
  frontendImportFile currentImport
    ++ ":"
    ++ show (frontendImportLine currentImport)
    ++ " imports "
    ++ frontendImportModule currentImport

checkFrontendImport :: FrontendBoundaryRules -> FrontendImport -> [FrontendBoundaryError]
checkFrontendImport rules currentImport =
  case firstMatchingPattern (frontendBoundaryRuleForbiddenImports rules) currentModule of
    Just currentPattern ->
      [ForbiddenFrontendImport currentImport currentPattern]
    Nothing
      | any (`matchesModulePattern` currentModule) (frontendBoundaryRuleAllowedImports rules) ->
          []
      | otherwise ->
          [UnknownFrontendImport currentImport]
  where
    currentModule =
      frontendImportModule currentImport

collectFrontendFiles :: FrontendBoundaryPolicy -> IO [FilePath]
collectFrontendFiles policy = do
  files <- concat <$> mapM collectRoot (frontendBoundaryRoots policy)
  pure
    [ currentFile
    | currentFile <- files
    , takeExtension currentFile == ".hs"
    , not (isExcluded currentFile)
    ]
  where
    excluded =
      map normalise (frontendBoundaryExcludedPaths policy)

    isExcluded currentFile =
      normalise currentFile `elem` excluded

collectRoot :: FilePath -> IO [FilePath]
collectRoot root = do
  rootIsFile <- doesFileExist root
  rootIsDirectory <- doesDirectoryExist root
  if rootIsFile
    then pure [root]
    else
      if rootIsDirectory
        then collectDirectory root
        else pure []

collectDirectory :: FilePath -> IO [FilePath]
collectDirectory directory = do
  children <- listDirectory directory
  concat <$> mapM collectRoot [directory </> child | child <- children]

extractFileImports :: FilePath -> IO [FrontendImport]
extractFileImports currentFile = do
  contents <- readFile currentFile
  pure
    [ currentImport
    | (lineNumber, currentLine) <- zip [1 ..] (lines contents)
    , Just currentImport <- [parseImport currentFile lineNumber currentLine]
    ]

parseImport :: FilePath -> Int -> String -> Maybe FrontendImport
parseImport currentFile lineNumber currentLine =
  case stripWord "import" (trim currentLine) of
    Nothing ->
      Nothing
    Just rest ->
      FrontendImport currentFile lineNumber <$> parseImportedModule rest

parseImportedModule :: String -> Maybe String
parseImportedModule text =
  case dropImportKeywords (words text) of
    [] ->
      Nothing
    currentToken : _ ->
      cleanModuleToken currentToken

dropImportKeywords :: [String] -> [String]
dropImportKeywords [] =
  []
dropImportKeywords (currentToken : rest)
  | currentToken `elem` ["qualified", "safe"] =
      dropImportKeywords rest
  | otherwise =
      currentToken : rest

cleanModuleToken :: String -> Maybe String
cleanModuleToken currentToken =
  nonEmpty (takeWhile isModuleChar currentToken)

isModuleChar :: Char -> Bool
isModuleChar currentChar =
  isAlphaNum currentChar || currentChar == '_' || currentChar == '.'

stripWord :: String -> String -> Maybe String
stripWord expected text =
  case splitAt (length expected) text of
    (prefix, rest)
      | prefix == expected && startsWithSpace rest ->
          Just (trim rest)
      | otherwise ->
          Nothing

startsWithSpace :: String -> Bool
startsWithSpace [] =
  True
startsWithSpace (currentChar : _) =
  isSpace currentChar

trim :: String -> String
trim =
  dropWhile isSpace

nonEmpty :: String -> Maybe String
nonEmpty [] =
  Nothing
nonEmpty value =
  Just value

firstMatchingPattern :: [ModulePattern] -> String -> Maybe ModulePattern
firstMatchingPattern [] _ =
  Nothing
firstMatchingPattern (currentPattern : rest) currentModule
  | matchesModulePattern currentPattern currentModule =
      Just currentPattern
  | otherwise =
      firstMatchingPattern rest currentModule

renderModulePattern :: ModulePattern -> String
renderModulePattern pattern =
  case pattern of
    ExactModule currentModule ->
      currentModule
    PrefixModule currentPrefix ->
      currentPrefix ++ "*"
