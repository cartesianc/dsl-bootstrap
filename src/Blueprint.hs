module Blueprint
  ( Chain
  , Parallel
  , Middleware
  , Effect
  , Callback
  , Fallback
  , Race
  , Choice
  , chain
  , parallel
  , middleware
  , effect
  , callback
  , fallback
  , race
  , choice
  , ChoiceKey (..)
  , module AST.Vocabulary
  ) where

import Architecture
  ( ChoiceKey (..)
  , Workflow
  )
import qualified Architecture
import AST.Vocabulary

type Component = Workflow WorkflowFact Interceptor

type Chain = Component

type Parallel = Component

type Middleware = Component

type Effect = Component

type Callback = Component

type Fallback = Component

type Race = Component

type Choice = Component

chain :: WorkflowName -> [Component] -> Chain
chain =
  Architecture.chain

parallel :: WorkflowName -> [Component] -> Parallel
parallel =
  Architecture.parallel

middleware :: Interceptor -> Component -> Middleware
middleware =
  Architecture.middleware

effect :: [WorkflowFact] -> Effect
effect =
  Architecture.effect

callback :: [WorkflowFact] -> Component -> Callback
callback =
  Architecture.callback

fallback :: [Component] -> Fallback
fallback =
  Architecture.fallback

race :: [Component] -> Race
race =
  Architecture.race

choice :: ChoiceKey -> [(ChoiceKey, Component)] -> Choice
choice =
  Architecture.choice
