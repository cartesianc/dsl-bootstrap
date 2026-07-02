module Main
  ( main
  ) where

import System.Exit
  ( ExitCode (..) )

import Framework.SelfArtifact
  ( ArtifactCommandResult (..)
  , artifactCommandLabel
  , artifactCommandResultCommand
  , defaultSelfArtifactManifest
  , materializeSelfArtifact
  , renderArtifactCommandResult
  , renderArtifactManifest
  , runSelfArtifactGate
  )

main :: IO ()
main = do
  putStrLn "[artifact] materializing stage1 framework"
  manifest <- materializeSelfArtifact defaultSelfArtifactManifest
  mapM_ putStrLn (renderArtifactManifest manifest)
  results <- runSelfArtifactGate manifest
  mapM_ printCommandSummary results
  case filter commandFailed results of
    [] ->
      putStrLn "[artifact] ok stage1 framework artifact"
    failures ->
      ioError
        ( userError
            ( unlines
                ( "[artifact] stage1 framework artifact failed"
                    : concatMap renderArtifactCommandResult failures
                )
            )
        )

printCommandSummary :: ArtifactCommandResult -> IO ()
printCommandSummary result =
  case artifactCommandResultExitCode result of
    ExitSuccess ->
      putStrLn ("[artifact] passed " ++ commandLabel result)
    ExitFailure code ->
      putStrLn ("[artifact] failed " ++ commandLabel result ++ " exit " ++ show code)

commandFailed :: ArtifactCommandResult -> Bool
commandFailed result =
  artifactCommandResultExitCode result /= ExitSuccess

commandLabel :: ArtifactCommandResult -> String
commandLabel =
  artifactCommandLabel . artifactCommandResultCommand
