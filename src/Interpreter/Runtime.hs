module Interpreter.Runtime
  ( Runtime (..)
  , runApp
  , runAppWith
  ) where

import AppBlueprint
  ( App
  )
import Interpreter.Core
  ( interpret
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
  _ <- interpret runtimeAlgebra appArchitecture runtime
  pure ()
