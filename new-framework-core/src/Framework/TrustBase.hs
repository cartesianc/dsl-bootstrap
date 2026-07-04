module Framework.TrustBase
  ( TrustBaseRuntimeEffectEnvironment
  , NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , NativeRuntime
  , RuntimeArtifact (..)
  , SendContract (..)
  , Runtime (..)
  , RuntimeError (..)
  , RuntimeFactClaim (..)
  , RuntimeFactFailure (..)
  , RuntimeFactStatus (..)
  , RuntimeResult (..)
  , RuntimeSnapshot (..)
  , DomainRegistration (domainRegistrationName)
  , DomainSemanticCheck (..)
  , DomainSemanticEvidence
  , bootstrapRuntimeEffectEnvironment
  , buildApp
  , buildNativeApp
  , domainEvidenceFailed
  , domainEvidencePassed
  , emptyRuntime
  , renderNativeAppError
  , renderRuntimeError
  , renderRuntimeSnapshot
  , runBlueprintWithEffectEnvironment
  , runBlueprintWithEffectEnvironmentResult
  , runBlueprintWithEffectEnvironmentRuntimeResult
  , runNativeBlueprintWithEffectEnvironment
  , runNativeBlueprintWithEffectEnvironmentResult
  , runtimeSnapshot
  , module Framework.Background.ConstraintProof
  , module Framework.FixedPoint
  , module Framework.RegistryCodegen
  , module Framework.Runtime.Concurrency
  , module Framework.Runtime.Diagnosis
  , module Framework.Runtime.Evidence
  , module Framework.Runtime.HotPath
  , module Framework.Runtime.Policy
  , module Framework.SelfArtifact
  , module Framework.TrustBase.Manifest
  , module Framework.Workflow.Semantics
  ) where

import Bootstrap.Effect
  ( EffectTheory )
import qualified Bootstrap.Runtime as Native
import Bootstrap.Runtime
  ( NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , NativeRuntime
  , RuntimeArtifact (..)
  , SendContract (..)
  )
import Bootstrap.Workflow
  ( AppBlueprint )
import Framework.Background.ConstraintProof
import Framework.Domain
  ( DomainRegistration (domainRegistrationName)
  , DomainSemanticCheck (..)
  , DomainSemanticEvidence
  , domainEvidenceFailed
  , domainEvidencePassed
  )
import Framework.FixedPoint
import Framework.RegistryCodegen
import Framework.Runtime.Concurrency
import Framework.Runtime.Interpreter
  ( Runtime (..)
  , RuntimeError (..)
  , RuntimeFactClaim (..)
  , RuntimeFactFailure (..)
  , RuntimeFactStatus (..)
  , RuntimeResult (..)
  , RuntimeSnapshot (..)
  , emptyRuntime
  , renderRuntimeError
  , renderRuntimeSnapshot
  , runBlueprintWithEffectEnvironment
  , runBlueprintWithEffectEnvironmentResult
  , runBlueprintWithEffectEnvironmentRuntimeResult
  , runtimeSnapshot
  )
import Framework.Runtime.Diagnosis
import Framework.Runtime.Evidence
import Framework.Runtime.HotPath
import Framework.Runtime.Policy
import Framework.SelfArtifact
import Framework.TrustBase.Manifest
import Framework.Workflow.Semantics

type TrustBaseRuntimeEffectEnvironment = Native.RuntimeEffectEnvironment

bootstrapRuntimeEffectEnvironment :: TrustBaseRuntimeEffectEnvironment
bootstrapRuntimeEffectEnvironment =
  Native.bootstrapRuntimeEffectEnvironment

buildApp :: AppBlueprint -> EffectTheory -> Either String NativeAppPlan
buildApp =
  Native.buildNativeApp

buildNativeApp :: AppBlueprint -> EffectTheory -> Either String NativeAppPlan
buildNativeApp =
  Native.buildNativeApp

renderNativeAppError :: String -> String
renderNativeAppError =
  Native.renderNativeAppError

runNativeBlueprintWithEffectEnvironment ::
  TrustBaseRuntimeEffectEnvironment ->
  EffectTheory ->
  AppBlueprint ->
  IO ()
runNativeBlueprintWithEffectEnvironment =
  Native.runNativeBlueprintWithEffectEnvironment

runNativeBlueprintWithEffectEnvironmentResult ::
  TrustBaseRuntimeEffectEnvironment ->
  EffectTheory ->
  AppBlueprint ->
  IO (Either String Native.NativeRuntime)
runNativeBlueprintWithEffectEnvironmentResult =
  Native.runNativeBlueprintWithEffectEnvironmentResult
