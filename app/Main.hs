module Main
  ( main
  ) where

import CurrentAst
  ( currentAst
  )
import CurrentEffects
  ( currentEffects
  )
import InterpretConfig
  ( currentInterpreter
  )

main :: IO ()
main =
  currentInterpreter currentAst currentEffects
