module Main
  ( main
  ) where

import AppBlueprint
import qualified Interpreter.View as Interpreter

main :: IO ()
main =
  Interpreter.interpret app
