module Domain.AppBlueprint
  ( frameworkCoreApp
  , frameworkCoreBlueprint
  , frameworkCoreHooks
  ) where

import Bootstrap.Blueprint
  ( coreBootstrapApp
  , coreBootstrapBlueprint
  , coreBootstrapHanging
  )
import Bootstrap.Workflow
  ( App
  , AppBlueprint (..)
  , AppHanging
  )

frameworkCoreBlueprint :: AppBlueprint
frameworkCoreBlueprint =
  coreBootstrapBlueprint

frameworkCoreApp :: App
frameworkCoreApp =
  coreBootstrapApp

frameworkCoreHooks :: AppHanging
frameworkCoreHooks =
  coreBootstrapHanging
