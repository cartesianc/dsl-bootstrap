module Interpreter.View
  ( interpret
  , interpretBlueprint
  , printAppBlueprint
  , renderAppBlueprint
  ) where

import AppBlueprint
  ( App
  )
import qualified Interpreter.Core as Core
import Interpreter.View.Algebra
  ( Tree (..)
  , blueprintViewAlgebra
  , renderTree
  )

interpret :: App -> IO ()
interpret =
  interpretBlueprint

interpretBlueprint :: App -> IO ()
interpretBlueprint =
  printAppBlueprint

renderAppBlueprint :: App -> String
renderAppBlueprint ast =
  unlines (renderTree (Tree "app" [Core.interpret blueprintViewAlgebra ast]))

printAppBlueprint :: App -> IO ()
printAppBlueprint =
  putStr . renderAppBlueprint
