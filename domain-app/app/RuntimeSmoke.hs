module Main
  ( main
  ) where

import Runtime.Smoke
  ( runRuntimeBoundarySmoke
  )

main :: IO ()
main =
  runRuntimeBoundarySmoke
