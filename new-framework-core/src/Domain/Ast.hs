module Domain.Ast
  ( AstRegistration (..)
  , astRegistrationNames
  , frameworkCoreAst
  , frameworkCoreAstRegistration
  , registeredAsts
  ) where

import qualified Bootstrap.Blueprint
import Bootstrap.Workflow
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
    , astRegistrationBlueprint = Bootstrap.Blueprint.coreBootstrapBlueprint
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
