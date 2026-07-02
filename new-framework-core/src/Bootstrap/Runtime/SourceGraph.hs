module Bootstrap.Runtime.SourceGraph
  ( SourceImportGraph (..)
  , SourceModule (..)
  , readSourceImportGraph
  ) where

import Data.Char
  ( isAlphaNum )
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , listDirectory
  )
import System.FilePath
  ( normalise
  , takeExtension
  , (</>)
  )

data SourceImportGraph = SourceImportGraph
  { sourceImportModules :: [SourceModule]
  }

data SourceModule = SourceModule
  { sourceModuleName :: String
  , sourceModulePath :: FilePath
  , sourceModuleImports :: [String]
  }

readSourceImportGraph :: [FilePath] -> IO SourceImportGraph
readSourceImportGraph roots = do
  files <- concat <$> mapM collectHaskellFiles roots
  modules <- mapM readSourceModule files
  pure (SourceImportGraph modules)

collectHaskellFiles :: FilePath -> IO [FilePath]
collectHaskellFiles root = do
  isFile <- doesFileExist root
  isDirectory <- doesDirectoryExist root
  if isFile
    then pure [root | takeExtension root == ".hs"]
    else
      if isDirectory
        then do
          children <- listDirectory root
          concat <$> mapM (collectHaskellFiles . (root </>)) children
        else pure []

readSourceModule :: FilePath -> IO SourceModule
readSourceModule path = do
  text <- readFile path
  pure
    SourceModule
      { sourceModuleName = moduleNameFromFile path text
      , sourceModulePath = normalise path
      , sourceModuleImports = mapMaybeImport (lines text)
      }

moduleNameFromFile :: FilePath -> String -> String
moduleNameFromFile path text =
  case firstJust (map parseModuleLine (lines text)) of
    Just name ->
      name
    Nothing ->
      path

parseModuleLine :: String -> Maybe String
parseModuleLine line =
  case words line of
    ("module" : name : _) ->
      Just (takeModuleName name)
    _ ->
      Nothing

mapMaybeImport :: [String] -> [String]
mapMaybeImport =
  unique . foldr collect []
  where
    collect line imports =
      case parseImportLine line of
        Just currentImport ->
          currentImport : imports
        Nothing ->
          imports

parseImportLine :: String -> Maybe String
parseImportLine line =
  case words (stripLineComment line) of
    ("import" : rest) ->
      parseImportWords rest
    _ ->
      Nothing

parseImportWords :: [String] -> Maybe String
parseImportWords [] =
  Nothing
parseImportWords ("qualified" : rest) =
  parseImportWords rest
parseImportWords (name : _) =
  Just (takeModuleName name)

takeModuleName :: String -> String
takeModuleName =
  takeWhile (\char -> isAlphaNum char || char == '_' || char == '.')

stripLineComment :: String -> String
stripLineComment [] =
  []
stripLineComment ('-' : '-' : _) =
  []
stripLineComment (char : rest) =
  char : stripLineComment rest

unique :: Eq item => [item] -> [item]
unique =
  foldl appendUnique []

appendUnique :: Eq item => [item] -> item -> [item]
appendUnique items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest
