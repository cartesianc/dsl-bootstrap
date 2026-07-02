module Framework.Background
  ( NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , NativeRuntime
  , RuntimeArtifact (..)
  , SendContract (..)
  , buildApp
  , buildNativeApp
  , module Framework.Background.ConstraintProof
  , module Framework.Background.RuntimeDiagnosis
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
import Framework.Background.ConstraintProof
import Framework.Background.RuntimeDiagnosis
import Framework.Runtime

buildApp :: AppBlueprint -> EffectTheory -> Either String NativeAppPlan
buildApp =
  buildNativeApp
