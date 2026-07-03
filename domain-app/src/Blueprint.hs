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
  , loop
  , allOf
  , anyOf
  , hanging
  , fallback
  , race
  , choice
  , ChoiceKey (..)
  , Interceptor (..)
  , LogEvent (..)
  , WorkflowFact (..)
  , WorkflowName (..)
  , module Domain.Vocabulary
  ) where

import Domain.Vocabulary
import Framework.Ast
  ( ChoiceKey (..)
  , Interceptor (..)
  , LogEvent (..)
  , Workflow
  , WorkflowFact (..)
  , WorkflowName (..)
  )
import qualified Framework.Ast as Architecture

type WorkflowComponent = Workflow WorkflowFact Interceptor

type FactComponent = Architecture.FactExpr WorkflowFact

type HangingComponent = Architecture.HangingAction WorkflowFact Interceptor WorkflowComponent

type Chain = WorkflowComponent

type Parallel = WorkflowComponent

type Middleware = HangingComponent

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

callback :: WorkflowName -> WorkflowComponent -> HangingComponent
callback =
  Architecture.callback

suspense :: WorkflowName -> HangingComponent
suspense =
  Architecture.suspense

loop :: WorkflowComponent -> HangingComponent
loop =
  Architecture.loop

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
