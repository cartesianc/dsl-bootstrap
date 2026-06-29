import Data.Char
  ( isAlphaNum
  , isSpace
  )
import Control.Exception
  ( evaluate
  )
import Data.List
  ( intercalate
  , nub
  , sort
  )
import Distribution.Simple
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , listDirectory
  )
import System.Exit
  ( die
  )
import System.FilePath
  ( (</>)
  , takeDirectory
  , takeExtension
  )
import System.IO
  ( IOMode (ReadMode)
  , char8
  , hGetContents
  , hSetEncoding
  , withFile
  )

data PluginExport = PluginExport
  { pluginModule :: String
  , pluginValue :: String
  }

data EffectExport = EffectExport
  { effectModule :: String
  , effectValue :: String
  }

pluginRegistryPath :: FilePath
pluginRegistryPath =
  "src" </> "Core" </> "Plugins.hs"

effectRegistryPath :: FilePath
effectRegistryPath =
  "src" </> "Effects" </> "Theory.hs"

data PluginSource = PluginSource
  { sourcePath :: FilePath
  , sourceModuleName :: String
  , sourceContent :: String
  }

generatedImportStart :: String
generatedImportStart =
  "-- plugin imports: begin"

generatedImportEnd :: String
generatedImportEnd =
  "-- plugin imports: end"

main :: IO ()
main =
  defaultMainWithHooks
    simpleUserHooks
      { preBuild = \args flags -> do
          generatePlugins
          generateEffects
          preBuild simpleUserHooks args flags
      }

generatePlugins :: IO ()
generatePlugins = do
  sourceFiles <- haskellFiles "src"
  pluginExports <- fmap concat (mapM pluginExportsFromFile sourceFiles)
  case duplicateValues pluginExports of
    [] -> do
      updatePluginImports sourceFiles pluginExports
      createDirectoryIfMissing True (takeDirectory pluginRegistryPath)
      writeFile pluginRegistryPath (renderPlugins pluginExports)
    duplicates ->
      die ("Duplicate plugin exports: " ++ intercalate ", " duplicates)

generateEffects :: IO ()
generateEffects = do
  sourceFiles <- haskellFiles ("src" </> "Effects")
  effectExports <- fmap concat (mapM effectExportsFromFile sourceFiles)
  case duplicateEffectValues effectExports of
    [] -> do
      createDirectoryIfMissing True (takeDirectory effectRegistryPath)
      writeFile effectRegistryPath (renderEffectTheory effectExports)
    duplicates ->
      die ("Duplicate effect exports: " ++ intercalate ", " duplicates)

updatePluginImports :: [FilePath] -> [PluginExport] -> IO ()
updatePluginImports sourceFiles pluginExports = do
  pluginSources <- fmap concat (mapM pluginSourceFromFile sourceFiles)
  mapM_ (writePluginImports pluginExports) pluginSources

pluginSourceFromFile :: FilePath -> IO [PluginSource]
pluginSourceFromFile path = do
  source <- readSource path
  case moduleName source of
    Just currentModule
      | isPluginModule currentModule && not (null (pluginMarkers source)) ->
          pure [PluginSource path currentModule source]
    _ ->
      pure []

isPluginModule :: String -> Bool
isPluginModule currentModule =
  case stripPrefixText "Plugins." currentModule of
    Just suffix ->
      not (generatedPluginModule suffix)
    Nothing ->
      False

generatedPluginModule :: String -> Bool
generatedPluginModule suffix =
  hasGeneratedPrefix "Dependencies." suffix || hasGeneratedPrefix "Scope." suffix

referencedPluginExports :: [PluginExport] -> PluginSource -> [PluginExport]
referencedPluginExports pluginExports pluginSource =
  sortPluginExports
    [ pluginExport
    | pluginExport <- pluginExports
    , pluginModule pluginExport /= sourceModuleName pluginSource
    , pluginValue pluginExport `elem` identifiersIn (sourceContent pluginSource)
    ]

writePluginImports :: [PluginExport] -> PluginSource -> IO ()
writePluginImports pluginExports pluginSource = do
  let referencedModules =
        sort (nub (map pluginModule (referencedPluginExports pluginExports pluginSource)))
      updatedSource =
        insertGeneratedImports
          referencedModules
          (removeGeneratedImports (sourceContent pluginSource))
  if updatedSource == sourceContent pluginSource
    then pure ()
    else writeFile (sourcePath pluginSource) updatedSource

insertGeneratedImports :: [String] -> String -> String
insertGeneratedImports modules source
  | null modules =
      source
  | otherwise =
      unlines (before ++ renderGeneratedImports modules ++ after)
  where
    sourceLines =
      lines source
    (before, after) =
      splitAt (importInsertionIndex sourceLines) sourceLines

renderGeneratedImports :: [String] -> [String]
renderGeneratedImports modules =
  [ generatedImportStart ]
    ++ map ("import " ++) modules
    ++ [ generatedImportEnd ]

removeGeneratedImports :: String -> String
removeGeneratedImports =
  unlines . removeDependencyImports . removeGeneratedImportBlock . lines

removeGeneratedImportBlock :: [String] -> [String]
removeGeneratedImportBlock [] =
  []
removeGeneratedImportBlock (line : rest)
  | trimLeft line == generatedImportStart =
      removeGeneratedImportBlock (dropGeneratedImportBlock rest)
  | otherwise =
      line : removeGeneratedImportBlock rest

dropGeneratedImportBlock :: [String] -> [String]
dropGeneratedImportBlock [] =
  []
dropGeneratedImportBlock (line : rest)
  | trimLeft line == generatedImportEnd =
      rest
  | otherwise =
      dropGeneratedImportBlock rest

removeDependencyImports :: [String] -> [String]
removeDependencyImports =
  filter (not . generatedDependencyImportLine)

generatedDependencyImportLine :: String -> Bool
generatedDependencyImportLine line =
  case words (trimLeft line) of
    ("import" : "qualified" : moduleNameValue : _) ->
      isGeneratedDependencyModule moduleNameValue
    ("import" : moduleNameValue : _) ->
      isGeneratedDependencyModule moduleNameValue
    _ ->
      False

isGeneratedDependencyModule :: String -> Bool
isGeneratedDependencyModule moduleNameValue =
  hasGeneratedPrefix "Plugins.Dependencies." moduleNameValue
    || hasGeneratedPrefix "Plugins.Scope." moduleNameValue

importInsertionIndex :: [String] -> Int
importInsertionIndex sourceLines =
  case lastImportLine sourceLines of
    Just index ->
      index + 1
    Nothing ->
      case moduleHeaderLine sourceLines of
        Just index -> index + 1
        Nothing -> 0

lastImportLine :: [String] -> Maybe Int
lastImportLine =
  lastMatchingLine importLine

moduleHeaderLine :: [String] -> Maybe Int
moduleHeaderLine =
  firstMatchingLine moduleLine

lastMatchingLine :: (String -> Bool) -> [String] -> Maybe Int
lastMatchingLine predicate =
  foldl rememberMatch Nothing . zip [0 ..]
  where
    rememberMatch current (index, line)
      | predicate line = Just index
      | otherwise = current

firstMatchingLine :: (String -> Bool) -> [String] -> Maybe Int
firstMatchingLine predicate =
  firstJust . map matchLine . zip [0 ..]
  where
    matchLine (index, line)
      | predicate line = Just index
      | otherwise = Nothing

importLine :: String -> Bool
importLine line =
  case words (trimLeft line) of
    ("import" : _) -> True
    _ -> False

moduleLine :: String -> Bool
moduleLine line =
  case words (trimLeft line) of
    ("module" : _) -> True
    _ -> False

hasGeneratedPrefix :: String -> String -> Bool
hasGeneratedPrefix prefix text =
  case stripPrefixText prefix text of
    Just _ -> True
    Nothing -> False

haskellFiles :: FilePath -> IO [FilePath]
haskellFiles root = do
  names <- listDirectory root
  fmap concat (mapM childFiles names)
  where
    childFiles name = do
      let path = root </> name
      isDirectory <- doesDirectoryExist path
      if isDirectory
        then haskellFiles path
        else pure [path | takeExtension path == ".hs"]

pluginExportsFromFile :: FilePath -> IO [PluginExport]
pluginExportsFromFile path = do
  source <- readSource path
  case moduleName source of
    Nothing ->
      pure []
    Just currentModule ->
      pure
        [ PluginExport currentModule valueName
        | valueName <- pluginMarkers source
        ]

effectExportsFromFile :: FilePath -> IO [EffectExport]
effectExportsFromFile path = do
  source <- readSource path
  case moduleName source of
    Nothing ->
      pure []
    Just currentModule ->
      pure
        [ EffectExport currentModule valueName
        | valueName <- effectMarkers source
        ]

readSource :: FilePath -> IO String
readSource path =
  withFile path ReadMode $ \handle -> do
    hSetEncoding handle char8
    source <- hGetContents handle
    _ <- evaluate (length source)
    pure source

moduleName :: String -> Maybe String
moduleName source =
  firstJust (map moduleNameLine (lines source))

moduleNameLine :: String -> Maybe String
moduleNameLine line =
  case words line of
    ("module" : name : _) ->
      Just name
    _ ->
      Nothing

pluginMarkers :: String -> [String]
pluginMarkers =
  concatMap pluginMarkerLine . lines

effectMarkers :: String -> [String]
effectMarkers =
  concatMap effectMarkerLine . lines

pluginMarkerLine :: String -> [String]
pluginMarkerLine line =
  case stripPrefixText "-- plugin:" (trimLeft line) of
    Just markerText ->
      wordsByPluginSeparator markerText
    Nothing ->
      []

effectMarkerLine :: String -> [String]
effectMarkerLine line =
  case stripPrefixText "-- effect:" (trimLeft line) of
    Just markerText ->
      wordsByPluginSeparator markerText
    Nothing ->
      []

renderPlugins :: [PluginExport] -> String
renderPlugins pluginExports =
  unlines
    ( [ "{-# OPTIONS_GHC -Wno-missing-export-lists #-}"
      , "{-# OPTIONS_GHC -Wno-missing-signatures #-}"
      , ""
      , "module Plugins"
      , "  where"
      , ""
      ]
        ++ map renderImport modules
        ++ [ "" ]
        ++ map renderAlias sortedExports
    )
  where
    sortedExports =
      sortPluginExports pluginExports
    modules =
      sort (nub (map pluginModule sortedExports))

renderImport :: String -> String
renderImport moduleNameValue =
  "import qualified " ++ moduleNameValue

renderAlias :: PluginExport -> String
renderAlias pluginExport =
  pluginValue pluginExport
    ++ " = "
    ++ pluginModule pluginExport
    ++ "."
    ++ pluginValue pluginExport

renderEffectTheory :: [EffectExport] -> String
renderEffectTheory effectExports =
  unlines
    ( [ "{-# OPTIONS_GHC -Wno-missing-export-lists #-}"
      , "{-# OPTIONS_GHC -Wno-missing-signatures #-}"
      , ""
      , "module Effects.Theory"
      , "  ( effectTheory"
      , "  ) where"
      , ""
      , "import Effects.EffectTheory"
      , "  ( EffectTheory"
      , "  , theory"
      , "  )"
      ]
        ++ map renderQualifiedImport modules
        ++ [ ""
           , "effectTheory :: EffectTheory"
           , "effectTheory ="
           , "  theory"
           ]
        ++ renderEffectList sortedExports
    )
  where
    sortedExports =
      sortEffectExports effectExports
    modules =
      sort (nub (map effectModule sortedExports))

renderQualifiedImport :: String -> String
renderQualifiedImport moduleNameValue =
  "import qualified " ++ moduleNameValue

renderEffectList :: [EffectExport] -> [String]
renderEffectList [] =
  [ "    []" ]
renderEffectList (firstExport : rest) =
  ("    [ " ++ effectReference firstExport)
    : map (("    , " ++) . effectReference) rest
    ++ [ "    ]" ]

effectReference :: EffectExport -> String
effectReference effectExport =
  effectModule effectExport ++ "." ++ effectValue effectExport

sortPluginExports :: [PluginExport] -> [PluginExport]
sortPluginExports pluginExports =
  [ pluginExport
  | (moduleNameValue, valueName) <-
      sort
        [ (pluginModule pluginExport, pluginValue pluginExport)
        | pluginExport <- pluginExports
        ]
  , let pluginExport = PluginExport moduleNameValue valueName
  ]

sortEffectExports :: [EffectExport] -> [EffectExport]
sortEffectExports effectExports =
  [ effectExport
  | (moduleNameValue, valueName) <-
      sort
        [ (effectModule effectExport, effectValue effectExport)
        | effectExport <- effectExports
        ]
  , let effectExport = EffectExport moduleNameValue valueName
  ]

duplicateValues :: [PluginExport] -> [String]
duplicateValues pluginExports =
  [ valueName
  | valueName <- sort (nub (map pluginValue pluginExports))
  , length (filter ((== valueName) . pluginValue) pluginExports) > 1
  ]

duplicateEffectValues :: [EffectExport] -> [String]
duplicateEffectValues effectExports =
  [ valueName
  | valueName <- sort (nub (map effectValue effectExports))
  , length (filter ((== valueName) . effectValue) effectExports) > 1
  ]

wordsByPluginSeparator :: String -> [String]
wordsByPluginSeparator text =
  case dropWhile (not . isIdentifierStart) text of
    [] ->
      []
    rest ->
      let valueName = takeWhile isIdentifierChar rest
          remaining = dropWhile isIdentifierChar rest
       in valueName : wordsByPluginSeparator remaining

identifiersIn :: String -> [String]
identifiersIn text =
  case dropWhile (not . isIdentifierStart) text of
    [] ->
      []
    rest ->
      let identifier = takeWhile isIdentifierChar rest
          remaining = dropWhile isIdentifierChar rest
       in identifier : identifiersIn remaining

isIdentifierStart :: Char -> Bool
isIdentifierStart char =
  char == '_' || isAsciiLetter char

isIdentifierChar :: Char -> Bool
isIdentifierChar char =
  isIdentifierStart char || isAlphaNum char || char == '\''

isAsciiLetter :: Char -> Bool
isAsciiLetter char =
  ('a' <= char && char <= 'z') || ('A' <= char && char <= 'Z')

trimLeft :: String -> String
trimLeft =
  dropWhile isSpace

stripPrefixText :: String -> String -> Maybe String
stripPrefixText [] text =
  Just text
stripPrefixText _ [] =
  Nothing
stripPrefixText (expected : expectedRest) (actual : actualRest)
  | expected == actual =
      stripPrefixText expectedRest actualRest
  | otherwise =
      Nothing

firstJust :: [Maybe a] -> Maybe a
firstJust [] =
  Nothing
firstJust (item : rest) =
  case item of
    Just value ->
      Just value
    Nothing ->
      firstJust rest
