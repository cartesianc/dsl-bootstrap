module FrameworkCore.CurrentAst
  ( currentAst
  ) where

import Domain.AppBlueprint
  ( frameworkCoreBlueprint
  )
import Framework.Ast
  ( AppBlueprint
  )

currentAst :: AppBlueprint
currentAst =
  frameworkCoreBlueprint
