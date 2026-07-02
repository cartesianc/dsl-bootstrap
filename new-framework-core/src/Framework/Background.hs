module Framework.Background
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , NativeHandler (..)
  , NativeRuntime (..)
  , RuntimeArtifact (..)
  , RuntimeEffectEnvironment (..)
  , SendContract (..)
  , TransformBinding (..)
  , TransformRegistry (..)
  , buildApp
  , buildNativeApp
  , emptyHandlerRegistry
  , emptyTransformRegistry
  , handlerFor
  , renderNativeAppError
  , runBlueprintWithEffectEnvironment
  , runNativeBlueprintWithEffectEnvironment
  , runNativeBlueprintWithEffectEnvironmentResult
  , runtimeEffectEnvironment
  , runtimeEffectEnvironmentWithTransforms
  ) where

import Bootstrap.Effect
  ( EffectTheory )
import Bootstrap.Runtime
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , NativeHandler (..)
  , NativeRuntime (..)
  , RuntimeArtifact (..)
  , RuntimeEffectEnvironment (..)
  , SendContract (..)
  , TransformBinding (..)
  , TransformRegistry (..)
  , buildNativeApp
  , handlerFor
  , renderNativeAppError
  , runNativeBlueprintWithEffectEnvironment
  , runNativeBlueprintWithEffectEnvironmentResult
  )
import Bootstrap.Workflow
  ( AppBlueprint )

buildApp :: AppBlueprint -> EffectTheory -> Either String NativeAppPlan
buildApp =
  buildNativeApp

runBlueprintWithEffectEnvironment :: RuntimeEffectEnvironment -> EffectTheory -> AppBlueprint -> IO ()
runBlueprintWithEffectEnvironment =
  runNativeBlueprintWithEffectEnvironment

runtimeEffectEnvironment :: HandlerRegistry -> RuntimeEffectEnvironment
runtimeEffectEnvironment handlers =
  RuntimeEffectEnvironment handlers emptyTransformRegistry

runtimeEffectEnvironmentWithTransforms :: HandlerRegistry -> TransformRegistry -> RuntimeEffectEnvironment
runtimeEffectEnvironmentWithTransforms =
  RuntimeEffectEnvironment

emptyHandlerRegistry :: HandlerRegistry
emptyHandlerRegistry =
  HandlerRegistry []

emptyTransformRegistry :: TransformRegistry
emptyTransformRegistry =
  TransformRegistry []

