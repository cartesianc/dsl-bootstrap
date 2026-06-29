module Interpreter.Runtime.Contextware
  ( contextware
  ) where

import Interpreter.Runtime.Types
  ( RuntimeContextware
  )

contextware :: RuntimeContextware
contextware _effects algebra =
  algebra
