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

pluginRegistryPath :: FilePath
pluginRegistryPath =
  "src" </> "Core" </> "Plugins.hs"

main :: IO ()
main =
  defaultMainWithHooks
    simpleUserHooks
      { preBuild = \args flags -> do
          generatePlugins
          preBuild simpleUserHooks args flags
      }

generatePlugins :: IO ()
generatePlugins = do
  sourceFiles <- haskellFiles "src"
  pluginExports <- fmap concat (mapM pluginExportsFromFile sourceFiles)
  case duplicateValues pluginExports of
    [] -> do
      createDirectoryIfMissing True (takeDirectory pluginRegistryPath)
      writeFile pluginRegistryPath (renderPlugins pluginExports)
    duplicates ->
      die ("Duplicate plugin exports: " ++ intercalate ", " duplicates)

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

pluginMarkerLine :: String -> [String]
pluginMarkerLine line =
  case stripPrefixText "-- plugin:" (trimLeft line) of
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

duplicateValues :: [PluginExport] -> [String]
duplicateValues pluginExports =
  [ valueName
  | valueName <- sort (nub (map pluginValue pluginExports))
  , length (filter ((== valueName) . pluginValue) pluginExports) > 1
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
