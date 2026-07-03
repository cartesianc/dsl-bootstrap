{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeSynonymInstances #-}

module Blueprint
  ( WorkflowComponent
  , EffectSystemComponent
  , FactComponent
  , HangingComponent
  , Chain
  , Parallel
  , Middleware
  , Wait
  , Fallback
  , Race
  , Choice
  , Hanging
  , FactDsl (facts)
  , effectSystem
  , run
  , chain
  , parallel
  , middleware
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
  , EffectSystemName (..)
  , Interceptor (..)
  , LogEvent (..)
  , WorkflowFact (..)
  ) where

import Framework.Workflow
  ( ChoiceKey (..)
  , EffectSystem
  , EffectSystemName (..)
  , Interceptor (..)
  , LogEvent (..)
  , Workflow
  , WorkflowFact (..)
  )
import qualified Framework.Workflow as Architecture

type WorkflowComponent = Workflow WorkflowFact Interceptor

type EffectSystemComponent = EffectSystem WorkflowFact

type FactComponent = Architecture.FactExpr WorkflowFact

type HangingComponent = Architecture.HangingAction WorkflowFact Interceptor WorkflowComponent

type Chain = WorkflowComponent

type Parallel = WorkflowComponent

type Middleware = HangingComponent

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

effectSystem :: FactDsl currentFacts => EffectSystemName -> currentFacts -> EffectSystemComponent
effectSystem name =
  Architecture.effectSystem name . facts

run :: EffectSystemComponent -> WorkflowComponent
run =
  Architecture.run

chain :: [WorkflowComponent] -> Chain
chain =
  Architecture.chain

parallel :: [WorkflowComponent] -> Parallel
parallel =
  Architecture.parallel

middleware :: Interceptor -> WorkflowComponent -> Middleware
middleware =
  Architecture.middleware

wait :: FactDsl currentFacts => currentFacts -> WorkflowComponent -> Wait
wait currentFacts =
  Architecture.wait (facts currentFacts)

callback :: EffectSystemName -> WorkflowComponent -> HangingComponent
callback =
  Architecture.callback

suspense :: EffectSystemName -> HangingComponent
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
