module Core.ImportGraph
  ( ImportGraph (..)
  , ImportModule (..)
  , ImportPackage (..)
  , ModuleImport (..)
  , PackageImportError (..)
  , PackageImportPolicy (..)
  , checkDefaultPackageImportGraph
  , checkPackageImportGraph
  , defaultPackageImportPolicy
  , extractImportGraph
  , readPackageImportGraph
  , renderModuleImport
  , renderPackageImportError
  ) where

import Data.Char
  ( isAlphaNum
  , isSpace
  )
import Data.List
  ( isPrefixOf
  , nub
  )
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , listDirectory
  )
import System.FilePath
  ( dropExtension
  , makeRelative
  , normalise
  , splitDirectories
  , takeExtension
  , (</>)
  )

data ImportPackage = ImportPackage
  { importPackageName :: String
  , importPackageSourceDirs :: [FilePath]
  , importPackageAllowedDependencies :: [String]
  }
  deriving (Eq, Show)

newtype PackageImportPolicy = PackageImportPolicy
  { importPolicyPackages :: [ImportPackage]
  }
  deriving (Eq, Show)

data ImportModule = ImportModule
  { importModulePackage :: String
  , importModuleName :: String
  , importModuleFile :: FilePath
  }
  deriving (Eq, Show)

data ModuleImport = ModuleImport
  { moduleImportSourcePackage :: String
  , moduleImportSourceModule :: String
  , moduleImportSourceFile :: FilePath
  , moduleImportLine :: Int
  , moduleImportTargetModule :: String
  }
  deriving (Eq, Show)

data ImportGraph = ImportGraph
  { importGraphModules :: [ImportModule]
  , importGraphImports :: [ModuleImport]
  }
  deriving (Eq, Show)

data PackageImportError
  = ForbiddenPackageImport ModuleImport String
  deriving (Eq, Show)

defaultPackageImportPolicy :: PackageImportPolicy
defaultPackageImportPolicy =
  PackageImportPolicy
    [ ImportPackage
        { importPackageName = "framework-core"
        , importPackageSourceDirs = ["framework-core" </> "src"]
        , importPackageAllowedDependencies = []
        }
    , ImportPackage
        { importPackageName = "domain-app"
        , importPackageSourceDirs =
            [ "domain-app" </> "src"
            , "domain-app" </> "app"
            ]
        , importPackageAllowedDependencies = ["framework-core"]
        }
    ]

checkDefaultPackageImportGraph :: IO [PackageImportError]
checkDefaultPackageImportGraph = do
  graph <- readPackageImportGraph defaultPackageImportPolicy
  pure (checkPackageImportGraph defaultPackageImportPolicy graph)

readPackageImportGraph :: PackageImportPolicy -> IO ImportGraph
readPackageImportGraph policy =
  extractImportGraph (importPolicyPackages policy)

extractImportGraph :: [ImportPackage] -> IO ImportGraph
extractImportGraph packages = do
  packageModules <- concat <$> mapM discoverPackageModules packages
  let packageImports =
        concatMap moduleImportsFromSource packageModules
  pure
    ImportGraph
      { importGraphModules = map sourceImportModule packageModules
      , importGraphImports = packageImports
      }

checkPackageImportGraph :: PackageImportPolicy -> ImportGraph -> [PackageImportError]
checkPackageImportGraph policy graph =
  [ ForbiddenPackageImport currentImport targetPackage
  | currentImport <- importGraphImports graph
  , Just targetPackage <- [packageForModule graph (moduleImportTargetModule currentImport)]
  , targetPackage /= moduleImportSourcePackage currentImport
  , targetPackage `notElem` allowedDependenciesFor policy (moduleImportSourcePackage currentImport)
  ]

renderPackageImportError :: PackageImportError -> String
renderPackageImportError currentError =
  case currentError of
    ForbiddenPackageImport currentImport targetPackage ->
      "forbidden package import: "
        ++ renderModuleImport currentImport
        ++ " reaches package "
        ++ targetPackage

renderModuleImport :: ModuleImport -> String
renderModuleImport currentImport =
  moduleImportSourceFile currentImport
    ++ ":"
    ++ show (moduleImportLine currentImport)
    ++ " "
    ++ moduleImportSourcePackage currentImport
    ++ ":"
    ++ moduleImportSourceModule currentImport
    ++ " imports "
    ++ moduleImportTargetModule currentImport

data SourceModule = SourceModule
  { sourceImportModule :: ImportModule
  , sourceLines :: [String]
  }

discoverPackageModules :: ImportPackage -> IO [SourceModule]
discoverPackageModules currentPackage = do
  sourceFiles <- concat <$> mapM collectRoot (importPackageSourceDirs currentPackage)
  mapM (readSourceModule currentPackage) sourceFiles

readSourceModule :: ImportPackage -> FilePath -> IO SourceModule
readSourceModule currentPackage sourceFile = do
  source <- readFile sourceFile
  let currentLines =
        lines source
      currentModule =
        moduleNameFromSource
          (importPackageSourceDirs currentPackage)
          sourceFile
          currentLines
  pure
    SourceModule
      { sourceImportModule =
          ImportModule
            { importModulePackage = importPackageName currentPackage
            , importModuleName = currentModule
            , importModuleFile = normalise sourceFile
            }
      , sourceLines = currentLines
      }

moduleImportsFromSource :: SourceModule -> [ModuleImport]
moduleImportsFromSource currentSource =
  [ ModuleImport
      { moduleImportSourcePackage = importModulePackage currentModule
      , moduleImportSourceModule = importModuleName currentModule
      , moduleImportSourceFile = importModuleFile currentModule
      , moduleImportLine = lineNumber
      , moduleImportTargetModule = targetModule
      }
  | (lineNumber, currentLine) <- zip [1 ..] (sourceLines currentSource)
  , Just targetModule <- [parseImport currentLine]
  ]
  where
    currentModule =
      sourceImportModule currentSource

moduleNameFromSource :: [FilePath] -> FilePath -> [String] -> String
moduleNameFromSource sourceDirs sourceFile currentLines =
  case firstJust (map parseModuleName currentLines) of
    Just currentModule ->
      currentModule
    Nothing ->
      moduleNameFromPath sourceDirs sourceFile

moduleNameFromPath :: [FilePath] -> FilePath -> String
moduleNameFromPath sourceDirs sourceFile =
  joinWith "." (splitDirectories (dropExtension relativePath))
  where
    relativePath =
      makeRelative (sourceRootFor sourceDirs sourceFile) sourceFile

sourceRootFor :: [FilePath] -> FilePath -> FilePath
sourceRootFor [] _ =
  "."
sourceRootFor (sourceDir : rest) sourceFile
  | normalise sourceDir `isPrefixOf` normalise sourceFile =
      sourceDir
  | otherwise =
      sourceRootFor rest sourceFile

collectRoot :: FilePath -> IO [FilePath]
collectRoot root = do
  rootIsFile <- doesFileExist root
  rootIsDirectory <- doesDirectoryExist root
  if rootIsFile
    then pure [root | takeExtension root == ".hs"]
    else
      if rootIsDirectory
        then collectDirectory root
        else pure []

collectDirectory :: FilePath -> IO [FilePath]
collectDirectory directory = do
  children <- listDirectory directory
  concat <$> mapM (collectRoot . (directory </>)) children

parseModuleName :: String -> Maybe String
parseModuleName currentLine =
  case words (trim currentLine) of
    ("module" : name : _) ->
      cleanModuleToken name
    _ ->
      Nothing

parseImport :: String -> Maybe String
parseImport currentLine =
  case stripWord "import" (trim currentLine) of
    Nothing ->
      Nothing
    Just rest ->
      parseImportedModule rest

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
cleanModuleToken =
  nonEmpty . takeWhile isModuleChar

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

packageForModule :: ImportGraph -> String -> Maybe String
packageForModule graph moduleName =
  firstJust
    [ Just (importModulePackage currentModule)
    | currentModule <- importGraphModules graph
    , importModuleName currentModule == moduleName
    ]

allowedDependenciesFor :: PackageImportPolicy -> String -> [String]
allowedDependenciesFor policy packageName =
  unique
    [ allowedPackage
    | currentPackage <- importPolicyPackages policy
    , importPackageName currentPackage == packageName
    , allowedPackage <- importPackageAllowedDependencies currentPackage
    ]

unique :: Eq item => [item] -> [item]
unique =
  nub

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
