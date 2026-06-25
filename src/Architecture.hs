module Architecture
  ( Chain (..)
  , Parallel (..)
  , Middleware (..)
  , Fallback (..)
  , Race (..)
  , Choice (..)
  , Callback (..)
  , ChoiceKey (..)
  , module AST.Names
  , Requirement (..)
  , Effect (..)
  , Workflow (..)
  , freeChain
  , freeParallel
  , freeFallback
  , freeRace
  , freeChoice
  , freeCallback
  , freeRequirement
  , chain
  , parallel
  , middleware
  , fallback
  , race
  , choice
  , callback
  , effect
  ) where

import Architecture.Internal
  ( FreeAlternative
  , FreeApplicative
  , FreeChoice
  , FreeMonad
  , RequirementEffect
  )
import qualified Architecture.Internal as Internal
import AST.Names

newtype Chain step = Chain
  { chainSteps :: FreeMonad step
  }

newtype Parallel branch = Parallel
  { parallelBranches :: FreeApplicative branch
  }

newtype Middleware hook = Middleware
  { middlewareHook :: hook
  }

newtype Fallback branch = Fallback
  { fallbackBranches :: FreeAlternative branch
  }

newtype Race branch = Race
  { raceBranches :: FreeAlternative branch
  }

newtype Choice branch = Choice
  { choiceBranches :: FreeChoice ChoiceKey branch
  }

newtype Callback fact = Callback
  { callbackFacts :: Requirement fact
  }

newtype ChoiceKey = ChoiceKey String
  deriving (Eq)

newtype Requirement fact = Requirement
  { requirementFacts :: RequirementEffect fact ()
  }

newtype Effect fact = Effect
  { effectFacts :: Requirement fact
  }

data Workflow fact hook
  = EffectWorkflow (Effect fact)
  | ChainWorkflow WorkflowName (Chain (Workflow fact hook))
  | ParallelWorkflow WorkflowName (Parallel (Workflow fact hook))
  | FallbackWorkflow (Fallback (Workflow fact hook))
  | RaceWorkflow (Race (Workflow fact hook))
  | ChoiceWorkflow ChoiceKey (Choice (Workflow fact hook))
  | CallbackWorkflow (Callback fact) (Workflow fact hook)
  | MiddlewareWorkflow (Middleware hook) (Workflow fact hook)

freeChain :: [step] -> Chain step
freeChain =
  Chain . Internal.freeMonad

freeParallel :: [branch] -> Parallel branch
freeParallel =
  Parallel . Internal.freeApplicative

freeFallback :: [branch] -> Fallback branch
freeFallback =
  Fallback . Internal.freeAlternative

freeRace :: [branch] -> Race branch
freeRace =
  Race . Internal.freeAlternative

freeChoice :: [(ChoiceKey, branch)] -> Choice branch
freeChoice =
  Choice . Internal.freeChoice

freeCallback :: [fact] -> Callback fact
freeCallback =
  Callback . freeRequirement

freeRequirement :: [requirement] -> Requirement requirement
freeRequirement =
  Requirement . Internal.requirementEffect

effectComponent :: [fact] -> Effect fact
effectComponent factItems =
  Effect
    { effectFacts = freeRequirement factItems
    }

effect :: [fact] -> Workflow fact hook
effect =
  EffectWorkflow . effectComponent

chain :: WorkflowName -> [Workflow fact hook] -> Workflow fact hook
chain name =
  ChainWorkflow name . freeChain

parallel :: WorkflowName -> [Workflow fact hook] -> Workflow fact hook
parallel name =
  ParallelWorkflow name . freeParallel

fallback :: [Workflow fact hook] -> Workflow fact hook
fallback =
  FallbackWorkflow . freeFallback

race :: [Workflow fact hook] -> Workflow fact hook
race =
  RaceWorkflow . freeRace

choice ::
  ChoiceKey ->
  [(ChoiceKey, Workflow fact hook)] ->
  Workflow fact hook
choice selectedKey =
  ChoiceWorkflow selectedKey . freeChoice

callback :: [fact] -> Workflow fact hook -> Workflow fact hook
callback factItems =
  CallbackWorkflow (freeCallback factItems)

middleware :: hook -> Workflow fact hook -> Workflow fact hook
middleware currentMiddleware =
  MiddlewareWorkflow (Middleware currentMiddleware)
