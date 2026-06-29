module Interpreter.Runtime.Types
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , Registry
  , Runtime (..)
  , RuntimeContextware
  , RuntimeEnv (..)
  , RuntimeError (..)
  , RuntimeEffectEnvironment (..)
  , RuntimeFAlgebra
  , RuntimeHandler (..)
  , RuntimeM (..)
  , RuntimeMiddlewareEvent (..)
  , RuntimeRecursionModel
  , RuntimeResult (..)
  , RuntimeState
  , WorkflowProgram
  , emptyRuntime
  ) where

import AST.Vocabulary
  ( Interceptor
  , WorkflowFact
  )
import AST.AppBlueprint
  ( AppBlueprint
  )
import Core.Effect.Semantics
  ( EffectSemantics
  )
import Core.Workflow.Eff
  ( WorkflowEffAlgebra
  )
import Effects.EffectTheory
  ( EffectTheory
  )
import Effects.Names
  ( ImplementationName
  , ProfileName
  , SendName
  )

data Runtime = Runtime
  { availableFacts :: [WorkflowFact]
  , runtimeTrace :: [String]
  , runtimeMiddlewareStack :: [Interceptor]
  , runtimeMiddlewareEvents :: [RuntimeMiddlewareEvent]
  }
  deriving (Eq, Show)

type RuntimeState = Runtime

data RuntimeMiddlewareEvent
  = RuntimeMiddlewareEntered Interceptor
  | RuntimeMiddlewareExited Interceptor
  deriving (Eq, Show)

data HandlerResult
  = HandlerSucceeded
  | HandlerFailed String
  deriving (Eq, Show)

newtype RuntimeHandler = RuntimeHandler
  { runRuntimeHandler :: SendName -> Runtime -> IO HandlerResult
  }

data HandlerBinding = HandlerBinding
  { handlerBindingName :: ImplementationName
  , handlerBindingHandler :: RuntimeHandler
  }

newtype HandlerRegistry = HandlerRegistry
  { handlerRegistryBindings :: [HandlerBinding]
  }

data RuntimeEffectEnvironment = RuntimeEffectEnvironment
  { runtimeEffectProfile :: ProfileName
  , runtimeEffectHandlers :: HandlerRegistry
  }

data RuntimeEnv = RuntimeEnv
  { runtimeEnvEffectEnvironment :: RuntimeEffectEnvironment
  , runtimeEnvEffectSemantics :: EffectSemantics
  }

data RuntimeError
  = RuntimeMissingFactRule WorkflowFact
  | RuntimeFactDependencyCycle WorkflowFact
  | RuntimeExternalTakeAutoMake WorkflowFact
  | RuntimeMissingImplementation ProfileName SendName
  | RuntimeHandlerFailed SendName String
  | RuntimeWaitBlocked String
  | RuntimeChoiceMissingBranch String
  | RuntimeFallbackExhausted
  | RuntimeRaceEmpty
  | RuntimeRaceExhausted
  | RuntimeIoException String
  deriving (Eq, Show)

data RuntimeResult a
  = RuntimeSucceeded a RuntimeState
  | RuntimeFailed RuntimeError RuntimeState
  deriving (Eq, Show)

newtype RuntimeM a = RuntimeM
  { runRuntimeMInternal :: RuntimeEnv -> RuntimeState -> IO (RuntimeResult a)
  }

instance Functor RuntimeM where
  fmap transform program =
    RuntimeM $ \environment state -> do
      result <- runRuntimeMInternal program environment state
      case result of
        RuntimeSucceeded value nextState ->
          pure (RuntimeSucceeded (transform value) nextState)
        RuntimeFailed errorReport nextState ->
          pure (RuntimeFailed errorReport nextState)

instance Applicative RuntimeM where
  pure value =
    RuntimeM $ \_ state ->
      pure (RuntimeSucceeded value state)

  functionProgram <*> valueProgram =
    RuntimeM $ \environment state -> do
      functionResult <- runRuntimeMInternal functionProgram environment state
      case functionResult of
        RuntimeFailed errorReport nextState ->
          pure (RuntimeFailed errorReport nextState)
        RuntimeSucceeded transform nextState ->
          runRuntimeMInternal (fmap transform valueProgram) environment nextState

instance Monad RuntimeM where
  program >>= next =
    RuntimeM $ \environment state -> do
      result <- runRuntimeMInternal program environment state
      case result of
        RuntimeFailed errorReport nextState ->
          pure (RuntimeFailed errorReport nextState)
        RuntimeSucceeded value nextState ->
          runRuntimeMInternal (next value) environment nextState

type Registry = [WorkflowFact]

type WorkflowProgram = RuntimeM ()

type RuntimeFAlgebra = WorkflowEffAlgebra WorkflowFact WorkflowProgram

type RuntimeRecursionModel = RuntimeFAlgebra -> AppBlueprint -> IO ()

type RuntimeContextware = EffectTheory -> RuntimeFAlgebra -> RuntimeFAlgebra

emptyRuntime :: Runtime
emptyRuntime =
  Runtime
    { availableFacts = []
    , runtimeTrace = []
    , runtimeMiddlewareStack = []
    , runtimeMiddlewareEvents = []
    }
