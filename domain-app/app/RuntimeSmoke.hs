module Main
  ( main
  ) where

import Interpreter.Runtime.Smoke
  ( runRuntimeBoundarySmoke
  )

main :: IO ()
main =
  runRuntimeBoundarySmoke
