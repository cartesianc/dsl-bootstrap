module Framework.SelfArtifact
  ( ArtifactCommand (..)
  , ArtifactCommandResult (..)
  , ArtifactManifest (..)
  , ArtifactSource (..)
  , defaultSelfArtifactManifest
  , materializeSelfArtifact
  , renderArtifactCommand
  , renderArtifactCommandResult
  , renderArtifactManifest
  , runArtifactCommand
  , runSelfArtifactGate
  ) where

import System.Directory
  ( copyFile
  , createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , listDirectory
  , removePathForcibly
  )
import System.Exit
  ( ExitCode )
import System.FilePath
  ( dropTrailingPathSeparator
  , normalise
  , splitDirectories
  , takeDirectory
  , takeExtension
  , takeFileName
  , (</>)
  )
import qualified System.Process as Process

data ArtifactManifest = ArtifactManifest
  { artifactManifestName :: String
  , artifactManifestRoot :: FilePath
  , artifactManifestSources :: [ArtifactSource]
  , artifactManifestCommands :: [ArtifactCommand]
  }
  deriving (Eq, Show)

data ArtifactSource = ArtifactSource
  { artifactSourcePath :: FilePath
  , artifactTargetPath :: FilePath
  }
  deriving (Eq, Show)

data ArtifactCommand = ArtifactCommand
  { artifactCommandLabel :: String
  , artifactCommandExecutable :: FilePath
  , artifactCommandArguments :: [String]
  }
  deriving (Eq, Show)

data ArtifactCommandResult = ArtifactCommandResult
  { artifactCommandResultCommand :: ArtifactCommand
  , artifactCommandResultExitCode :: ExitCode
  , artifactCommandResultStdout :: String
  , artifactCommandResultStderr :: String
  }
  deriving (Eq, Show)

defaultSelfArtifactManifest :: ArtifactManifest
defaultSelfArtifactManifest =
  ArtifactManifest
    { artifactManifestName = "stage1-framework"
    , artifactManifestRoot = ".generated" </> "stage1-framework"
    , artifactManifestSources =
        [ ArtifactSource "new-framework-core" "new-framework-core"
        , ArtifactSource "domain-app" "domain-app"
        , ArtifactSource "docs" "docs"
        , ArtifactSource "stack.yaml" "stack.yaml"
        , ArtifactSource "stack.yaml.lock" "stack.yaml.lock"
        , ArtifactSource "LICENSE" "LICENSE"
        , ArtifactSource "README.md" "README.md"
        , ArtifactSource "CHANGELOG.md" "CHANGELOG.md"
        ]
    , artifactManifestCommands =
        [ ArtifactCommand "stack build" "stack" ["build"]
        , ArtifactCommand "bootstrap report" "stack" ["exec", "bootstrap-report"]
        , ArtifactCommand "fixed point" "stack" ["exec", "fixed-point-smoke"]
        , ArtifactCommand "domain app report" "stack" ["exec", "domain-app-report"]
        , ArtifactCommand "registry codegen witness" "stack" ["exec", "registry-codegen-witness"]
        ]
    }

materializeSelfArtifact :: ArtifactManifest -> IO ArtifactManifest
materializeSelfArtifact manifest = do
  ensureSafeArtifactRoot (artifactManifestRoot manifest)
  targetExists <- doesDirectoryExist (artifactManifestRoot manifest)
  if targetExists
    then removePathForcibly (artifactManifestRoot manifest)
    else pure ()
  createDirectoryIfMissing True (artifactManifestRoot manifest)
  mapM_ (copyArtifactSource (artifactManifestRoot manifest)) (artifactManifestSources manifest)
  pure manifest

runSelfArtifactGate :: ArtifactManifest -> IO [ArtifactCommandResult]
runSelfArtifactGate manifest =
  mapM (runArtifactCommand (artifactManifestRoot manifest)) (artifactManifestCommands manifest)

runArtifactCommand :: FilePath -> ArtifactCommand -> IO ArtifactCommandResult
runArtifactCommand cwdPath command = do
  (exitCode, stdoutText, stderrText) <-
    Process.readCreateProcessWithExitCode
      ( (Process.proc (artifactCommandExecutable command) (artifactCommandArguments command))
          { Process.cwd = Just cwdPath
          }
      )
      ""
  pure
    ArtifactCommandResult
      { artifactCommandResultCommand = command
      , artifactCommandResultExitCode = exitCode
      , artifactCommandResultStdout = stdoutText
      , artifactCommandResultStderr = stderrText
      }

renderArtifactManifest :: ArtifactManifest -> [String]
renderArtifactManifest manifest =
  [ "artifact manifest"
  , "name: " ++ artifactManifestName manifest
  , "root: " ++ artifactManifestRoot manifest
  , "sources:"
  ]
    ++ map (("  " ++) . renderArtifactSource) (artifactManifestSources manifest)
    ++ ["commands:"]
    ++ map (("  " ++) . renderArtifactCommand) (artifactManifestCommands manifest)

renderArtifactCommand :: ArtifactCommand -> String
renderArtifactCommand command =
  artifactCommandLabel command
    ++ ": "
    ++ unwords (artifactCommandExecutable command : artifactCommandArguments command)

renderArtifactCommandResult :: ArtifactCommandResult -> [String]
renderArtifactCommandResult result =
  [ "command: " ++ renderArtifactCommand (artifactCommandResultCommand result)
  , "exit: " ++ show (artifactCommandResultExitCode result)
  ]
    ++ renderIfPresent "stdout" (artifactCommandResultStdout result)
    ++ renderIfPresent "stderr" (artifactCommandResultStderr result)

renderArtifactSource :: ArtifactSource -> String
renderArtifactSource source =
  artifactSourcePath source ++ " -> " ++ artifactTargetPath source

copyArtifactSource :: FilePath -> ArtifactSource -> IO ()
copyArtifactSource root source = do
  let sourcePath =
        artifactSourcePath source
      targetPath =
        root </> artifactTargetPath source
  sourceIsFile <- doesFileExist sourcePath
  sourceIsDirectory <- doesDirectoryExist sourcePath
  if sourceIsFile
    then copyArtifactFile sourcePath targetPath
    else
      if sourceIsDirectory
        then copyArtifactDirectory sourcePath targetPath
        else ioError (userError ("missing artifact source: " ++ sourcePath))

copyArtifactFile :: FilePath -> FilePath -> IO ()
copyArtifactFile sourcePath targetPath = do
  createDirectoryIfMissing True (takeDirectory targetPath)
  copyFile sourcePath targetPath

copyArtifactDirectory :: FilePath -> FilePath -> IO ()
copyArtifactDirectory sourcePath targetPath = do
  createDirectoryIfMissing True targetPath
  entries <- listDirectory sourcePath
  mapM_ copyEntry entries
  where
    copyEntry entry
      | shouldSkipArtifactEntry entry =
          pure ()
      | otherwise = do
          let nextSource =
                sourcePath </> entry
              nextTarget =
                targetPath </> entry
          nextSourceIsFile <- doesFileExist nextSource
          nextSourceIsDirectory <- doesDirectoryExist nextSource
          if nextSourceIsFile
            then copyArtifactFile nextSource nextTarget
            else
              if nextSourceIsDirectory
                then copyArtifactDirectory nextSource nextTarget
                else pure ()

shouldSkipArtifactEntry :: FilePath -> Bool
shouldSkipArtifactEntry path =
  takeFileName path
    `elem`
      [ ".stack-work"
      , "dist"
      , "dist-newstyle"
      , ".git"
      , ".generated"
      ]
    || takeExtension path `elem` [".hi", ".o", ".dyn_hi", ".dyn_o", ".hie"]

ensureSafeArtifactRoot :: FilePath -> IO ()
ensureSafeArtifactRoot root =
  if safeArtifactRoot root
    then pure ()
    else ioError (userError ("unsafe artifact root: " ++ root))

safeArtifactRoot :: FilePath -> Bool
safeArtifactRoot root =
  case map dropTrailingPathSeparator (splitDirectories (normalise root)) of
    ".generated" : _ : _ ->
      True
    _ ->
      False

renderIfPresent :: String -> String -> [String]
renderIfPresent _ [] =
  []
renderIfPresent label text =
  (label ++ ":") : indentLines 2 (lines text)

indentLines :: Int -> [String] -> [String]
indentLines count =
  map (replicate count ' ' ++)
