module Framework.TrustBase
  ( TrustBaseRuntimeEffectEnvironment
  , NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , NativeRuntime
  , RuntimeArtifact (..)
  , SendContract (..)
  , Runtime (..)
  , RuntimeDiagnosisBlocker (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisNodeKind (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeError (..)
  , RuntimeFactClaim (..)
  , RuntimeFactFailure (..)
  , RuntimeFactStatus (..)
  , RuntimeFailureDiagnosis (..)
  , RuntimeResult (..)
  , RuntimeSnapshot (..)
  , DomainRegistration (domainRegistrationName)
  , DomainSemanticCheck (..)
  , DomainSemanticEvidence
  , bootstrapRuntimeEffectEnvironment
  , buildApp
  , buildFailureDiagnosis
  , buildNativeApp
  , completeDiagnosisProbe
  , diagnosisProbePairs
  , domainEvidenceFailed
  , domainEvidencePassed
  , emptyRuntime
  , recordRuntimeDiagnosis
  , renderNativeAppError
  , renderRuntimeError
  , renderRuntimeFailureDiagnosis
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
  , module Framework.SelfArtifact
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
import Framework.Runtime
  ( Runtime (..)
  , RuntimeDiagnosisBlocker (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisNodeKind (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeError (..)
  , RuntimeFactClaim (..)
  , RuntimeFactFailure (..)
  , RuntimeFactStatus (..)
  , RuntimeFailureDiagnosis (..)
  , RuntimeResult (..)
  , RuntimeSnapshot (..)
  , buildFailureDiagnosis
  , completeDiagnosisProbe
  , diagnosisProbePairs
  , emptyRuntime
  , recordRuntimeDiagnosis
  , renderRuntimeError
  , renderRuntimeFailureDiagnosis
  , renderRuntimeSnapshot
  , runBlueprintWithEffectEnvironment
  , runBlueprintWithEffectEnvironmentResult
  , runBlueprintWithEffectEnvironmentRuntimeResult
  , runtimeSnapshot
  )
import Framework.SelfArtifact

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
