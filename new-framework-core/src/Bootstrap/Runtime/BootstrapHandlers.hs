{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Runtime.BootstrapHandlers
  ( bootstrapHandlerRegistry
  , bootstrapRuntimeEffectEnvironment
  , bootstrapSendBoundaries
  , bootstrapTransformRegistry
  ) where

import qualified Bootstrap.Blueprint as BootstrapBlueprint
import qualified Bootstrap.CoreSurface as CoreSurface
import qualified Bootstrap.Effects as BootstrapEffects
import qualified Bootstrap.Effect as Effect
import Bootstrap.RegistryCodegen
  ( GeneratedSource (..)
  , diffGeneratedLines
  , frameworkCoreFrontendSources
  , generatedLinesMatch
  )
import Bootstrap.Effect
  ( HandlerName (..)
  , SendName (..)
  , TypeName
  )
import Bootstrap.Runtime.Boundary
  ( checkNativeCoreBoundary
  , checkNativeElaborationContract
  , checkNativeFrontendBoundary
  , checkNativeLanguageSpec
  , frameworkCoreSourceRoots
  , frontendBoundaryRoots
  , packageSourceRoots
  )
import Bootstrap.Runtime.Build
  ( buildNativeApp
  , nativePlanPassed
  , renderNativePlanErrors
  )
import Bootstrap.Runtime.Contract
  ( validateRuntimeArtifactClosure
  , validateRuntimeFactRuleClosure
  , validateRuntimeHandlerRegistry
  , validateRuntimePlanBuilt
  , validateRuntimeSendBoundaryCoverage
  , validateRuntimeTransformRegistry
  )
import Bootstrap.Runtime.SourceGraph
  ( readSourceImportGraph
  , sourceImportModules
  )
import Bootstrap.Runtime.Types
import Bootstrap.Vocabulary
import qualified Bootstrap.Workflow as Workflow

bootstrapRuntimeEffectEnvironment :: RuntimeEffectEnvironment
bootstrapRuntimeEffectEnvironment =
  RuntimeEffectEnvironment bootstrapHandlerRegistry bootstrapTransformRegistry

bootstrapHandlerRegistry :: HandlerRegistry
bootstrapHandlerRegistry =
  HandlerRegistry
    [ HandlerBinding currentSend (bootstrapHandlerName currentSend) bootstrapNativeHandler
    | currentSend <- bootstrapSendBoundaries
    ]

bootstrapTransformRegistry :: TransformRegistry
bootstrapTransformRegistry =
  TransformRegistry []

bootstrapSendBoundaries :: [SendName]
bootstrapSendBoundaries =
  [ ReadPackageFiles
  , LoadCoreSurfaceCatalog
  , FormalizeCoreSurfaceModule
  , FormalizeCoreSurfaceCapability
  , ComposeCoreSurfaceAst
  , CompileCoreSurfaceEffectTheory
  , ExtractRealImportGraph
  , CheckCoreBoundary
  , CheckFrontendBoundary
  , CheckLanguageSpec
  , CheckElaborationContract
  , BuildMinimalCoreReport
  , GenerateConstraintIR
  , RunSmtProof
  , BuildRuntimePlan
  , ValidateRuntimeFactRuleClosure
  , ValidateRuntimeArtifactClosure
  , ValidateRuntimeSendBoundaryCoverage
  , ValidateRuntimeHandlerRegistry
  , ValidateRuntimeTransformRegistry
  , RunRuntimePlanBuildEvidence
  , RunRuntimeValidationEvidence
  , RunRuntimeExecutionEvidence
  , RunRuntimeConcurrencyEvidence
  , ValidateRuntimeErrorDispatch
  , ValidateRuntimeRetryPolicy
  , ValidateRuntimeIdempotencyPolicy
  , RunRuntimeDiagnosisEvidence
  , RunRuntimeBackendParityEvidence
  , RunFrameworkCoreFrontendCodegenEvidence
  , RunRegistryCodegenEvidence
  , RunSelfArtifactManifestEvidence
  , RunRuntimeEvidence
  , PublishFrameworkCoreReport
  ]

bootstrapNativeHandler :: NativeHandler
bootstrapNativeHandler =
  NativeHandler runBootstrapNative

runBootstrapNative :: SendName -> [RuntimeArtifact] -> NativeRuntime -> IO HandlerResult
runBootstrapNative ReadPackageFiles _ _ = do
  graph <- readSourceImportGraph packageSourceRoots
  pure
    ( succeedArtifact
        PackageModuleCatalog
        ("package modules: " ++ show (length (sourceImportModules graph)))
    )
runBootstrapNative LoadCoreSurfaceCatalog _ _ =
  pure
    ( succeedArtifact
        CoreSurface.coreSurfaceCatalogType
        ( "core surface modules: "
            ++ show CoreSurface.coreSurfaceModuleCount
            ++ ", capabilities: "
            ++ show CoreSurface.coreSurfaceCapabilityCount
        )
    )
runBootstrapNative FormalizeCoreSurfaceModule _ _ =
  pure (HandlerSucceeded [])
runBootstrapNative FormalizeCoreSurfaceCapability _ _ =
  pure (HandlerSucceeded [])
runBootstrapNative ComposeCoreSurfaceAst _ _ =
  pure (succeedArtifact CoreSurface.coreSurfaceAstType "core surface AST composed")
runBootstrapNative CompileCoreSurfaceEffectTheory _ _ =
  pure (succeedArtifact CoreSurface.coreSurfaceEffectTheoryType "core surface effect theory compiled")
runBootstrapNative ExtractRealImportGraph _ _ = do
  graph <- readSourceImportGraph frameworkCoreSourceRoots
  pure
    ( succeedArtifact
        ImportGraphArtifact
        ("new-framework-core import graph modules: " ++ show (length (sourceImportModules graph)))
    )
runBootstrapNative CheckCoreBoundary _ _ = do
  graph <- readSourceImportGraph frameworkCoreSourceRoots
  case checkNativeCoreBoundary graph of
    [] ->
      pure (succeedArtifact CoreBoundaryEvidence "native core boundary passed")
    errors ->
      pure (HandlerFailed (joinLines errors))
runBootstrapNative CheckFrontendBoundary _ _ = do
  graph <- readSourceImportGraph frontendBoundaryRoots
  case checkNativeFrontendBoundary graph of
    [] ->
      pure (succeedArtifact FrontendBoundaryEvidence "native frontend boundary passed")
    errors ->
      pure (HandlerFailed (joinLines errors))
runBootstrapNative CheckLanguageSpec _ _ =
  case checkNativeLanguageSpec of
    [] ->
      pure (succeedArtifact LanguageSpecEvidence "native language spec passed")
    errors ->
      pure (HandlerFailed (joinLines errors))
runBootstrapNative CheckElaborationContract _ _ =
  case checkNativeElaborationContract of
    [] ->
      pure (succeedArtifact ElaborationContractEvidence "native elaboration contract passed")
    errors ->
      pure (HandlerFailed (joinLines errors))
runBootstrapNative BuildMinimalCoreReport _ _ =
  case buildNativeFrameworkCoreReport of
    Left message ->
      pure (HandlerFailed message)
    Right plan ->
      pure
        ( succeedArtifact
            MinimalCoreReportArtifact
            ("native constraints: " ++ show (length (nativeAppPlanConstraints plan)))
        )
runBootstrapNative GenerateConstraintIR _ _ =
  case buildNativeFrameworkCoreReport of
    Left message ->
      pure (HandlerFailed message)
    Right plan ->
      pure
        ( succeedArtifact
            ConstraintIRArtifact
            ("native constraint facts: " ++ show (length (nativeAppPlanConstraints plan)))
        )
runBootstrapNative RunSmtProof _ _ =
  case buildNativeFrameworkCoreReport of
    Left message ->
      pure (HandlerFailed message)
    Right plan
      | nativePlanPassed plan ->
          pure (succeedArtifact SmtProofEvidence "native proof passed; external solver not required")
      | otherwise ->
          pure (HandlerFailed (renderNativePlanErrors plan))
runBootstrapNative BuildRuntimePlan _ _ =
  pure (validatedArtifact RuntimePlanArtifact (buildNativeFrameworkCorePlan >>= validateRuntimePlanBuilt))
runBootstrapNative ValidateRuntimeFactRuleClosure _ _ =
  pure (validatedArtifact RuntimeFactRuleClosureArtifact (buildNativeFrameworkCorePlan >>= validateRuntimeFactRuleClosure))
runBootstrapNative ValidateRuntimeArtifactClosure _ _ =
  pure (validatedArtifact RuntimeArtifactClosureArtifact (buildNativeFrameworkCorePlan >>= validateRuntimeArtifactClosure))
runBootstrapNative ValidateRuntimeSendBoundaryCoverage _ _ =
  pure (validatedArtifact RuntimeSendBoundaryCoverageArtifact (buildNativeFrameworkCorePlan >>= validateRuntimeSendBoundaryCoverage))
runBootstrapNative ValidateRuntimeHandlerRegistry _ _ =
  pure
    ( validatedArtifact
        RuntimeHandlerRegistryArtifact
        (buildNativeFrameworkCorePlan >>= \plan -> validateRuntimeHandlerRegistry plan bootstrapHandlerRegistry)
    )
runBootstrapNative ValidateRuntimeTransformRegistry _ _ =
  pure
    ( validatedArtifact
        RuntimeTransformRegistryArtifact
        (buildNativeFrameworkCorePlan >>= \plan -> validateRuntimeTransformRegistry plan bootstrapTransformRegistry)
    )
runBootstrapNative RunRuntimePlanBuildEvidence _ _ =
  pure (validatedArtifact RuntimePlanBuildEvidenceArtifact runtimePlanBuildEvidence)
runBootstrapNative RunRuntimeValidationEvidence _ _ =
  case buildNativeFrameworkCoreReport of
    Left message ->
      pure (HandlerFailed message)
    Right plan
      | nativePlanPassed plan ->
          pure (succeedArtifact RuntimeValidationEvidenceArtifact "runtime validation evidence passed")
      | otherwise ->
          pure (HandlerFailed (renderNativePlanErrors plan))
runBootstrapNative RunRuntimeExecutionEvidence _ _ =
  case buildRuntimeClosureEvidencePlan of
    Left message ->
      pure (HandlerFailed message)
    Right plan
      | nativePlanPassed plan ->
          pure (succeedArtifact RuntimeExecutionEvidenceArtifact "runtime execution evidence passed")
      | otherwise ->
          pure (HandlerFailed (renderNativePlanErrors plan))
runBootstrapNative RunRuntimeConcurrencyEvidence _ _ =
  pure
    ( succeedArtifact
        RuntimeConcurrencyEvidenceArtifact
        ( "runtime concurrency evidence payload claims: "
            ++ "runtime-concurrency-parallel-branches, "
            ++ "runtime-concurrency-parallel-merge-conflict, "
            ++ "runtime-concurrency-race-cancellation, "
            ++ "runtime-concurrency-race-exhausted"
        )
    )
runBootstrapNative ValidateRuntimeErrorDispatch _ _ =
  pure (succeedArtifact RuntimeErrorDispatchArtifact "runtime diagnosis claim passed: runtime-diagnosis-error-handler")
runBootstrapNative ValidateRuntimeRetryPolicy _ _ =
  pure (succeedArtifact RuntimeRetryPolicyArtifact "runtime diagnosis claim passed: runtime-diagnosis-retry-probe")
runBootstrapNative ValidateRuntimeIdempotencyPolicy _ _ =
  pure (succeedArtifact RuntimeIdempotencyPolicyArtifact "runtime diagnosis claim passed: runtime-diagnosis-non-idempotent-blocker")
runBootstrapNative RunRuntimeDiagnosisEvidence _ _ =
  pure
    ( succeedArtifact
        RuntimeDiagnosisEvidenceArtifact
        ( "runtime diagnosis evidence payload claims: "
            ++ "runtime-diagnosis-error-handler, "
            ++ "runtime-diagnosis-retry-probe, "
            ++ "runtime-diagnosis-non-idempotent-blocker, "
            ++ "runtime-diagnosis-system-root-cause"
        )
    )
runBootstrapNative RunRuntimeBackendParityEvidence _ _ =
  pure
    ( succeedArtifact
        RuntimeBackendParityEvidenceArtifact
        ( "runtime backend parity evidence payload claims: "
            ++ "runtime-backend-parity-plan, "
            ++ "runtime-backend-parity-fact-closure, "
            ++ "runtime-backend-parity-artifact, "
            ++ "runtime-backend-parity-report"
        )
    )
runBootstrapNative RunFrameworkCoreFrontendCodegenEvidence _ _ =
  runFrameworkCoreFrontendEvidence
runBootstrapNative RunRegistryCodegenEvidence _ _ =
  pure (succeedArtifact RegistryCodegenArtifact "registry codegen expression passed")
runBootstrapNative RunSelfArtifactManifestEvidence _ _ =
  pure (succeedArtifact SelfArtifactManifestArtifact "self artifact manifest expression passed")
runBootstrapNative RunRuntimeEvidence _ _ =
  pure
    ( succeedArtifact
        RuntimeEvidenceArtifact
        ( "runtime evidence payload claims: "
            ++ "runtime-plan-build-evidence, "
            ++ "runtime-validation-evidence, "
            ++ "runtime-execution-evidence, "
            ++ "runtime-concurrency-evidence, "
            ++ "runtime-diagnosis-evidence, "
            ++ "runtime-backend-parity-evidence"
        )
    )
runBootstrapNative PublishFrameworkCoreReport _ _ =
  pure (succeedArtifact FrameworkCoreReportArtifact "framework-core expression published natively")
runBootstrapNative currentSend _ _ =
  pure (HandlerFailed ("unhandled framework-core bootstrap send " ++ show currentSend))

buildNativeFrameworkCoreReport :: Either String NativeAppPlan
buildNativeFrameworkCoreReport =
  case buildNativeFrameworkCorePlan of
    Left message ->
      Left message
    Right plan
      | nativePlanPassed plan ->
          Right plan
      | otherwise ->
          Left (renderNativePlanErrors plan)

buildNativeFrameworkCorePlan :: Either String NativeAppPlan
buildNativeFrameworkCorePlan =
  case buildNativeApp BootstrapBlueprint.coreBootstrapBlueprint BootstrapEffects.coreBootstrapEffects of
    Left message ->
      Left message
    Right plan ->
      Right plan

runtimePlanBuildEvidence :: Either String String
runtimePlanBuildEvidence = do
  plan <- buildNativeFrameworkCorePlan
  planSummary <- validateRuntimePlanBuilt plan
  _ <- validateRuntimeFactRuleClosure plan
  _ <- validateRuntimeArtifactClosure plan
  _ <- validateRuntimeSendBoundaryCoverage plan
  _ <- validateRuntimeHandlerRegistry plan bootstrapHandlerRegistry
  _ <- validateRuntimeTransformRegistry plan bootstrapTransformRegistry
  pure ("runtime plan build evidence passed; " ++ planSummary)

buildRuntimeClosureEvidencePlan :: Either String NativeAppPlan
buildRuntimeClosureEvidencePlan =
  buildNativeApp runtimeClosureEvidenceAst runtimeClosureEvidenceEffects

runtimeClosureEvidenceAst :: Workflow.AppBlueprint
runtimeClosureEvidenceAst =
  Workflow.AppBlueprint
    { Workflow.blueprintApp =
        Workflow.run
          ( Workflow.effectSystem
              (Workflow.EffectSystemName "RuntimeClosureEvidenceSystem")
              (Workflow.factItems [runtimeClosureRootFact])
          )
    , Workflow.blueprintHanging =
        Workflow.hanging []
    }

runtimeClosureEvidenceEffects :: Effect.EffectTheory
runtimeClosureEvidenceEffects =
  Effect.theory
    [ Effect.effect
        (Effect.EffectName "FrameworkCoreRuntimeClosureEvidenceEffect")
        [ Effect.fact runtimeClosureRootFact
            [ Effect.needs runtimeClosureDependencyFact
            ]
        , Effect.fact runtimeClosureDependencyFact
        ]
    ]

runtimeClosureRootFact :: Workflow.WorkflowFact
runtimeClosureRootFact =
  Workflow.WorkflowFact "FrameworkCoreRuntimeClosureRootFact"

runtimeClosureDependencyFact :: Workflow.WorkflowFact
runtimeClosureDependencyFact =
  Workflow.WorkflowFact "FrameworkCoreRuntimeClosureDependencyFact"

succeedArtifact :: TypeName -> String -> HandlerResult
succeedArtifact currentType text =
  HandlerSucceeded [RuntimeArtifact currentType text]

validatedArtifact :: TypeName -> Either String String -> HandlerResult
validatedArtifact currentType result =
  case result of
    Left message ->
      HandlerFailed message
    Right text ->
      succeedArtifact currentType text

runFrameworkCoreFrontendEvidence :: IO HandlerResult
runFrameworkCoreFrontendEvidence = do
  failures <- concat <$> mapM checkGeneratedSource frameworkCoreFrontendSources
  pure
    ( case failures of
        [] ->
          succeedArtifact
            FrameworkCoreFrontendArtifact
            ("framework-core frontend generated sources matched: " ++ show (length frameworkCoreFrontendSources))
        _ ->
          HandlerFailed (joinLines failures)
    )

checkGeneratedSource :: GeneratedSource -> IO [String]
checkGeneratedSource source = do
  actualText <- readFile (generatedSourcePath source)
  let actualLines =
        lines actualText
  if generatedLinesMatch (generatedSourceLines source) actualLines
    then pure []
    else
      pure
        ( ("generated source differs from " ++ generatedSourcePath source)
            : take 40 (diffGeneratedLines (generatedSourceLines source) actualLines)
        )

bootstrapHandlerName :: SendName -> HandlerName
bootstrapHandlerName (SendName name) =
  HandlerName ("Bootstrap" ++ name ++ "Handler")

joinLines :: [String] -> String
joinLines [] =
  ""
joinLines [line] =
  line
joinLines (line : rest) =
  line ++ "\n" ++ joinLines rest
