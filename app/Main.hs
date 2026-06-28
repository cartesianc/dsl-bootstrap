module Main
  ( main
  ) where

import CurrentAst
  ( currentAst
  )
import InterpretConfig
  ( currentInterpreter
  )

main :: IO ()
main =
  currentInterpreter currentAst
