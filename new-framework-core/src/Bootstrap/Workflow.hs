module Bootstrap.Workflow
  ( App
  , AppBlueprint (..)
  , AppHanging
  , Callback (..)
  , Chain (..)
  , Choice (..)
  , ChoiceKey (..)
  , EffectSystem (..)
  , EffectSystemBoundaryArtifact (..)
  , EffectSystemBoundary (..)
  , EffectSystemBoundaryHandler (..)
  , EffectSystemBoundaryPipeline (..)
  , EffectSystemBoundaryPolicy (..)
  , EffectSystemBoundarySend (..)
  , EffectSystemBoundaryTransform (..)
  , EffectSystemName (..)
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
  , RecursionContext (..)
  , RecursionContextAlgebra (..)
  , RecursionContextName (..)
  , RecursionSchemeMode (..)
  , RecursionSchemeModel (..)
  , Requirement (..)
  , Suspense (..)
  , Wait (..)
  , Workflow (..)
  , WorkflowFact (..)
  , callback
  , boundaryArtifact
  , boundaryHandler
  , boundaryIdempotent
  , boundaryPipeline
  , boundaryRetryOnce
  , boundarySend
  , boundaryTransform
  , chain
  , chainItems
  , choice
  , choiceItems
  , anaMode
  , apoMode
  , cataMode
  , context
  , chronoMode
  , effectSystem
  , effectSystemFromBoundary
  , effectSystemRuntimeFacts
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
  , futuMode
  , generalizedMode
  , hanging
  , hangingItems
  , histoMode
  , hyloMode
  , loop
  , middleware
  , parallel
  , parallelItems
  , paraMode
  , preproMode
  , race
  , raceItems
  , recursionContext
  , recursionContextAlgebra
  , recursionModel
  , recursionMode
  , recursionModelHasMode
  , requirementItems
  , listenDuringRunMode
  , renderBeforeRunMode
  , run
  , suspense
  , systemBoundary
  , systemBoundaryWithContracts
  , systemBoundaryWithHandlers
  , systemBoundaryWithPipelines
  , systemBoundaryWithPolicies
  , withRecursionContext
  , wait
  , zygoMode
  ) where

newtype WorkflowFact = WorkflowFact
  { workflowFactText :: String
  }
  deriving (Eq)

instance Show WorkflowFact where
  show =
    workflowFactText

newtype EffectSystemName = EffectSystemName
  { effectSystemNameText :: String
  }
  deriving (Eq)

instance Show EffectSystemName where
  show =
    effectSystemNameText

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

newtype RecursionContextName = RecursionContextName
  { recursionContextNameText :: String
  }
  deriving (Eq)

instance Show RecursionContextName where
  show =
    recursionContextNameText

newtype RecursionSchemeMode = RecursionSchemeMode
  { recursionSchemeModeText :: String
  }
  deriving (Eq)

instance Show RecursionSchemeMode where
  show =
    recursionSchemeModeText

data RecursionContextAlgebra fact = RecursionContextAlgebra
  { recursionContextAlgebraName :: String
  , recursionContextAlgebraEffects :: [EffectSystem fact]
  }

data RecursionSchemeModel fact = RecursionSchemeModel
  { recursionSchemeModelName :: String
  , recursionSchemeModelModes :: [RecursionSchemeMode]
  , recursionSchemeModelAlgebra :: RecursionContextAlgebra fact
  }

data RecursionContext fact = RecursionContext
  { recursionContextName :: RecursionContextName
  , recursionContextModel :: RecursionSchemeModel fact
  }

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
  { callbackTarget :: EffectSystemName
  , callbackBody :: workflow
  }

newtype Wait fact = Wait
  { waitFacts :: FactExpr fact
  }

data Suspense fact workflow = Suspense
  { suspenseTarget :: EffectSystemName
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
  | HangingContext (RecursionContext fact) workflow

newtype ChoiceKey = ChoiceKey String
  deriving (Eq)

newtype Requirement fact = Requirement
  { requirementFacts :: [fact]
  }

data EffectSystem fact = EffectSystem
  { effectSystemName :: EffectSystemName
  , effectSystemSuccess :: FactExpr fact
  , effectSystemBoundary :: EffectSystemBoundary fact
  , effectSystemBoundaryExplicit :: Bool
  }

data EffectSystemBoundary fact = EffectSystemBoundary
  { effectSystemBoundaryName :: EffectSystemName
  , effectSystemBoundaryImports :: [fact]
  , effectSystemBoundaryPrivateFacts :: [fact]
  , effectSystemBoundaryExports :: [fact]
  , effectSystemBoundarySends :: [EffectSystemBoundarySend]
  , effectSystemBoundaryTransforms :: [EffectSystemBoundaryTransform]
  , effectSystemBoundaryPolicies :: [EffectSystemBoundaryPolicy]
  , effectSystemBoundaryPipelines :: [EffectSystemBoundaryPipeline]
  , effectSystemBoundaryHandlers :: [EffectSystemBoundaryHandler]
  }

data EffectSystemBoundaryHandler = EffectSystemBoundaryHandler
  { effectSystemBoundaryHandlerSend :: EffectSystemBoundarySend
  , effectSystemBoundaryHandlerName :: String
  }
  deriving (Eq, Show)

data EffectSystemBoundaryPipeline = EffectSystemBoundaryPipeline
  { effectSystemBoundaryPipelineName :: String
  , effectSystemBoundaryPipelineArtifacts :: [EffectSystemBoundaryArtifact]
  }
  deriving (Eq, Show)

newtype EffectSystemBoundaryArtifact = EffectSystemBoundaryArtifact
  { effectSystemBoundaryArtifactText :: String
  }
  deriving (Eq)

instance Show EffectSystemBoundaryArtifact where
  show =
    effectSystemBoundaryArtifactText

data EffectSystemBoundaryPolicy
  = EffectSystemBoundaryIdempotent EffectSystemBoundarySend
  | EffectSystemBoundaryRetryOnce EffectSystemBoundarySend
  deriving (Eq)

instance Show EffectSystemBoundaryPolicy where
  show policy =
    case policy of
      EffectSystemBoundaryIdempotent currentSend ->
        "idempotent " ++ show currentSend
      EffectSystemBoundaryRetryOnce currentSend ->
        "retry-once " ++ show currentSend

newtype EffectSystemBoundarySend = EffectSystemBoundarySend
  { effectSystemBoundarySendText :: String
  }
  deriving (Eq)

instance Show EffectSystemBoundarySend where
  show =
    effectSystemBoundarySendText

newtype EffectSystemBoundaryTransform = EffectSystemBoundaryTransform
  { effectSystemBoundaryTransformText :: String
  }
  deriving (Eq)

instance Show EffectSystemBoundaryTransform where
  show =
    effectSystemBoundaryTransformText

data Workflow fact hook
  = RunWorkflow (EffectSystem fact)
  | ChainWorkflow (Chain (Workflow fact hook))
  | ParallelWorkflow (Parallel (Workflow fact hook))
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

effectSystem :: EffectSystemName -> FactExpr fact -> EffectSystem fact
effectSystem name successFacts =
  EffectSystem
    { effectSystemName = name
    , effectSystemSuccess = successFacts
    , effectSystemBoundary =
        EffectSystemBoundary
          { effectSystemBoundaryName = name
          , effectSystemBoundaryImports = []
          , effectSystemBoundaryPrivateFacts = []
          , effectSystemBoundaryExports = factExprFacts successFacts
          , effectSystemBoundarySends = []
          , effectSystemBoundaryTransforms = []
          , effectSystemBoundaryPolicies = []
          , effectSystemBoundaryPipelines = []
          , effectSystemBoundaryHandlers = []
          }
    , effectSystemBoundaryExplicit = False
    }

systemBoundary :: EffectSystemName -> [fact] -> [fact] -> [fact] -> EffectSystemBoundary fact
systemBoundary name imports privateFacts exports =
  systemBoundaryWithContracts name imports privateFacts exports [] []

systemBoundaryWithContracts ::
  EffectSystemName ->
  [fact] ->
  [fact] ->
  [fact] ->
  [EffectSystemBoundarySend] ->
  [EffectSystemBoundaryTransform] ->
  EffectSystemBoundary fact
systemBoundaryWithContracts name imports privateFacts exports sends transforms =
  systemBoundaryWithPolicies name imports privateFacts exports sends transforms []

systemBoundaryWithPolicies ::
  EffectSystemName ->
  [fact] ->
  [fact] ->
  [fact] ->
  [EffectSystemBoundarySend] ->
  [EffectSystemBoundaryTransform] ->
  [EffectSystemBoundaryPolicy] ->
  EffectSystemBoundary fact
systemBoundaryWithPolicies name imports privateFacts exports sends transforms policies =
  systemBoundaryWithPipelines name imports privateFacts exports sends transforms policies []

systemBoundaryWithPipelines ::
  EffectSystemName ->
  [fact] ->
  [fact] ->
  [fact] ->
  [EffectSystemBoundarySend] ->
  [EffectSystemBoundaryTransform] ->
  [EffectSystemBoundaryPolicy] ->
  [EffectSystemBoundaryPipeline] ->
  EffectSystemBoundary fact
systemBoundaryWithPipelines name imports privateFacts exports sends transforms policies pipelines =
  systemBoundaryWithHandlers name imports privateFacts exports sends transforms policies pipelines []

systemBoundaryWithHandlers ::
  EffectSystemName ->
  [fact] ->
  [fact] ->
  [fact] ->
  [EffectSystemBoundarySend] ->
  [EffectSystemBoundaryTransform] ->
  [EffectSystemBoundaryPolicy] ->
  [EffectSystemBoundaryPipeline] ->
  [EffectSystemBoundaryHandler] ->
  EffectSystemBoundary fact
systemBoundaryWithHandlers name imports privateFacts exports sends transforms policies pipelines handlers =
  EffectSystemBoundary
    { effectSystemBoundaryName = name
    , effectSystemBoundaryImports = imports
    , effectSystemBoundaryPrivateFacts = privateFacts
    , effectSystemBoundaryExports = exports
    , effectSystemBoundarySends = sends
    , effectSystemBoundaryTransforms = transforms
    , effectSystemBoundaryPolicies = policies
    , effectSystemBoundaryPipelines = pipelines
    , effectSystemBoundaryHandlers = handlers
    }

boundarySend :: String -> EffectSystemBoundarySend
boundarySend =
  EffectSystemBoundarySend

boundaryTransform :: String -> EffectSystemBoundaryTransform
boundaryTransform =
  EffectSystemBoundaryTransform

boundaryIdempotent :: String -> EffectSystemBoundaryPolicy
boundaryIdempotent =
  EffectSystemBoundaryIdempotent . boundarySend

boundaryRetryOnce :: String -> EffectSystemBoundaryPolicy
boundaryRetryOnce =
  EffectSystemBoundaryRetryOnce . boundarySend

boundaryArtifact :: String -> EffectSystemBoundaryArtifact
boundaryArtifact =
  EffectSystemBoundaryArtifact

boundaryPipeline :: String -> [EffectSystemBoundaryArtifact] -> EffectSystemBoundaryPipeline
boundaryPipeline =
  EffectSystemBoundaryPipeline

boundaryHandler :: String -> String -> EffectSystemBoundaryHandler
boundaryHandler currentSend handlerName =
  EffectSystemBoundaryHandler
    { effectSystemBoundaryHandlerSend = boundarySend currentSend
    , effectSystemBoundaryHandlerName = handlerName
    }

recursionMode :: String -> RecursionSchemeMode
recursionMode =
  RecursionSchemeMode

renderBeforeRunMode :: RecursionSchemeMode
renderBeforeRunMode =
  recursionMode "render-before-run"

listenDuringRunMode :: RecursionSchemeMode
listenDuringRunMode =
  recursionMode "listen-during-run"

cataMode :: RecursionSchemeMode
cataMode =
  recursionMode "cata"

paraMode :: RecursionSchemeMode
paraMode =
  recursionMode "para"

histoMode :: RecursionSchemeMode
histoMode =
  recursionMode "histo"

anaMode :: RecursionSchemeMode
anaMode =
  recursionMode "ana"

apoMode :: RecursionSchemeMode
apoMode =
  recursionMode "apo"

futuMode :: RecursionSchemeMode
futuMode =
  recursionMode "futu"

hyloMode :: RecursionSchemeMode
hyloMode =
  recursionMode "hylo"

chronoMode :: RecursionSchemeMode
chronoMode =
  recursionMode "chrono"

preproMode :: RecursionSchemeMode
preproMode =
  recursionMode "prepro"

zygoMode :: RecursionSchemeMode
zygoMode =
  recursionMode "zygo"

generalizedMode :: String -> RecursionSchemeMode
generalizedMode name =
  recursionMode ("g:" ++ name)

recursionContextAlgebra :: String -> [EffectSystem fact] -> RecursionContextAlgebra fact
recursionContextAlgebra =
  RecursionContextAlgebra

recursionModel :: String -> [RecursionSchemeMode] -> RecursionContextAlgebra fact -> RecursionSchemeModel fact
recursionModel =
  RecursionSchemeModel

recursionContext :: RecursionContextName -> RecursionSchemeModel fact -> RecursionContext fact
recursionContext =
  RecursionContext

recursionModelHasMode :: RecursionSchemeMode -> RecursionSchemeModel fact -> Bool
recursionModelHasMode currentMode model =
  currentMode `elem` recursionSchemeModelModes model

effectSystemFromBoundary :: EffectSystemBoundary fact -> EffectSystem fact
effectSystemFromBoundary boundary =
  EffectSystem
    { effectSystemName = effectSystemBoundaryName boundary
    , effectSystemSuccess = factItems (effectSystemBoundaryExports boundary)
    , effectSystemBoundary = boundary
    , effectSystemBoundaryExplicit = True
    }

effectSystemRuntimeFacts :: EffectSystem fact -> FactExpr fact
effectSystemRuntimeFacts system =
  case (effectSystemBoundaryImports boundary, effectSystemBoundaryPrivateFacts boundary) of
    ([], []) ->
      effectSystemSuccess system
    (imports, privateFacts) ->
      factAll
        ( map factItems (filter (not . null) [imports, privateFacts])
            ++ [effectSystemSuccess system]
        )
  where
    boundary =
      effectSystemBoundary system

run :: EffectSystem fact -> Workflow fact hook
run =
  RunWorkflow

chain :: [Workflow fact hook] -> Workflow fact hook
chain =
  ChainWorkflow . freeChain

parallel :: [Workflow fact hook] -> Workflow fact hook
parallel =
  ParallelWorkflow . freeParallel

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

callback :: EffectSystemName -> workflow -> HangingAction fact hook workflow
callback currentTarget body =
  HangingCallback (Callback currentTarget body)

suspense :: EffectSystemName -> HangingAction fact hook workflow
suspense currentTarget =
  HangingSuspense (Suspense currentTarget)

loop :: workflow -> HangingAction fact hook workflow
loop body =
  HangingLoop (Loop body)

middleware :: hook -> workflow -> HangingAction fact hook workflow
middleware currentMiddleware body =
  HangingMiddleware (Middleware currentMiddleware) body

context :: RecursionContext fact -> workflow -> HangingAction fact hook workflow
context currentContext body =
  HangingContext currentContext body

withRecursionContext :: RecursionContext WorkflowFact -> AppBlueprint -> AppBlueprint
withRecursionContext currentContext blueprint =
  blueprint
    { blueprintHanging =
        hanging
          (hangingItems (blueprintHanging blueprint) ++ [context currentContext (blueprintApp blueprint)])
    }

factExprFacts :: FactExpr fact -> [fact]
factExprFacts expr =
  case expr of
    FactItems requirement ->
      requirementItems requirement
    FactAll items ->
      concatMap factExprFacts items
    FactAny items ->
      concatMap factExprFacts items
