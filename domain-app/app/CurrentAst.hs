{-# LANGUAGE PackageImports #-}

module CurrentAst
  ( currentAst
  ) where

import "domain-app" Domain.AppBlueprint
  ( AppBlueprint
  , blueprint
  )

currentAst :: AppBlueprint
currentAst =
  blueprint
