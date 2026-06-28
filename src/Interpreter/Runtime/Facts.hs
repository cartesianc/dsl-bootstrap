module Interpreter.Runtime.Facts
  ( factExprAvailable
  , mergeRuntime
  , recordFact
  ) where

import AST.Vocabulary
  ( WorkflowFact
  )
import Core.Architecture
  ( Fact (..)
  , FactExpr (..)
  , Requirement (..)
  )
import Core.Architecture.Internal
  ( RequirementEffect (..)
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  )
import Interpreter.Runtime.Trace
  ( renderFactExpr
  , runtimeSleep
  , traceRuntime
  )

recordFact :: Fact WorkflowFact -> Runtime -> IO Runtime
recordFact currentFact runtime = do
  traceRuntime ("fact " ++ renderFactExpr (factExpression currentFact))
  runtimeSleep
  pure runtime {availableFacts = mergeFacts (availableFacts runtime) (collectFactExpr (factExpression currentFact))}

factExprAvailable :: Runtime -> FactExpr WorkflowFact -> Bool
factExprAvailable runtime (FactItems currentFacts) =
  all (`elem` availableFacts runtime) (collectFacts currentFacts)
factExprAvailable runtime (FactAll currentFacts) =
  all (factExprAvailable runtime) currentFacts
factExprAvailable runtime (FactAny currentFacts) =
  any (factExprAvailable runtime) currentFacts

mergeRuntime :: Runtime -> Runtime -> Runtime
mergeRuntime left right =
  left {availableFacts = mergeFacts (availableFacts left) (availableFacts right)}

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

mergeFacts :: [WorkflowFact] -> [WorkflowFact] -> [WorkflowFact]
mergeFacts =
  foldl addFact
  where
    addFact facts currentFact
      | currentFact `elem` facts = facts
      | otherwise = currentFact : facts
