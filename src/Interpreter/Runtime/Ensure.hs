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
  ( EffectSemantics
  , TakeMakeRule (..)
  , TakeMakeSource (..)
  , takeMakeRuleFor
  )
import Effects.EffectTheory
  ( SendName
  )
import Interpreter.Runtime.Trace
  ( runtimeSleep
  , traceRuntime
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , WorkflowProgram
  )

ensureFact ::
  EffectSemantics ->
  (Fact WorkflowFact -> WorkflowProgram) ->
  Fact WorkflowFact ->
  WorkflowProgram
ensureFact semantics makeFact currentFact =
  ensureFacts semantics makeFact [] (collectFactExpr (factExpression currentFact))

ensureFacts ::
  EffectSemantics ->
  (Fact WorkflowFact -> WorkflowProgram) ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  WorkflowProgram
ensureFacts _ _ _ [] runtime =
  pure runtime
ensureFacts semantics makeFact stack (currentFact : rest) runtime = do
  nextRuntime <- ensureOneFact semantics makeFact stack currentFact runtime
  ensureFacts semantics makeFact stack rest nextRuntime

ensureOneFact ::
  EffectSemantics ->
  (Fact WorkflowFact -> WorkflowProgram) ->
  [WorkflowFact] ->
  WorkflowFact ->
  WorkflowProgram
ensureOneFact semantics makeFact stack currentFact runtime
  | currentFact `elem` availableFacts runtime =
      pure runtime
  | currentFact `elem` stack =
      ioError (userError ("fact dependency cycle while ensuring " ++ show currentFact))
  | otherwise =
      case takeMakeRuleFor semantics currentFact of
        Nothing ->
          ioError (userError ("missing take/make rule for fact " ++ show currentFact))
        Just currentRule ->
          ensureByRule semantics makeFact stack currentRule runtime

ensureByRule ::
  EffectSemantics ->
  (Fact WorkflowFact -> WorkflowProgram) ->
  [WorkflowFact] ->
  TakeMakeRule ->
  WorkflowProgram
ensureByRule semantics makeFact stack currentRule runtime =
  case takeMakeSource currentRule of
    ExternalTake ->
      ioError (userError ("cannot auto-make externalTake fact " ++ show (takeMakeRuleFact currentRule)))
    InternalMake -> do
      traceRuntime ("ensure " ++ show (takeMakeRuleFact currentRule))
      runtimeAfterTakes <-
        ensureFacts semantics makeFact (takeMakeRuleFact currentRule : stack) (takeFacts currentRule) runtime
      runtimeAfterExternalMakes <- runExternalMakes (externalMakeNames currentRule) runtimeAfterTakes
      makeFact (Fact (factItems (makeFacts currentRule))) runtimeAfterExternalMakes

runExternalMakes :: [SendName] -> WorkflowProgram
runExternalMakes [] runtime =
  pure runtime
runExternalMakes (currentExternalMake : rest) runtime = do
  traceRuntime ("externalMake " ++ show currentExternalMake)
  runtimeSleep
  runExternalMakes rest runtime

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
