module Main
  ( main
  ) where

import Data.Char
  ( isSpace )
import Data.List
  ( isPrefixOf )
import Framework.TrustBase
  ( ArtifactManifest (..)
  , ArtifactSource (..)
  , TrustBaseManifest (..)
  , defaultSelfArtifactManifest
  , defaultTrustBaseManifest
  , renderArtifactCommand
  , renderTrustBaseManifest
  , renderTrustBaseManifestJson
  )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  failures <- checkTrustBaseManifest defaultTrustBaseManifest
  case failures of
    [] ->
      case args of
        ["--json"] ->
          putStrLn (renderTrustBaseManifestJson defaultTrustBaseManifest)
        _ -> do
          mapM_ putStrLn (renderTrustBaseManifest defaultTrustBaseManifest)
          putStrLn
            ( "[witness] ok trust base manifest "
                ++ trustBaseManifestSchema defaultTrustBaseManifest
            )
    currentFailures ->
      ioError (userError ("trust base manifest failed\n" ++ unlines currentFailures))

checkTrustBaseManifest :: TrustBaseManifest -> IO [String]
checkTrustBaseManifest manifest = do
  coreCabal <- readFile "new-framework-core/new-framework-core.cabal"
  domainCabal <- readFile "domain-app/domain-app.cabal"
  let exposedModules =
        cabalExposedModules coreCabal ++ cabalExposedModules domainCabal
      executables =
        cabalExecutables coreCabal ++ cabalExecutables domainCabal
  pure
    ( missingItems
        "kernel module not exposed"
        exposedModules
        (trustBaseManifestKernelModules manifest)
        ++ missingItems
          "facade module not exposed"
          exposedModules
          (trustBaseManifestFacadeModules manifest)
        ++ missingItems
          "report executable missing"
          executables
          (trustBaseManifestReportExecutables manifest)
        ++ missingItems
          "witness executable missing"
          executables
          (trustBaseManifestWitnessExecutables manifest)
        ++ missingItems
          "artifact gate executable missing"
          executables
          [trustBaseManifestArtifactGateExecutable manifest]
        ++ artifactSourcesDrift manifest
        ++ artifactCommandsDrift manifest
    )

artifactSourcesDrift :: TrustBaseManifest -> [String]
artifactSourcesDrift manifest
  | trustBaseManifestArtifactSources manifest == currentArtifactSources =
      []
  | otherwise =
      [ "artifact sources drifted from defaultSelfArtifactManifest"
      ]

artifactCommandsDrift :: TrustBaseManifest -> [String]
artifactCommandsDrift manifest
  | trustBaseManifestArtifactCommands manifest == currentArtifactCommands =
      []
  | otherwise =
      [ "artifact commands drifted from defaultSelfArtifactManifest"
      ]

currentArtifactSources :: [String]
currentArtifactSources =
  map renderArtifactSourceText (artifactManifestSources defaultSelfArtifactManifest)

currentArtifactCommands :: [String]
currentArtifactCommands =
  map renderArtifactCommand (artifactManifestCommands defaultSelfArtifactManifest)

renderArtifactSourceText :: ArtifactSource -> String
renderArtifactSourceText source =
  artifactSourcePath source ++ " -> " ++ artifactTargetPath source

missingItems :: String -> [String] -> [String] -> [String]
missingItems label available expected =
  [ label ++ ": " ++ item
  | item <- expected
  , item `notElem` available
  ]

cabalExposedModules :: String -> [String]
cabalExposedModules =
  mapMaybeModule . lines

mapMaybeModule :: [String] -> [String]
mapMaybeModule [] =
  []
mapMaybeModule (currentLine : rest) =
  case cabalModuleName currentLine of
    Just name ->
      name : mapMaybeModule rest
    Nothing ->
      mapMaybeModule rest

cabalModuleName :: String -> Maybe String
cabalModuleName line =
  case takeWhile (not . isSpace) (dropModulePrefix line) of
    [] ->
      Nothing
    name
      | '.' `elem` name || name == "Blueprint" ->
          Just name
      | otherwise ->
          Nothing

dropModulePrefix :: String -> String
dropModulePrefix =
  dropWhile isSpace . dropWhile (== ',') . dropWhile isSpace

cabalExecutables :: String -> [String]
cabalExecutables =
  mapMaybeExecutable . lines

mapMaybeExecutable :: [String] -> [String]
mapMaybeExecutable [] =
  []
mapMaybeExecutable (currentLine : rest) =
  case cabalExecutableName currentLine of
    Just name ->
      name : mapMaybeExecutable rest
    Nothing ->
      mapMaybeExecutable rest

cabalExecutableName :: String -> Maybe String
cabalExecutableName line =
  case stripPrefix "executable " (dropWhile isSpace line) of
    Just name ->
      Just (takeWhile (not . isSpace) name)
    Nothing ->
      Nothing

stripPrefix :: String -> String -> Maybe String
stripPrefix prefix text
  | prefix `isPrefixOf` text =
      Just (drop (length prefix) text)
  | otherwise =
      Nothing
