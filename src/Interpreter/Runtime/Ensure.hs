module Interpreter.Runtime.Ensure
  ( ensureFact
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Architecture
  ( Fact (..)
  , FactExpr (..)
  , Requirement (..)
  , factItems
  )
import Core.Architecture.Internal
  ( RequirementEffect (..)
  )
import Core.Effect.Semantics
  ( HandlerContract (..)
  , TakeMakeRule (..)
  , TakeMakeSource (..)
  , handlerContractFor
  , takeMakeRuleFor
  )
import Effects.EffectTheory
  ( ImplementationBinding (..)
  , SendName
  )
import Interpreter.Runtime.Handlers
  ( runHandler
  )
import Interpreter.Runtime.Monad
  ( askRuntimeEnv
  , getRuntimeState
  , liftRuntimeIO
  , runtimeSleepM
  , throwRuntimeError
  , traceRuntimeM
  )
import Interpreter.Runtime.Types
  ( HandlerResult (..)
  , Runtime (..)
  , RuntimeEnv (..)
  , RuntimeError (..)
  , RuntimeEffectEnvironment (..)
  , RuntimeM
  , WorkflowProgram
  )

ensureFact ::
  (Fact WorkflowFact -> WorkflowProgram) ->
  Fact WorkflowFact ->
  WorkflowProgram
ensureFact makeFact currentFact =
  ensureFacts makeFact [] (collectFactExpr (factExpression currentFact))

ensureFacts ::
  (Fact WorkflowFact -> WorkflowProgram) ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  WorkflowProgram
ensureFacts _ _ [] =
  pure ()
ensureFacts makeFact stack (currentFact : rest) = do
  ensureOneFact makeFact stack currentFact
  ensureFacts makeFact stack rest

ensureOneFact ::
  (Fact WorkflowFact -> WorkflowProgram) ->
  [WorkflowFact] ->
  WorkflowFact ->
  WorkflowProgram
ensureOneFact makeFact stack currentFact = do
  runtime <- getRuntimeState
  environment <- askRuntimeEnv
  let semantics = runtimeEnvEffectSemantics environment
  if currentFact `elem` availableFacts runtime
    then pure ()
    else
      if currentFact `elem` stack
        then throwRuntimeError (RuntimeFactDependencyCycle currentFact)
        else
          case takeMakeRuleFor semantics currentFact of
            Nothing ->
              throwRuntimeError (RuntimeMissingFactRule currentFact)
            Just currentRule ->
              ensureByRule makeFact stack currentRule

ensureByRule ::
  (Fact WorkflowFact -> WorkflowProgram) ->
  [WorkflowFact] ->
  TakeMakeRule ->
  WorkflowProgram
ensureByRule makeFact stack currentRule =
  case takeMakeSource currentRule of
    ExternalTake ->
      throwRuntimeError (RuntimeExternalTakeAutoMake (takeMakeRuleFact currentRule))
    InternalMake -> do
      traceRuntimeM ("ensure " ++ show (takeMakeRuleFact currentRule))
      ensureFacts makeFact (takeMakeRuleFact currentRule : stack) (takeFacts currentRule)
      externalMakeResult <- runExternalMakes (externalMakeNames currentRule)
      case externalMakeResult of
        ExternalMakesSucceeded ->
          makeFact (Fact (factItems (makeFacts currentRule)))
        ExternalMakeFailed currentExternalMake errorReport ->
          handleExternalMakeFailure makeFact currentRule currentExternalMake errorReport

data ExternalMakeResult
  = ExternalMakesSucceeded
  | ExternalMakeFailed SendName RuntimeError

handleExternalMakeFailure ::
  (Fact WorkflowFact -> WorkflowProgram) ->
  TakeMakeRule ->
  SendName ->
  RuntimeError ->
  WorkflowProgram
handleExternalMakeFailure makeFact currentRule currentExternalMake errorReport
  | null (failureMakeFacts currentRule) =
      throwRuntimeError errorReport
  | otherwise = do
      traceRuntimeM
        ( "externalMake "
            ++ show currentExternalMake
            ++ " failed, make failure facts "
            ++ show (failureMakeFacts currentRule)
        )
      makeFact (Fact (factItems (failureMakeFacts currentRule)))

runExternalMakes ::
  [SendName] ->
  RuntimeM ExternalMakeResult
runExternalMakes [] =
  pure ExternalMakesSucceeded
runExternalMakes (currentExternalMake : rest) = do
  environment <- askRuntimeEnv
  runtime <- getRuntimeState
  let effectEnvironment = runtimeEnvEffectEnvironment environment
  let semantics = runtimeEnvEffectSemantics environment
  case handlerContractFor semantics (runtimeEffectProfile effectEnvironment) currentExternalMake of
    Nothing ->
      pure
        ( ExternalMakeFailed
            currentExternalMake
            (RuntimeMissingImplementation (runtimeEffectProfile effectEnvironment) currentExternalMake)
        )
    Just currentContract -> do
      let currentImplementation =
            implementationName (handlerContractImplementation currentContract)
      traceRuntimeM
        ( "externalMake "
            ++ show currentExternalMake
            ++ " using "
            ++ show currentImplementation
        )
      runtimeSleepM
      handlerResult <- liftRuntimeIO $
        runHandler
          (runtimeEffectHandlers effectEnvironment)
          currentImplementation
          currentExternalMake
          runtime
      case handlerResult of
        HandlerSucceeded ->
          runExternalMakes rest
        HandlerFailed message ->
          pure (ExternalMakeFailed currentExternalMake (RuntimeHandlerFailed currentExternalMake message))
collectFactExpr :: FactExpr WorkflowFact -> [WorkflowFact]
collectFactExpr (FactItems currentFacts) =
  collectFacts currentFacts
collectFactExpr (FactAll currentFacts) =
  concatMap collectFactExpr currentFacts
collectFactExpr (FactAny currentFacts) =
  concatMap collectFactExpr currentFacts

collectFacts :: Requirement WorkflowFact -> [WorkflowFact]
collectFacts =
  requirementEffectItems . requirementFacts
