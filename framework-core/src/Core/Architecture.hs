module Core.Architecture
  ( Chain (..)
  , Parallel (..)
  , Middleware (..)
  , Fallback (..)
  , Race (..)
  , Choice (..)
  , Callback (..)
  , Wait (..)
  , Suspense (..)
  , Loop (..)
  , FactExpr (..)
  , Hanging (..)
  , HangingAction (..)
  , ChoiceKey (..)
  , module AST.Names
  , Requirement (..)
  , Fact (..)
  , Workflow (..)
  , freeChain
  , freeParallel
  , freeFallback
  , freeRace
  , freeChoice
  , freeWait
  , freeHanging
  , freeRequirement
  , factItems
  , factAll
  , factAny
  , chain
  , parallel
  , middleware
  , fallback
  , race
  , choice
  , callback
  , wait
  , hanging
  , suspense
  , loop
  , fact
  ) where

import AST.Names
import Core.Architecture.Internal
  ( FreeAlternative
  , FreeApplicative
  , FreeChoice
  , FreeMonad
  , FreeMonoid
  , RequirementEffect
  )
import qualified Core.Architecture.Internal as Internal

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

data FactExpr fact
  = FactItems (Requirement fact)
  | FactAll [FactExpr fact]
  | FactAny [FactExpr fact]

data Callback fact workflow = Callback
  { callbackTarget :: WorkflowName
  , callbackBody :: workflow
  }

newtype Wait fact = Wait
  { waitFacts :: FactExpr fact
  }

data Suspense fact workflow = Suspense
  { suspenseTarget :: WorkflowName
  }

newtype Loop workflow = Loop
  { loopBody :: workflow
  }

newtype Hanging action = Hanging
  { hangingActions :: FreeMonoid action
  }

data HangingAction fact hook workflow
  = HangingCallback (Callback fact workflow)
  | HangingSuspense (Suspense fact workflow)
  | HangingLoop (Loop workflow)
  | HangingMiddleware (Middleware hook) workflow

newtype ChoiceKey = ChoiceKey String
  deriving (Eq)

newtype Requirement fact = Requirement
  { requirementFacts :: RequirementEffect fact ()
  }

newtype Fact fact = Fact
  { factExpression :: FactExpr fact
  }

data Workflow fact hook
  = FactWorkflow (Fact fact)
  | ChainWorkflow WorkflowName (Chain (Workflow fact hook))
  | ParallelWorkflow WorkflowName (Parallel (Workflow fact hook))
  | FallbackWorkflow (Fallback (Workflow fact hook))
  | RaceWorkflow (Race (Workflow fact hook))
  | ChoiceWorkflow ChoiceKey (Choice (Workflow fact hook))
  | WaitWorkflow (Wait fact) (Workflow fact hook)

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

freeWait :: FactExpr fact -> Wait fact
freeWait =
  Wait

freeHanging :: [action] -> Hanging action
freeHanging =
  Hanging . Internal.freeMonoid

freeRequirement :: [requirement] -> Requirement requirement
freeRequirement =
  Requirement . Internal.requirementEffect

factItems :: [fact] -> FactExpr fact
factItems =
  FactItems . freeRequirement

factAll :: [FactExpr fact] -> FactExpr fact
factAll =
  FactAll

factAny :: [FactExpr fact] -> FactExpr fact
factAny =
  FactAny

factComponent :: FactExpr fact -> Fact fact
factComponent =
  Fact

fact :: FactExpr fact -> Workflow fact hook
fact =
  FactWorkflow . factComponent

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

wait :: FactExpr fact -> Workflow fact hook -> Workflow fact hook
wait currentFacts =
  WaitWorkflow (freeWait currentFacts)

hanging :: [HangingAction fact hook workflow] -> Hanging (HangingAction fact hook workflow)
hanging =
  freeHanging

callback ::
  WorkflowName ->
  workflow ->
  HangingAction fact hook workflow
callback currentTarget body =
  HangingCallback (Callback currentTarget body)

suspense ::
  WorkflowName ->
  HangingAction fact hook workflow
suspense currentTarget =
  HangingSuspense (Suspense currentTarget)

loop ::
  workflow ->
  HangingAction fact hook workflow
loop body =
  HangingLoop (Loop body)

middleware ::
  hook ->
  workflow ->
  HangingAction fact hook workflow
middleware currentMiddleware body =
  HangingMiddleware (Middleware currentMiddleware) body
