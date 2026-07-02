module Framework.Background
  ( NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , NativeRuntime
  , RuntimeArtifact (..)
  , SendContract (..)
  , buildApp
  , buildNativeApp
  , module Framework.Runtime
  , renderNativeAppError
  , runNativeBlueprintWithEffectEnvironment
  , runNativeBlueprintWithEffectEnvironmentResult
  ) where

import Bootstrap.Effect
  ( EffectTheory )
import Bootstrap.Runtime
  ( NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , NativeRuntime
  , RuntimeArtifact (..)
  , SendContract (..)
  , buildNativeApp
  , renderNativeAppError
  , runNativeBlueprintWithEffectEnvironment
  , runNativeBlueprintWithEffectEnvironmentResult
  )
import Bootstrap.Workflow
  ( AppBlueprint )
import Framework.Runtime

buildApp :: AppBlueprint -> EffectTheory -> Either String NativeAppPlan
buildApp =
  buildNativeApp
