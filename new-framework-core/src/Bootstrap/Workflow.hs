module Bootstrap.Workflow
  ( App
  , AppBlueprint (..)
  , AppHanging
  , Callback (..)
  , Chain (..)
  , Choice (..)
  , ChoiceKey (..)
  , Fact (..)
  , FactExpr (..)
  , Fallback (..)
  , Hanging (..)
  , HangingAction (..)
  , Interceptor (..)
  , LogEvent (..)
  , Loop (..)
  , Middleware (..)
  , Parallel (..)
  , Race (..)
  , Requirement (..)
  , Suspense (..)
  , Wait (..)
  , Workflow (..)
  , WorkflowFact (..)
  , WorkflowName (..)
  , callback
  , chain
  , chainItems
  , choice
  , choiceItems
  , fact
  , factAll
  , factAny
  , factItems
  , fallback
  , fallbackItems
  , freeChain
  , freeChoice
  , freeFallback
  , freeHanging
  , freeParallel
  , freeRace
  , freeRequirement
  , freeWait
  , hanging
  , hangingItems
  , loop
  , middleware
  , parallel
  , parallelItems
  , race
  , raceItems
  , requirementItems
  , suspense
  , wait
  ) where

newtype WorkflowFact = WorkflowFact
  { workflowFactText :: String
  }
  deriving (Eq)

instance Show WorkflowFact where
  show =
    workflowFactText

newtype WorkflowName = WorkflowName
  { workflowNameText :: String
  }
  deriving (Eq)

instance Show WorkflowName where
  show =
    workflowNameText

newtype Interceptor = Interceptor
  { interceptorText :: String
  }
  deriving (Eq)

instance Show Interceptor where
  show =
    interceptorText

newtype LogEvent = LogEvent
  { logEventText :: String
  }
  deriving (Eq)

instance Show LogEvent where
  show =
    logEventText

data AppBlueprint = AppBlueprint
  { blueprintApp :: App
  , blueprintHanging :: AppHanging
  }

type App = Workflow WorkflowFact Interceptor

type AppHanging = Hanging (HangingAction WorkflowFact Interceptor App)

newtype Chain step = Chain
  { chainSteps :: [step]
  }

newtype Parallel branch = Parallel
  { parallelBranches :: [branch]
  }

newtype Middleware hook = Middleware
  { middlewareHook :: hook
  }

newtype Fallback branch = Fallback
  { fallbackBranches :: [branch]
  }

newtype Race branch = Race
  { raceBranches :: [branch]
  }

newtype Choice branch = Choice
  { choiceBranches :: [(ChoiceKey, branch)]
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
  { hangingActions :: [action]
  }

data HangingAction fact hook workflow
  = HangingCallback (Callback fact workflow)
  | HangingSuspense (Suspense fact workflow)
  | HangingLoop (Loop workflow)
  | HangingMiddleware (Middleware hook) workflow

newtype ChoiceKey = ChoiceKey String
  deriving (Eq)

newtype Requirement fact = Requirement
  { requirementFacts :: [fact]
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
  Chain

freeParallel :: [branch] -> Parallel branch
freeParallel =
  Parallel

freeFallback :: [branch] -> Fallback branch
freeFallback =
  Fallback

freeRace :: [branch] -> Race branch
freeRace =
  Race

freeChoice :: [(ChoiceKey, branch)] -> Choice branch
freeChoice =
  Choice

freeWait :: FactExpr fact -> Wait fact
freeWait =
  Wait

freeHanging :: [action] -> Hanging action
freeHanging =
  Hanging

freeRequirement :: [requirement] -> Requirement requirement
freeRequirement =
  Requirement

chainItems :: Chain step -> [step]
chainItems =
  chainSteps

parallelItems :: Parallel branch -> [branch]
parallelItems =
  parallelBranches

fallbackItems :: Fallback branch -> [branch]
fallbackItems =
  fallbackBranches

raceItems :: Race branch -> [branch]
raceItems =
  raceBranches

choiceItems :: Choice branch -> [(ChoiceKey, branch)]
choiceItems =
  choiceBranches

hangingItems :: Hanging action -> [action]
hangingItems =
  hangingActions

requirementItems :: Requirement fact -> [fact]
requirementItems =
  requirementFacts

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

choice :: ChoiceKey -> [(ChoiceKey, Workflow fact hook)] -> Workflow fact hook
choice selectedKey =
  ChoiceWorkflow selectedKey . freeChoice

wait :: FactExpr fact -> Workflow fact hook -> Workflow fact hook
wait currentFacts =
  WaitWorkflow (freeWait currentFacts)

hanging :: [HangingAction fact hook workflow] -> Hanging (HangingAction fact hook workflow)
hanging =
  freeHanging

callback :: WorkflowName -> workflow -> HangingAction fact hook workflow
callback currentTarget body =
  HangingCallback (Callback currentTarget body)

suspense :: WorkflowName -> HangingAction fact hook workflow
suspense currentTarget =
  HangingSuspense (Suspense currentTarget)

loop :: workflow -> HangingAction fact hook workflow
loop body =
  HangingLoop (Loop body)

middleware :: hook -> workflow -> HangingAction fact hook workflow
middleware currentMiddleware body =
  HangingMiddleware (Middleware currentMiddleware) body
