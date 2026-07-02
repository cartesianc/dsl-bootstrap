{-# LANGUAGE PackageImports #-}

module CurrentAst
  ( currentAst
  ) where

import "demo-domain-app" Domain.AppBlueprint
  ( AppBlueprint
  , blueprint
  )

currentAst :: AppBlueprint
currentAst =
  blueprint
