module Interpreter
  ( Runtime (..)
  , interpreter
  , runApp
  , runAppWith
  , runBlueprint
  , runBlueprintWith
  ) where

import AST.AppBlueprint
  ( AppBlueprint
  )
import Interpreter.Contextware
  ( contextware
  )
import Interpreter.FAlgebra
  ( fAlgebra
  )
import Interpreter.RecursionModel
  ( cataModel
  )
import Interpreter.Runtime
  ( Runtime (..)
  , runApp
  , runAppWith
  , runBlueprint
  , runBlueprintWith
  )

interpreter :: AppBlueprint -> IO ()
interpreter ast =
  cataModel (contextware fAlgebra) ast
