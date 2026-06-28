module Interpreter.View.Algebra
  ( Program
  , factProgram
  , middlewareProgram
  , runBlueprint
  , runProgram
  ) where

import AST.Vocabulary
  ( Interceptor
  , WorkflowFact
  )
import Core.Architecture
  ( Hanging
  , HangingAction
  , Middleware
  )
import Interpreter.View.Hanging.FreeMonoid
  ( freeMonoidHanging
  , freeMonoidMiddleware
  )
import Interpreter.View.Program
  ( Program
  , childIndent
  , factProgram
  , firstChildIndent
  , printNode
  )

runProgram :: Program -> IO ()
runProgram program = do
  putStrLn "app"
  program firstChildIndent

runBlueprint :: Program -> Hanging (HangingAction WorkflowFact Interceptor Program) -> IO ()
runBlueprint appProgram hooks = do
  putStrLn "blueprint"
  printNode firstChildIndent "app"
  appProgram (childIndent firstChildIndent)
  printNode firstChildIndent "hanging"
  freeMonoidHanging (childIndent firstChildIndent) hooks

middlewareProgram :: Middleware Interceptor -> Program -> Program
middlewareProgram =
  freeMonoidMiddleware
