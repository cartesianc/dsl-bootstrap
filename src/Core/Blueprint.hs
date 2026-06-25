{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeSynonymInstances #-}

module Blueprint
  ( WorkflowComponent
  , FactComponent
  , HangingComponent
  , Chain
  , Parallel
  , Middleware
  , Fact
  , Wait
  , Fallback
  , Race
  , Choice
  , Hanging
  , FactDsl (facts)
  , chain
  , parallel
  , middleware
  , fact
  , wait
  , callback
  , suspense
  , allOf
  , anyOf
  , hanging
  , fallback
  , race
  , choice
  , ChoiceKey (..)
  , module AST.Vocabulary
  ) where

import AST.Vocabulary
import Core.Architecture
  ( ChoiceKey (..)
  , Workflow
  )
import qualified Core.Architecture as Architecture

type WorkflowComponent = Workflow WorkflowFact Interceptor

type FactComponent = Architecture.FactExpr WorkflowFact

type HangingComponent = Architecture.HangingAction WorkflowFact WorkflowComponent

type Chain = WorkflowComponent

type Parallel = WorkflowComponent

type Middleware = WorkflowComponent

type Fact = WorkflowComponent

type Wait = WorkflowComponent

type Fallback = WorkflowComponent

type Race = WorkflowComponent

type Choice = WorkflowComponent

type Hanging = Architecture.Hanging HangingComponent

class FactDsl input where
  facts :: input -> FactComponent

instance FactDsl WorkflowFact where
  facts currentFact =
    Architecture.factItems [currentFact]

instance FactDsl [WorkflowFact] where
  facts =
    Architecture.factItems

instance FactDsl FactComponent where
  facts =
    id

chain :: WorkflowName -> [WorkflowComponent] -> Chain
chain =
  Architecture.chain

parallel :: WorkflowName -> [WorkflowComponent] -> Parallel
parallel =
  Architecture.parallel

middleware :: Interceptor -> WorkflowComponent -> Middleware
middleware =
  Architecture.middleware

fact :: FactDsl currentFacts => currentFacts -> Fact
fact =
  Architecture.fact . facts

wait :: FactDsl currentFacts => currentFacts -> WorkflowComponent -> Wait
wait currentFacts =
  Architecture.wait (facts currentFacts)

callback :: FactDsl currentFacts => currentFacts -> WorkflowComponent -> HangingComponent
callback currentFacts =
  Architecture.callback (facts currentFacts)

suspense :: FactDsl currentFacts => currentFacts -> WorkflowComponent -> HangingComponent
suspense currentFacts =
  Architecture.suspense (facts currentFacts)

allOf :: FactDsl currentFact => [currentFact] -> FactComponent
allOf =
  Architecture.factAll . map facts

anyOf :: FactDsl currentFact => [currentFact] -> FactComponent
anyOf =
  Architecture.factAny . map facts

hanging :: [HangingComponent] -> Hanging
hanging =
  Architecture.hanging

fallback :: [WorkflowComponent] -> Fallback
fallback =
  Architecture.fallback

race :: [WorkflowComponent] -> Race
race =
  Architecture.race

choice :: ChoiceKey -> [(ChoiceKey, WorkflowComponent)] -> Choice
choice =
  Architecture.choice
