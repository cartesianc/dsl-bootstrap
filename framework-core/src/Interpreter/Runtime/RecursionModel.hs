module Interpreter.Runtime.RecursionModel
  ( cata
  ) where

import Interpreter.Runtime
  ( runBlueprintWithAlgebra
  )
import Interpreter.Runtime.Types
  ( RuntimeRecursionModel
  , emptyRuntime
  )

cata :: RuntimeRecursionModel
cata algebra =
  runBlueprintWithAlgebra algebra emptyRuntime
