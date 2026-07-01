module Interpreter.Runtime.Monad
  ( askRuntimeEnv
  , defaultRuntimeEnv
  , getRuntimeState
  , liftRuntimeIO
  , modifyRuntimeState
  , putRuntimeState
  , renderRuntimeError
  , runRuntimeM
  , runRuntimeMOrThrow
  , runtimeEnv
  , runtimeSleepM
  , throwRuntimeError
  , traceRuntimeM
  , withRuntimeEnv
  , withRuntimeCallbacks
  ) where

import Core.Effect.Semantics
  ( EffectSemantics
  , effectSemantics
  )
import Effects.EffectTheory
  ( theory
  )
import Interpreter.Runtime.Handlers
  ( defaultRuntimeEffectEnvironment
  )
import Interpreter.Runtime.Trace
  ( runtimeSleep
  , traceRuntime
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , RuntimeCallback
  , RuntimeEnv (..)
  , RuntimeError (..)
  , RuntimeEffectEnvironment
  , RuntimeM (..)
  , RuntimeResult (..)
  , RuntimeState
  )

runtimeEnv :: RuntimeEffectEnvironment -> EffectSemantics -> RuntimeEnv
runtimeEnv environment semantics =
  RuntimeEnv
    { runtimeEnvEffectEnvironment = environment
    , runtimeEnvEffectSemantics = semantics
    , runtimeEnvCallbacks = []
    }

defaultRuntimeEnv :: RuntimeEnv
defaultRuntimeEnv =
  runtimeEnv defaultRuntimeEffectEnvironment (effectSemantics (theory []))

runRuntimeM :: RuntimeEnv -> RuntimeState -> RuntimeM a -> IO (RuntimeResult a)
runRuntimeM environment state program =
  runRuntimeMInternal program environment state

runRuntimeMOrThrow :: RuntimeEnv -> RuntimeState -> RuntimeM a -> IO RuntimeState
runRuntimeMOrThrow environment state program = do
  result <- runRuntimeM environment state program
  case result of
    RuntimeSucceeded _ nextState ->
      pure nextState
    RuntimeFailed errorReport _ ->
      ioError (userError (renderRuntimeError errorReport))

askRuntimeEnv :: RuntimeM RuntimeEnv
askRuntimeEnv =
  RuntimeM $ \environment state ->
    pure (RuntimeSucceeded environment state)

withRuntimeEnv :: RuntimeEnv -> RuntimeM a -> RuntimeM a
withRuntimeEnv localEnvironment program =
  RuntimeM $ \_ state ->
    runRuntimeMInternal program localEnvironment state

withRuntimeCallbacks :: [RuntimeCallback] -> RuntimeEnv -> RuntimeEnv
withRuntimeCallbacks callbacks environment =
  environment
    { runtimeEnvCallbacks = callbacks <> runtimeEnvCallbacks environment
    }

getRuntimeState :: RuntimeM RuntimeState
getRuntimeState =
  RuntimeM $ \_ state ->
    pure (RuntimeSucceeded state state)

putRuntimeState :: RuntimeState -> RuntimeM ()
putRuntimeState state =
  RuntimeM $ \_ _ ->
    pure (RuntimeSucceeded () state)

modifyRuntimeState :: (RuntimeState -> RuntimeState) -> RuntimeM ()
modifyRuntimeState transform = do
  state <- getRuntimeState
  putRuntimeState (transform state)

throwRuntimeError :: RuntimeError -> RuntimeM a
throwRuntimeError errorReport =
  RuntimeM $ \_ state ->
    pure (RuntimeFailed errorReport state)

liftRuntimeIO :: IO a -> RuntimeM a
liftRuntimeIO action =
  RuntimeM $ \_ state -> do
    value <- action
    pure (RuntimeSucceeded value state)

traceRuntimeM :: String -> RuntimeM ()
traceRuntimeM message = do
  modifyRuntimeState
    ( \state ->
        state
          { runtimeTrace = runtimeTrace state <> [message]
          }
    )
  liftRuntimeIO (traceRuntime message)

runtimeSleepM :: RuntimeM ()
runtimeSleepM =
  liftRuntimeIO runtimeSleep

renderRuntimeError :: RuntimeError -> String
renderRuntimeError errorReport =
  case errorReport of
    RuntimeMissingFactRule currentFact ->
      "missing take/make rule for fact " ++ show currentFact
    RuntimeMissingSendBoundary currentSend ->
      "missing send boundary " ++ show currentSend
    RuntimeMissingHandler currentSend ->
      "missing handler for " ++ show currentSend
    RuntimeMissingHandlerInput currentSend currentType ->
      "externalMake " ++ show currentSend ++ " missing handler input " ++ show currentType
    RuntimeHandlerOutputMismatch currentSend expectedOutput actualOutputs ->
      "externalMake "
        ++ show currentSend
        ++ " output mismatch: expected "
        ++ show expectedOutput
        ++ ", got "
        ++ show actualOutputs
    RuntimeHandlerFailed currentSend message ->
      "externalMake " ++ show currentSend ++ " failed: " ++ message
    RuntimeMissingTransform currentTransform ->
      "missing transform " ++ show currentTransform
    RuntimeMissingTransformInput currentTransform currentType ->
      "transform " ++ show currentTransform ++ " missing input " ++ show currentType
    RuntimeTransformInputMismatch currentTransform expectedInput actualInput ->
      "transform "
        ++ show currentTransform
        ++ " input mismatch: expected "
        ++ show expectedInput
        ++ ", got "
        ++ show actualInput
    RuntimeTransformSignatureMismatch currentTransform expectedInput expectedOutput actualInput actualOutput ->
      "transform "
        ++ show currentTransform
        ++ " signature mismatch: expected "
        ++ show expectedInput
        ++ " -> "
        ++ show expectedOutput
        ++ ", got "
        ++ show actualInput
        ++ " -> "
        ++ show actualOutput
    RuntimeWaitBlocked facts ->
      "wait blocked: " ++ facts
    RuntimeChoiceMissingBranch selectedKey ->
      "choice workflow has no branch for " ++ selectedKey
    RuntimeFallbackExhausted ->
      "fallback workflow has no successful branch"
    RuntimeRaceEmpty ->
      "race workflow has no branches"
    RuntimeRaceExhausted ->
      "race workflow has no successful branch"
    RuntimeIoException message ->
      "runtime IO exception: " ++ message
