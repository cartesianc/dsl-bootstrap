module Domain.Ast
  ( AstRegistration (..)
  , astRegistrationNames
  , frameworkCoreAst
  , frameworkCoreAstRegistration
  , registeredAsts
  ) where

import Domain.AppBlueprint
  ( frameworkCoreBlueprint )
import Framework.Workflow
  ( AppBlueprint
  )

data AstRegistration = AstRegistration
  { astRegistrationName :: String
  , astRegistrationBlueprint :: AppBlueprint
  }

frameworkCoreAstRegistration :: AstRegistration
frameworkCoreAstRegistration =
  AstRegistration
    { astRegistrationName = "framework-core"
    , astRegistrationBlueprint = frameworkCoreBlueprint
    }

registeredAsts :: [AstRegistration]
registeredAsts =
  [frameworkCoreAstRegistration]

astRegistrationNames :: [String]
astRegistrationNames =
  map astRegistrationName registeredAsts

frameworkCoreAst :: AppBlueprint
frameworkCoreAst =
  astRegistrationBlueprint frameworkCoreAstRegistration
