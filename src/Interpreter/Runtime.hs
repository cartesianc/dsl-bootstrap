module Interpreter.Runtime
  ( Runtime (..)
  , runApp
  , runAppWith
  ) where

import AST.AppBlueprint
  ( App
  )
import Core.Architecture.Cata
  ( cataWorkflow
  )
import Interpreter.Runtime.Algebra
  ( runtimeAlgebra
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , emptyRuntime
  )

runApp :: App -> IO ()
runApp =
  runAppWith emptyRuntime

runAppWith :: Runtime -> App -> IO ()
runAppWith runtime appArchitecture = do
  _ <- cataWorkflow runtimeAlgebra appArchitecture runtime
  pure ()
