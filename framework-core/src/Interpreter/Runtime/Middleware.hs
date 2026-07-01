module Interpreter.Runtime.Middleware
  ( enterRuntimeMiddleware
  , exitRuntimeMiddleware
  , withRuntimeMiddleware
  ) where

import AST.Vocabulary
  ( Interceptor
  )
import Interpreter.Runtime.Monad
  ( modifyRuntimeState
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , RuntimeM (..)
  , RuntimeMiddlewareEvent (..)
  , RuntimeResult (..)
  , WorkflowProgram
  )

enterRuntimeMiddleware :: Interceptor -> WorkflowProgram
enterRuntimeMiddleware currentMiddleware =
  modifyRuntimeState (pushRuntimeMiddleware currentMiddleware)

exitRuntimeMiddleware :: Interceptor -> WorkflowProgram
exitRuntimeMiddleware currentMiddleware =
  modifyRuntimeState (popRuntimeMiddleware currentMiddleware)

withRuntimeMiddleware :: Interceptor -> WorkflowProgram -> WorkflowProgram
withRuntimeMiddleware currentMiddleware body =
  RuntimeM $ \environment state -> do
    result <- runRuntimeMInternal body environment (pushRuntimeMiddleware currentMiddleware state)
    pure (exitResult result)
  where
    exitResult result =
      case result of
        RuntimeSucceeded value nextState ->
          RuntimeSucceeded value (popRuntimeMiddleware currentMiddleware nextState)
        RuntimeFailed errorReport nextState ->
          RuntimeFailed errorReport (popRuntimeMiddleware currentMiddleware nextState)

pushRuntimeMiddleware :: Interceptor -> Runtime -> Runtime
pushRuntimeMiddleware currentMiddleware runtime =
  runtime
    { runtimeMiddlewareStack =
        currentMiddleware : runtimeMiddlewareStack runtime
    , runtimeMiddlewareEvents =
        runtimeMiddlewareEvents runtime <> [RuntimeMiddlewareEntered currentMiddleware]
    }

popRuntimeMiddleware :: Interceptor -> Runtime -> Runtime
popRuntimeMiddleware currentMiddleware runtime =
  runtime
    { runtimeMiddlewareStack =
        popFirst currentMiddleware (runtimeMiddlewareStack runtime)
    , runtimeMiddlewareEvents =
        runtimeMiddlewareEvents runtime <> [RuntimeMiddlewareExited currentMiddleware]
    }

popFirst :: Interceptor -> [Interceptor] -> [Interceptor]
popFirst _ [] =
  []
popFirst currentMiddleware (candidate : rest)
  | currentMiddleware == candidate =
      rest
  | otherwise =
      candidate : popFirst currentMiddleware rest
