module Framework.Background
  ( AppError
  , AppPlan (..)
  , BootstrapPhase (..)
  , CoreBoundary (..)
  , CoreBoundaryError (..)
  , CoreSlice (..)
  , CoreSliceName (..)
  , CoreSliceRole (..)
  , MinimalCoreReport (..)
  , MinimalCoreStatus (..)
  , buildApp
  , buildMinimalCoreReport
  , app
  , checkMinimalCore
  , checkMinimalCoreModel
  , checkCoreBoundary
  , checkCoreBoundaryWithImportGraph
  , coreBoundaryPassed
  , coreSlicesForPhase
  , minimalCorePassed
  , minimalCoreStatus
  , defaultCoreBoundary
  , renderBootstrapPhase
  , renderCoreBoundary
  , renderCoreBoundaryError
  , renderCoreSlice
  , renderCoreSliceName
  , renderCoreSliceRole
  , renderMinimalCoreReport
  , renderAppError
  , cata
  , prepro
  , gprepro
  , gpreproHanging
  , gpreproWorkflow
  , ConstraintError (..)
  , ConstraintFact (..)
  , FrontendBoundaryError (..)
  , FrontendBoundaryPolicy (..)
  , FrontendBoundaryRules (..)
  , FrontendImport (..)
  , ImportGraph (..)
  , ImportModule (..)
  , ImportPackage (..)
  , ModuleImport (..)
  , ModulePattern (..)
  , PackageImportError (..)
  , PackageImportPolicy (..)
  , RuleId (..)
  , SmtBackend (..)
  , SmtEvidence (..)
  , SmtProposition (..)
  , SmtResult (..)
  , SmtSolver (..)
  , SmtStatus (..)
  , WorkflowScope (..)
  , ArgumentCardinality (..)
  , ArgumentSpec (..)
  , ElaborationConstraintFact (..)
  , ElaborationContract (..)
  , ElaborationError (..)
  , ElaboratorBinding (..)
  , ElaboratorImplementation (..)
  , KeywordName (..)
  , KeywordSpec (..)
  , LanguageConstraintError (..)
  , LanguageConstraintFact (..)
  , LanguageError (..)
  , LanguageSpec (..)
  , LoweringTarget (..)
  , SyntaxKind (..)
  , checkConstraintFacts
  , checkDefaultElaborationContract
  , checkDefaultLanguageConstraints
  , checkDefaultLanguageSpec
  , checkElaborationContract
  , checkFrontendBoundary
  , checkFrontendBoundaryWith
  , checkFrontendImports
  , checkFrontendImportsWithRules
  , checkDefaultPackageImportGraph
  , checkLanguageConstraints
  , checkLanguageSpec
  , checkPackageImportGraph
  , constraintsFromAppPlan
  , defaultFrontendBoundaryPolicy
  , defaultFrontendBoundaryRules
  , defaultPackageImportPolicy
  , defaultElaborationConstraints
  , defaultElaborationContract
  , defaultLanguageConstraints
  , defaultLanguageSpec
  , elaborationConstraintsFromSpec
  , elaborationContractValid
  , elaborator
  , extractFrontendImports
  , extractImportGraph
  , frontendBoundaryPolicyRules
  , defaultSmtPropositions
  , availableSmtSolver
  , cvc5Solver
  , keyword
  , keywordNameText
  , languageConstraintsFromSpec
  , languageSpecValid
  , matchesModulePattern
  , many
  , optional
  , proveMinimalCore
  , proveMinimalCoreWith
  , proveMinimalCoreWithAvailableSolver
  , proveMinimalCoreWithSolver
  , renderElaborationConstraintFact
  , renderElaborationConstraintFacts
  , renderElaborationError
  , renderLanguageConstraintError
  , renderLanguageConstraintFact
  , renderLanguageConstraintFacts
  , renderLanguageError
  , renderConstraintError
  , renderConstraintFacts
  , renderFrontendBoundaryError
  , renderFrontendImport
  , readPackageImportGraph
  , renderModuleImport
  , renderPackageImportError
  , renderSmtEvidence
  , renderSmtResult
  , renderSmtResults
  , renderSmtSolver
  , required
  , smtPassed
  , smtLibForProposition
  , z3Solver
  , BoundarySource (..)
  , EffectBoundary (..)
  , EffectSemantics (..)
  , FactContract (..)
  , FactSource (..)
  , IdempotencyPolicy (..)
  , PipeTake (..)
  , ProducerRequirement (..)
  , RetryPolicy (..)
  , SendContract (..)
  , SendUse (..)
  , TakeMakeRule (..)
  , TakeMakeSource (..)
  , TransformContract (..)
  , TransformUse (..)
  , effectSemantics
  , effectBoundariesForFact
  , factContractFor
  , sendContractFor
  , takeMakeRuleFor
  , takeMakeRulesFor
  , transformContractFor
  , WorkflowEff (..)
  , WorkflowEffAlgebra (..)
  , WorkflowOp (..)
  , appendWorkflowEff
  , compileHangingEff
  , compileWorkflowEff
  , interpretHangingEff
  , interpretWorkflowEff
  , HangingProgram (..)
  , HangingProgramAction (..)
  , HandlerBinding (..)
  , HandlerInput (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , ErrorInputValue (..)
  , NoInputValue (..)
  , RuntimeHandler (..)
  , RuntimeCallback (..)
  , RuntimeCallbackEvent (..)
  , RuntimeComponentEvent (..)
  , RuntimeComponentStatus (..)
  , RuntimeEnv (..)
  , RuntimeError (..)
  , RuntimeEffectEnvironment (..)
  , RuntimeFactClaim (..)
  , RuntimeFactFailure (..)
  , RuntimeFactStatus (..)
  , RuntimeFailureDiagnosis (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisNodeKind (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeDiagnosisBlocker (..)
  , RuntimeM (..)
  , RuntimeMiddlewareEvent (..)
  , RuntimeSuspenseEvent (..)
  , RuntimeResult (..)
  , RuntimeState
  , RuntimeTypedValue (..)
  , RuntimeTransform (..)
  , RuntimeValue (..)
  , SomeRuntimeValue (..)
  , TransformBinding (..)
  , TransformRegistry (..)
  , UnitValue (..)
  , ValueTag (..)
  , WorkflowProgram (..)
  , applyRuntimeTransform
  , askRuntimeEnv
  , contextware
  , contextwareWithEffectEnvironment
  , defaultHandlerRegistry
  , defaultRuntimeEnv
  , defaultRuntimeEffectEnvironment
  , defaultTransformRegistry
  , emptyRuntime
  , emptyHandlerRegistry
  , emptyTransformRegistry
  , getRuntimeState
  , handlerFor
  , handlerInputFromTypedValues
  , handlerInputFromValues
  , interpretHangingProgram
  , interpretWorkflowProgram
  , liftRuntimeIO
  , lowerHanging
  , lowerWorkflow
  , modifyRuntimeState
  , putRuntimeState
  , renderRuntimeError
  , runHanging
  , runRuntimeM
  , runRuntimeMOrThrow
  , runtimeAlgebra
  , runtimeEffectEnvironment
  , runtimeEffectEnvironmentWithTransforms
  , runtimeEnv
  , runtimeTypedValueText
  , runtimeTypedValueToRuntimeValue
  , runtimeTypedValueType
  , runtimeTransformInput
  , runtimeTransformOutput
  , runHandler
  , runtimeValueToSome
  , sameValueTag
  , throwRuntimeError
  , traceRuntimeM
  , someRuntimeValueText
  , someRuntimeValueToRuntimeValue
  , someRuntimeValueType
  , typedValueFor
  , typedValueFromSome
  , transformFor
  , buildFailureDiagnosis
  , completeDiagnosisProbe
  , diagnosisProbePairs
  , recordRuntimeDiagnosis
  , renderRuntimeFailureDiagnosis
  , valueTagTypeName
  , withRuntimeMiddleware
  , withRuntimeEnv
  , withRuntimeCallbacks
  , Runtime (..)
  , runApp
  , runAppWith
  , runBlueprint
  , runBlueprintWith
  , runBlueprintWithAlgebra
  , runBlueprintWithEffectEnvironment
  , runBlueprintWithEffects
  ) where

import Core.App
import Core.App.Boundary
import Core.Architecture.Recursion
import Core.Bootstrap
import Core.Boundary.Frontend
import Core.Effect.Constraint
import Core.Effect.Constraint.SMT
import Core.Effect.Semantics
import Core.ImportGraph
import Core.Language.Constraint
import Core.Language.Elaboration
import Core.Language.Spec
import Core.Language.Validation
import Core.Workflow.Eff
import Core.Workflow.Semantics
import Interpreter.Runtime.Algebra
  ( runtimeAlgebra
  )
import Interpreter.Runtime.Contextware
import Interpreter.Runtime.Diagnosis
import Interpreter.Runtime.Handlers
import Interpreter.Runtime.Hanging.FreeMonoid
  ( runHanging
  )
import Interpreter.Runtime.Middleware
import Interpreter.Runtime.Monad
import Interpreter.Runtime
import Interpreter.Runtime.Types
  ( HandlerBinding (..)
  , HandlerInput (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , ErrorInputValue (..)
  , NoInputValue (..)
  , RuntimeEnv (..)
  , RuntimeError (..)
  , RuntimeEffectEnvironment (..)
  , RuntimeFactClaim (..)
  , RuntimeFactFailure (..)
  , RuntimeFactStatus (..)
  , RuntimeFailureDiagnosis (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisNodeKind (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeDiagnosisBlocker (..)
  , RuntimeHandler (..)
  , RuntimeCallback (..)
  , RuntimeCallbackEvent (..)
  , RuntimeComponentEvent (..)
  , RuntimeComponentStatus (..)
  , RuntimeM (..)
  , RuntimeMiddlewareEvent (..)
  , RuntimeResult (..)
  , RuntimeSuspenseEvent (..)
  , RuntimeState
  , RuntimeTypedValue (..)
  , RuntimeTransform (..)
  , RuntimeValue (..)
  , SomeRuntimeValue (..)
  , TransformBinding (..)
  , TransformRegistry (..)
  , UnitValue (..)
  , ValueTag (..)
  , emptyRuntime
  , applyRuntimeTransform
  , handlerInputFromTypedValues
  , handlerInputFromValues
  , runtimeTypedValueText
  , runtimeTypedValueToRuntimeValue
  , runtimeTypedValueType
  , runtimeTransformInput
  , runtimeTransformOutput
  , runtimeValueToSome
  , sameValueTag
  , someRuntimeValueText
  , someRuntimeValueToRuntimeValue
  , someRuntimeValueType
  , typedValueFor
  , typedValueFromSome
  , valueTagTypeName
  )
