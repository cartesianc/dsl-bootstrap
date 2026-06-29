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
import Interpreter.Runtime.Monad
  ( modifyRuntimeState
  , runtimeSleepM
  , traceRuntimeM
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , WorkflowProgram
  )
import Interpreter.Runtime.Trace
  ( renderFactExpr
  )

recordFact :: Fact WorkflowFact -> WorkflowProgram
recordFact currentFact = do
  traceRuntimeM ("fact " ++ renderFactExpr (factExpression currentFact))
  runtimeSleepM
  modifyRuntimeState
    ( \runtime ->
        runtime
          { availableFacts =
              mergeFacts (availableFacts runtime) (collectFactExpr (factExpression currentFact))
          }
    )

factExprAvailable :: Runtime -> FactExpr WorkflowFact -> Bool
factExprAvailable runtime (FactItems currentFacts) =
  all (`elem` availableFacts runtime) (collectFacts currentFacts)
factExprAvailable runtime (FactAll currentFacts) =
  all (factExprAvailable runtime) currentFacts
factExprAvailable runtime (FactAny currentFacts) =
  any (factExprAvailable runtime) currentFacts

mergeRuntime :: Runtime -> Runtime -> Runtime
mergeRuntime left right =
  left
    { availableFacts = mergeFacts (availableFacts left) (availableFacts right)
    , runtimeTrace = runtimeTrace left <> runtimeTrace right
    , runtimeMiddlewareEvents = runtimeMiddlewareEvents left <> runtimeMiddlewareEvents right
    }

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
