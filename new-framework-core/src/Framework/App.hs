module Framework.App
  ( Runtime
  , RuntimeError (..)
  , RuntimeResult (..)
  , renderAppError
  , runApp
  , runAppResult
  , runAppRuntimeResult
  ) where

import Bootstrap.Effect
  ( EffectTheory )
import Bootstrap.Workflow
  ( AppBlueprint )
import Framework.Business.Diagnostics
  ( renderRuntimeErrorDiagnostic )
import Framework.Runtime.Handlers
  ( RuntimeEffectEnvironment )
import Framework.Runtime.Interpreter
  ( Runtime
  , RuntimeError (..)
  , RuntimeResult (..)
  , runBlueprintWithEffectEnvironmentResult
  , runBlueprintWithEffectEnvironmentRuntimeResult
  )
import qualified Framework.Runtime.Interpreter as Runtime

runApp :: RuntimeEffectEnvironment -> EffectTheory -> AppBlueprint -> IO ()
runApp environment effects blueprint = do
  result <- runAppResult environment effects blueprint
  case result of
    Left errorReport ->
      ioError (userError (renderAppError errorReport))
    Right runtime ->
      mapM_ putStrLn (Runtime.runtimeTrace runtime)

runAppResult :: RuntimeEffectEnvironment -> EffectTheory -> AppBlueprint -> IO (Either RuntimeError Runtime)
runAppResult =
  runBlueprintWithEffectEnvironmentResult

runAppRuntimeResult :: RuntimeEffectEnvironment -> EffectTheory -> AppBlueprint -> IO (RuntimeResult Runtime)
runAppRuntimeResult =
  runBlueprintWithEffectEnvironmentRuntimeResult

renderAppError :: RuntimeError -> String
renderAppError =
  renderRuntimeErrorDiagnostic
