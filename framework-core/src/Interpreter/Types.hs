module Interpreter.Types
  ( Contextware
  , RecursionModel
  ) where

import AST.AppBlueprint
  ( AppBlueprint
  )
import Interpreter.FAlgebra
  ( FAlgebra
  )

type RecursionModel = FAlgebra -> AppBlueprint -> IO ()

type Contextware = FAlgebra -> FAlgebra
