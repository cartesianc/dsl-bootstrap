module Interpreter.View.Workflow.FreeAlternative
  ( freeAlternativeFallback
  , freeAlternativeRace
  ) where

import Core.Architecture
  ( Fallback (..)
  , Race (..)
  )
import Core.Architecture.Internal
  ( FreeAlternative (..)
  )
import Interpreter.View.Program
  ( Program
  , childIndent
  , printNode
  , runChildren
  )

freeAlternativeFallback :: Fallback Program -> Program
freeAlternativeFallback branches indent = do
  printNode indent "fallback"
  runChildren (childIndent indent) (freeAlternativeBranches (fallbackBranches branches))

freeAlternativeRace :: Race Program -> Program
freeAlternativeRace branches indent = do
  printNode indent "race"
  runChildren (childIndent indent) (freeAlternativeBranches (raceBranches branches))
