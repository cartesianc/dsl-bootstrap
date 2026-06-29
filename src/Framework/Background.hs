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
  , ModulePattern (..)
  , RuleId (..)
  , SmtBackend (..)
  , SmtEvidence (..)
  , SmtProposition (..)
  , SmtResult (..)
  , SmtStatus (..)
  , WorkflowScope (..)
  , checkConstraintFacts
  , checkFrontendBoundary
  , checkFrontendBoundaryWith
  , checkFrontendImports
  , checkFrontendImportsWithRules
  , constraintsFromAppPlan
  , defaultFrontendBoundaryPolicy
  , defaultFrontendBoundaryRules
  , extractFrontendImports
  , frontendBoundaryPolicyRules
  , defaultSmtPropositions
  , matchesModulePattern
  , proveMinimalCore
  , proveMinimalCoreWith
  , renderConstraintError
  , renderConstraintFacts
  , renderFrontendBoundaryError
  , renderFrontendImport
  , renderSmtEvidence
  , renderSmtResult
  , renderSmtResults
  , smtPassed
  , EffectSemantics (..)
  , FactContract (..)
  , FactSource (..)
  , HandlerContract (..)
  , ProducerRequirement (..)
  , ProfileContract (..)
  , SendContract (..)
  , SendUse (..)
  , TakeMakeRule (..)
  , TakeMakeSource (..)
  , effectSemantics
  , factContractFor
  , handlerContractFor
  , handlerContractsFor
  , profileContractFor
  , sendContractFor
  , takeMakeRuleFor
  , takeMakeRulesFor
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
  , HandlerRegistry (..)
  , HandlerResult (..)
  , RuntimeHandler (..)
  , RuntimeEnv (..)
  , RuntimeError (..)
  , RuntimeEffectEnvironment (..)
  , RuntimeM (..)
  , RuntimeResult (..)
  , RuntimeState
  , WorkflowProgram (..)
  , askRuntimeEnv
  , contextware
  , contextwareWithEffectEnvironment
  , defaultHandlerRegistry
  , defaultRuntimeEnv
  , defaultRuntimeEffectEnvironment
  , emptyHandlerRegistry
  , getRuntimeState
  , handlerFor
  , interpretHangingProgram
  , interpretWorkflowProgram
  , liftRuntimeIO
  , lowerHanging
  , lowerWorkflow
  , modifyRuntimeState
  , putRuntimeState
  , renderRuntimeError
  , runRuntimeM
  , runRuntimeMOrThrow
  , runtimeEffectEnvironment
  , runtimeEnv
  , runHandler
  , throwRuntimeError
  , traceRuntimeM
  , withRuntimeMiddleware
  , withRuntimeEnv
  , Runtime (..)
  , runApp
  , runAppWith
  , runBlueprint
  , runBlueprintWith
  , runBlueprintWithAlgebra
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
import Core.Workflow.Eff
import Core.Workflow.Semantics
import Interpreter.Runtime.Contextware
import Interpreter.Runtime.Handlers
import Interpreter.Runtime.Middleware
import Interpreter.Runtime.Monad
import Interpreter.Runtime
import Interpreter.Runtime.Types
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , RuntimeEnv (..)
  , RuntimeError (..)
  , RuntimeEffectEnvironment (..)
  , RuntimeHandler (..)
  , RuntimeM (..)
  , RuntimeResult (..)
  , RuntimeState
  )
