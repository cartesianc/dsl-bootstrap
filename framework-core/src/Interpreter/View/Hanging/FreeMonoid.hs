module Interpreter.View.Hanging.FreeMonoid
  ( freeMonoidHanging
  , freeMonoidMiddleware
  ) where

import AST.Vocabulary
  ( Interceptor
  , WorkflowFact
  )
import Core.Architecture
import Core.Architecture.Internal
  ( FreeMonoid (..)
  )
import Interpreter.View.Program
  ( Program
  , childIndent
  , printNode
  , renderInterceptor
  )

freeMonoidHanging :: Int -> Hanging (HangingAction WorkflowFact Interceptor Program) -> IO ()
freeMonoidHanging indent actions =
  mapM_ (runHangingAction indent) (freeMonoidItems (hangingActions actions))

freeMonoidMiddleware :: Middleware Interceptor -> Program -> Program
freeMonoidMiddleware currentMiddleware body indent = do
  printNode indent ("middleware " ++ renderInterceptor (middlewareHook currentMiddleware))
  body (childIndent indent)

runHangingAction :: Int -> HangingAction WorkflowFact Interceptor Program -> IO ()
runHangingAction indent (HangingCallback currentCallback) = do
  printNode indent ("callback " ++ show (callbackTarget currentCallback))
  printNode (childIndent indent) "run"
  callbackBody currentCallback (childIndent (childIndent indent))
runHangingAction indent (HangingSuspense currentSuspense) = do
  printNode indent ("suspense " ++ show (suspenseTarget currentSuspense))
runHangingAction indent (HangingLoop currentLoop) = do
  printNode indent "loop"
  printNode (childIndent indent) "repeat"
  loopBody currentLoop (childIndent (childIndent indent))
runHangingAction indent (HangingMiddleware currentMiddleware body) =
  freeMonoidMiddleware currentMiddleware body indent
