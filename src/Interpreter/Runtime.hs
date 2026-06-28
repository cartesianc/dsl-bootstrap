module Interpreter.Runtime
  ( Runtime (..)
  , runApp
  , runAppWith
  , runBlueprint
  , runBlueprintWith
  ) where

import AST.AppBlueprint
  ( App
  , AppBlueprint (..)
  )
import Core.Architecture.Cata
  ( cataHanging
  , cataWorkflow
  )
import Interpreter.Runtime.Algebra
  ( runtimeAlgebra
  )
import Interpreter.Runtime.Hanging.FreeMonoid
  ( runHanging
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

runBlueprint :: AppBlueprint -> IO ()
runBlueprint =
  runBlueprintWith emptyRuntime

runBlueprintWith :: Runtime -> AppBlueprint -> IO ()
runBlueprintWith runtime blueprint = do
  appRuntime <- cataWorkflow runtimeAlgebra (blueprintApp blueprint) runtime
  _ <- runHanging (cataHanging runtimeAlgebra (blueprintHanging blueprint)) appRuntime
  pure ()
