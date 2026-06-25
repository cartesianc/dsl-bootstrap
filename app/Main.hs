module Main
  ( main
  ) where

import AST.AppBlueprint
import Interpreter
  ( interpreter
  )

main :: IO ()
main =
  interpreter blueprint
