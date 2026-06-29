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
  , RuntimeEnv (..)
  , RuntimeError (..)
  , RuntimeEffectEnvironment
  , RuntimeM (..)
  , RuntimeResult (..)
  , RuntimeState
  )

runtimeEnv :: RuntimeEffectEnvironment -> EffectSemantics -> RuntimeEnv
runtimeEnv =
  RuntimeEnv

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
    RuntimeFactDependencyCycle currentFact ->
      "fact dependency cycle while ensuring " ++ show currentFact
    RuntimeExternalTakeAutoMake currentFact ->
      "cannot auto-make externalTake fact " ++ show currentFact
    RuntimeMissingImplementation currentProfile currentSend ->
      "missing implementation for " ++ show currentSend ++ " in profile " ++ show currentProfile
    RuntimeHandlerFailed currentSend message ->
      "externalMake " ++ show currentSend ++ " failed: " ++ message
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
