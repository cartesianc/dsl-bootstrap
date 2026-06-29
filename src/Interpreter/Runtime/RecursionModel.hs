module Interpreter.Runtime.RecursionModel
  ( cata
  ) where

import AST.AppBlueprint
  ( AppBlueprint (..)
  )
import Core.Architecture.Cata
  ( cataHanging
  , cataWorkflow
  )
import Interpreter.Runtime.Hanging.FreeMonoid
  ( runHanging
  )
import Interpreter.Runtime.Types
  ( RuntimeRecursionModel
  , emptyRuntime
  )

cata :: RuntimeRecursionModel
cata algebra =
  cataAfterCheck algebra

cataAfterCheck :: RuntimeRecursionModel
cataAfterCheck algebra ast = do
  appRuntime <- cataWorkflow algebra (blueprintApp ast) emptyRuntime
  _ <- runHanging (cataHanging algebra (blueprintHanging ast)) appRuntime
  pure ()
