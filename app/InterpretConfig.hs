{-# OPTIONS_GHC -Wno-name-shadowing #-}
module InterpretConfig
  ( InterpretConfig (..)
  , currentInterpreter
  , interpretConfig
  ) where

import AST.AppBlueprint
  ( AppBlueprint
  )
import Interpreter.Contextware
  ( contextware
  )
import Interpreter.FAlgebra
  ( FAlgebra
  , fAlgebra
  )
import Interpreter.RecursionModel
  ( cataModel
  )
import Interpreter.Types
  ( Contextware
  , RecursionModel
  )

data InterpretConfig = InterpretConfig
  { interpretRecursionModel :: RecursionModel
  , interpretContextware :: Contextware
  , interpretFAlgebra :: FAlgebra
  }

recursionScheme ::
  RecursionModel ->
  Contextware ->
  FAlgebra ->
  AppBlueprint ->
  IO ()
recursionScheme model contextware fAlgebra =
  model (contextware fAlgebra)

currentInterpreter :: AppBlueprint -> IO ()
currentInterpreter = recursionScheme
    (interpretRecursionModel interpretConfig)
    (interpretContextware interpretConfig)
    (interpretFAlgebra interpretConfig)

interpretConfig :: InterpretConfig
interpretConfig =
  InterpretConfig
    { interpretRecursionModel = cataModel
    , interpretContextware = contextware
    , interpretFAlgebra = fAlgebra
    }
