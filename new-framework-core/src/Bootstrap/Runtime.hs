{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Runtime
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , NativeHandler (..)
  , NativeRuntime (..)
  , RuntimeArtifact (..)
  , RuntimeEffectEnvironment (..)
  , SendContract (..)
  , TransformBinding (..)
  , TransformRegistry (..)
  , bootstrapHandlerRegistry
  , bootstrapRuntimeEffectEnvironment
  , bootstrapSendBoundaries
  , bootstrapTransformRegistry
  , buildNativeApp
  , handlerFor
  , renderNativeAppError
  , runNativeBlueprintWithEffectEnvironment
  , runNativeBlueprintWithEffectEnvironmentResult
  ) where

import Prelude hiding
  ( error
  )

import Data.Char
  ( isAlphaNum
  )
import Data.List
  ( isPrefixOf
  , isSuffixOf
  , sort
  )
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , listDirectory
  )
import System.FilePath
  ( normalise
  , takeExtension
  , (</>)
  )

import qualified Bootstrap.Blueprint as BootstrapBlueprint
import qualified Bootstrap.CoreSurface as CoreSurface
import qualified Bootstrap.Effects as BootstrapEffects
import Bootstrap.Vocabulary
import qualified Bootstrap.Effect as Effect
import Bootstrap.Effect
  ( EffectSection (..)
  , EffectTheory (..)
  , ExternalTakeBoundary (..)
  , FactProducer (..)
  , HandlerName (..)
  , IdempotencyPolicy (..)
  , ProducerStep (..)
  , RetryPolicy (..)
  , SendBoundary (..)
  , SendName (..)
  , SendPolicy (..)
  , SendSignature (..)
  , TransformName (..)
  , TypeName (..)
  , pattern ErrorInput
  , pattern NoInput
  , pattern Unit
  )
import Bootstrap.Workflow
  ( AppBlueprint (..)
  , Fact (..)
  , FactExpr (..)
  , Workflow (..)
  , WorkflowFact (..)
  , chainItems
  , choiceItems
  , fallbackItems
  , parallelItems
  , raceItems
  , requirementItems
  )
import qualified Bootstrap.Workflow as Workflow

data HandlerRegistry = HandlerRegistry
  { handlerRegistryBindings :: [HandlerBinding]
  }

data HandlerBinding = HandlerBinding
  { handlerBindingSend :: SendName
  , handlerBindingName :: HandlerName
  , handlerBindingHandler :: NativeHandler
  }

newtype NativeHandler = NativeHandler
  { runNativeHandler :: SendName -> [RuntimeArtifact] -> NativeRuntime -> IO HandlerResult
  }

data HandlerResult
  = HandlerSucceeded [RuntimeArtifact]
  | HandlerFailed String
  deriving (Eq, Show)

newtype TransformRegistry = TransformRegistry
  { transformRegistryBindings :: [TransformBinding]
  }

data TransformBinding = TransformBinding
  { transformBindingName :: TransformName
  , transformBindingInput :: TypeName
  , transformBindingOutput :: TypeName
  }
  deriving (Eq, Show)

data RuntimeEffectEnvironment = RuntimeEffectEnvironment
  { runtimeEffectHandlers :: HandlerRegistry
  , runtimeEffectTransforms :: TransformRegistry
  }

data RuntimeArtifact = RuntimeArtifact
  { artifactType :: TypeName
  , artifactText :: String
  }
  deriving (Eq, Show)

data NativeRuntime = NativeRuntime
  { availableFacts :: [WorkflowFact]
  , runtimeArtifacts :: [RuntimeArtifact]
  , runtimeTrace :: [String]
  , runtimeFailures :: [String]
  }
  deriving (Eq, Show)

data NativeAppPlan = NativeAppPlan
  { nativeAppPlanFacts :: [WorkflowFact]
  , nativeAppPlanRootFacts :: [WorkflowFact]
  , nativeAppPlanSendBoundaries :: [SendName]
  , nativeAppPlanSendContracts :: [SendContract]
  , nativeAppPlanFactRules :: [NativeFactRule]
  , nativeAppPlanConstraints :: [NativeConstraint]
  }

data SendContract = SendContract
  { sendContractName :: SendName
  , sendContractSignature :: SendSignature
  , sendContractIdempotency :: IdempotencyPolicy
  , sendContractRetry :: RetryPolicy
  }

data NativeFactRule = NativeFactRule
  { nativeRuleFact :: WorkflowFact
  , nativeRuleNeeds :: [WorkflowFact]
  , nativeRuleTakes :: [TypeName]
  , nativeRuleMakes :: [TypeName]
  , nativeRuleUses :: [SendName]
  , nativeRuleTransforms :: [(TypeName, TypeName, TransformName)]
  , nativeRuleErrors :: [SendName]
  , nativeRuleExternal :: Bool
  }
  deriving (Eq, Show)

data NativeConstraint = NativeConstraint
  { nativeConstraintName :: String
  , nativeConstraintPassed :: Bool
  , nativeConstraintMessage :: String
  }
  deriving (Eq, Show)

data SourceImportGraph = SourceImportGraph
  { sourceImportModules :: [SourceModule]
  }

data SourceModule = SourceModule
  { sourceModuleName :: String
  , sourceModulePath :: FilePath
  , sourceModuleImports :: [String]
  }

bootstrapRuntimeEffectEnvironment :: RuntimeEffectEnvironment
bootstrapRuntimeEffectEnvironment =
  RuntimeEffectEnvironment bootstrapHandlerRegistry bootstrapTransformRegistry

bootstrapHandlerRegistry :: HandlerRegistry
bootstrapHandlerRegistry =
  HandlerRegistry
    [ HandlerBinding currentSend (bootstrapHandlerName currentSend) bootstrapNativeHandler
    | currentSend <- bootstrapSendBoundaries
    ]

bootstrapTransformRegistry :: TransformRegistry
bootstrapTransformRegistry =
  TransformRegistry []

bootstrapSendBoundaries :: [SendName]
bootstrapSendBoundaries =
  [ ReadPackageFiles
  , LoadCoreSurfaceCatalog
  , FormalizeCoreSurfaceModule
  , FormalizeCoreSurfaceCapability
  , ComposeCoreSurfaceAst
  , CompileCoreSurfaceEffectTheory
  , ExtractRealImportGraph
  , CheckCoreBoundary
  , CheckFrontendBoundary
  , CheckLanguageSpec
  , CheckElaborationContract
  , BuildMinimalCoreReport
  , GenerateConstraintIR
  , RunSmtProof
  , RunRuntimeSmoke
  , PublishFrameworkCoreReport
  ]

bootstrapNativeHandler :: NativeHandler
bootstrapNativeHandler =
  NativeHandler runBootstrapNative

runNativeBlueprintWithEffectEnvironment :: RuntimeEffectEnvironment -> EffectTheory -> AppBlueprint -> IO ()
runNativeBlueprintWithEffectEnvironment environment effects blueprint = do
  result <- runNativeBlueprintWithEffectEnvironmentResult environment effects blueprint
  case result of
    Left message ->
      ioError (userError message)
    Right runtime ->
      mapM_ putStrLn (runtimeTrace runtime)

runNativeBlueprintWithEffectEnvironmentResult ::
  RuntimeEffectEnvironment ->
  EffectTheory ->
  AppBlueprint ->
  IO (Either String NativeRuntime)
runNativeBlueprintWithEffectEnvironmentResult environment effects blueprint =
  case buildNativeApp blueprint effects of
    Left message ->
      pure (Left message)
    Right plan
      | not (nativePlanPassed plan) ->
          pure (Left (renderNativePlanErrors plan))
      | otherwise -> do
          result <- runNativeWorkflow environment plan emptyNativeRuntime (blueprintApp blueprint)
          pure
            ( case result of
                Left message ->
                  Left message
                Right runtime ->
                  Right runtime
            )

buildNativeApp :: AppBlueprint -> EffectTheory -> Either String NativeAppPlan
buildNativeApp blueprint effects =
  let rootFacts =
        collectWorkflowFacts (blueprintApp blueprint)
      factRules =
        nativeFactRules effects
      sendContracts =
        nativeSendContracts effects
      constraints =
        nativeConstraints rootFacts factRules sendContracts
   in Right
        NativeAppPlan
          { nativeAppPlanFacts = map nativeRuleFact factRules
          , nativeAppPlanRootFacts = rootFacts
          , nativeAppPlanSendBoundaries = map sendContractName sendContracts
          , nativeAppPlanSendContracts = sendContracts
          , nativeAppPlanFactRules = factRules
          , nativeAppPlanConstraints = constraints
          }

renderNativeAppError :: String -> String
renderNativeAppError =
  id

handlerFor :: HandlerRegistry -> SendName -> Maybe HandlerBinding
handlerFor registry currentSend =
  firstJust
    [ Just binding
    | binding <- handlerRegistryBindings registry
    , handlerBindingSend binding == currentSend
    ]

runNativeWorkflow ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  Workflow.Workflow WorkflowFact Workflow.Interceptor ->
  IO (Either String NativeRuntime)
runNativeWorkflow environment plan runtime workflow =
  case workflow of
    FactWorkflow currentFact ->
      runFactExpr environment plan runtime (factExpression currentFact)
    ChainWorkflow name steps ->
      runSequential environment plan (traceRuntime ("chain " ++ show name) runtime) (chainItems steps)
    ParallelWorkflow name branches ->
      runSequential environment plan (traceRuntime ("parallel " ++ show name) runtime) (parallelItems branches)
    FallbackWorkflow branches ->
      runSequential environment plan runtime (fallbackItems branches)
    RaceWorkflow branches ->
      runSequential environment plan runtime (raceItems branches)
    ChoiceWorkflow _ branches ->
      runSequential environment plan runtime (map snd (choiceItems branches))
    WaitWorkflow wait body -> do
      waited <- runFactExpr environment plan runtime (Workflow.waitFacts wait)
      case waited of
        Left message ->
          pure (Left message)
        Right waitedRuntime ->
          runNativeWorkflow environment plan waitedRuntime body

runSequential ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [Workflow.Workflow WorkflowFact Workflow.Interceptor] ->
  IO (Either String NativeRuntime)
runSequential _ _ runtime [] =
  pure (Right runtime)
runSequential environment plan runtime (workflow : rest) = do
  result <- runNativeWorkflow environment plan runtime workflow
  case result of
    Left message ->
      pure (Left message)
    Right nextRuntime ->
      runSequential environment plan nextRuntime rest

runFactExpr ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  FactExpr WorkflowFact ->
  IO (Either String NativeRuntime)
runFactExpr environment plan runtime expression =
  case expression of
    FactItems requirements ->
      ensureFacts environment plan runtime (requirementItems requirements)
    FactAll expressions ->
      runFactExprs environment plan runtime expressions
    FactAny [] ->
      pure (Left "empty factAny cannot be satisfied")
    FactAny (firstExpression : _) ->
      runFactExpr environment plan runtime firstExpression

runFactExprs ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [FactExpr WorkflowFact] ->
  IO (Either String NativeRuntime)
runFactExprs _ _ runtime [] =
  pure (Right runtime)
runFactExprs environment plan runtime (expression : rest) = do
  result <- runFactExpr environment plan runtime expression
  case result of
    Left message ->
      pure (Left message)
    Right nextRuntime ->
      runFactExprs environment plan nextRuntime rest

ensureFacts ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [WorkflowFact] ->
  IO (Either String NativeRuntime)
ensureFacts _ _ runtime [] =
  pure (Right runtime)
ensureFacts environment plan runtime (currentFact : rest) = do
  result <- ensureFact environment plan runtime [] currentFact
  case result of
    Left message ->
      pure (Left message)
    Right nextRuntime ->
      ensureFacts environment plan nextRuntime rest

ensureFact ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [WorkflowFact] ->
  WorkflowFact ->
  IO (Either String NativeRuntime)
ensureFact environment plan runtime stack currentFact
  | currentFact `elem` availableFacts runtime =
      pure (Right runtime)
  | currentFact `elem` stack =
      pure (Left ("fact dependency cycle: " ++ show (reverse (currentFact : stack))))
  | otherwise =
      case ruleFor plan currentFact of
        Nothing ->
          pure (Left ("missing native fact rule for " ++ show currentFact))
        Just rule -> do
          dependencies <- ensureRuleDependencies environment plan runtime (currentFact : stack) rule
          case dependencies of
            Left message ->
              pure (Left message)
            Right dependencyRuntime -> do
              sendResult <- runRuleSends environment plan dependencyRuntime rule
              case sendResult of
                Left message ->
                  pure (Left message)
                Right sentRuntime ->
                  pure (Right (markRuleSucceeded rule sentRuntime))

ensureRuleDependencies ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [WorkflowFact] ->
  NativeFactRule ->
  IO (Either String NativeRuntime)
ensureRuleDependencies environment plan runtime stack rule = do
  needed <- ensureFactsWithStack environment plan runtime stack (nativeRuleNeeds rule)
  case needed of
    Left message ->
      pure (Left message)
    Right neededRuntime ->
      ensureTakes environment plan neededRuntime stack rule

ensureFactsWithStack ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  IO (Either String NativeRuntime)
ensureFactsWithStack _ _ runtime _ [] =
  pure (Right runtime)
ensureFactsWithStack environment plan runtime stack (currentFact : rest) = do
  result <- ensureFact environment plan runtime stack currentFact
  case result of
    Left message ->
      pure (Left message)
    Right nextRuntime ->
      ensureFactsWithStack environment plan nextRuntime stack rest

ensureTakes ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [WorkflowFact] ->
  NativeFactRule ->
  IO (Either String NativeRuntime)
ensureTakes _ _ runtime _ rule
  | all (`artifactAvailable` runtime) nativeTakes =
      pure (Right runtime)
  where
    nativeTakes =
      filter isPipeType (nativeRuleTakes rule)
ensureTakes environment plan runtime stack rule =
  ensureTakeTypes environment plan runtime stack (filter isPipeType (nativeRuleTakes rule))

ensureTakeTypes ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [WorkflowFact] ->
  [TypeName] ->
  IO (Either String NativeRuntime)
ensureTakeTypes _ _ runtime _ [] =
  pure (Right runtime)
ensureTakeTypes environment plan runtime stack (currentType : rest)
  | artifactAvailable currentType runtime =
      ensureTakeTypes environment plan runtime stack rest
  | otherwise =
      case sourceFactsForType plan currentType of
        [] ->
          pure (Left ("missing producer for pipe type " ++ show currentType))
        [sourceFact] -> do
          result <- ensureFact environment plan runtime stack sourceFact
          case result of
            Left message ->
              pure (Left message)
            Right nextRuntime ->
              ensureTakeTypes environment plan nextRuntime stack rest
        sources ->
          pure (Left ("duplicate producers for pipe type " ++ show currentType ++ ": " ++ show sources))

runRuleSends ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  NativeFactRule ->
  IO (Either String NativeRuntime)
runRuleSends _ _ runtime rule
  | null (nativeRuleUses rule) =
      pure (Right runtime)
runRuleSends environment plan runtime rule =
  runSends environment plan runtime (nativeRuleUses rule)

runSends ::
  RuntimeEffectEnvironment ->
  NativeAppPlan ->
  NativeRuntime ->
  [SendName] ->
  IO (Either String NativeRuntime)
runSends _ _ runtime [] =
  pure (Right runtime)
runSends environment plan runtime (currentSend : rest) =
  case sendContractFor plan currentSend of
    Nothing ->
      pure (Left ("missing send boundary for " ++ show currentSend))
    Just contract ->
      case handlerFor (runtimeEffectHandlers environment) currentSend of
        Nothing ->
          pure (Left ("missing native handler for " ++ show currentSend))
        Just binding -> do
          let inputArtifacts =
                handlerInputArtifacts runtime (sendInput (sendContractSignature contract))
          result <-
            runNativeHandler
              (handlerBindingHandler binding)
              currentSend
              inputArtifacts
              runtime
          case result of
            HandlerFailed message ->
              pure (Left ("native handler failed for " ++ show currentSend ++ ": " ++ message))
            HandlerSucceeded outputs ->
              let nextRuntime =
                    traceRuntime ("externalMake " ++ show currentSend ++ " using " ++ show (handlerBindingName binding))
                      (recordArtifacts outputs runtime)
               in runSends environment plan nextRuntime rest

handlerInputArtifacts :: NativeRuntime -> TypeName -> [RuntimeArtifact]
handlerInputArtifacts runtime inputType
  | not (isPipeType inputType) =
      []
  | otherwise =
      [ artifact
      | artifact <- runtimeArtifacts runtime
      , artifactType artifact == inputType
      ]

markRuleSucceeded :: NativeFactRule -> NativeRuntime -> NativeRuntime
markRuleSucceeded rule =
  markFact (nativeRuleFact rule)
    . recordArtifacts
      [ RuntimeArtifact currentType ("produced by " ++ show (nativeRuleFact rule))
      | currentType <- nativeRuleMakes rule
      , isPipeType currentType
      ]

markFact :: WorkflowFact -> NativeRuntime -> NativeRuntime
markFact currentFact runtime =
  traceRuntime ("fact [" ++ show currentFact ++ "]") runtime
    { availableFacts = unique (availableFacts runtime ++ [currentFact])
    }

recordArtifacts :: [RuntimeArtifact] -> NativeRuntime -> NativeRuntime
recordArtifacts artifacts runtime =
  runtime {runtimeArtifacts = foldl upsertArtifact (runtimeArtifacts runtime) artifacts}

traceRuntime :: String -> NativeRuntime -> NativeRuntime
traceRuntime message runtime =
  runtime {runtimeTrace = runtimeTrace runtime ++ ["[native-runtime] " ++ message]}

emptyNativeRuntime :: NativeRuntime
emptyNativeRuntime =
  NativeRuntime [] [] [] []

runBootstrapNative :: SendName -> [RuntimeArtifact] -> NativeRuntime -> IO HandlerResult
runBootstrapNative ReadPackageFiles _ _ = do
  graph <- readSourceImportGraph packageSourceRoots
  pure
    ( succeedArtifact
        PackageModuleCatalog
        ("package modules: " ++ show (length (sourceImportModules graph)))
    )
runBootstrapNative LoadCoreSurfaceCatalog _ _ =
  pure
    ( succeedArtifact
        CoreSurface.coreSurfaceCatalogType
        ( "core surface modules: "
            ++ show CoreSurface.coreSurfaceModuleCount
            ++ ", capabilities: "
            ++ show CoreSurface.coreSurfaceCapabilityCount
        )
    )
runBootstrapNative FormalizeCoreSurfaceModule _ _ =
  pure (HandlerSucceeded [])
runBootstrapNative FormalizeCoreSurfaceCapability _ _ =
  pure (HandlerSucceeded [])
runBootstrapNative ComposeCoreSurfaceAst _ _ =
  pure (succeedArtifact CoreSurface.coreSurfaceAstType "core surface AST composed")
runBootstrapNative CompileCoreSurfaceEffectTheory _ _ =
  pure (succeedArtifact CoreSurface.coreSurfaceEffectTheoryType "core surface effect theory compiled")
runBootstrapNative ExtractRealImportGraph _ _ = do
  graph <- readSourceImportGraph frameworkCoreSourceRoots
  pure
    ( succeedArtifact
        ImportGraphArtifact
        ("new-framework-core import graph modules: " ++ show (length (sourceImportModules graph)))
    )
runBootstrapNative CheckCoreBoundary _ _ = do
  graph <- readSourceImportGraph frameworkCoreSourceRoots
  case checkNativeCoreBoundary graph of
    [] ->
      pure (succeedArtifact CoreBoundaryEvidence "native core boundary passed")
    errors ->
      pure (HandlerFailed (joinLines errors))
runBootstrapNative CheckFrontendBoundary _ _ = do
  graph <- readSourceImportGraph frontendBoundaryRoots
  case checkNativeFrontendBoundary graph of
    [] ->
      pure (succeedArtifact FrontendBoundaryEvidence "native frontend boundary passed")
    errors ->
      pure (HandlerFailed (joinLines errors))
runBootstrapNative CheckLanguageSpec _ _ =
  case checkNativeLanguageSpec of
    [] ->
      pure (succeedArtifact LanguageSpecEvidence "native language spec passed")
    errors ->
      pure (HandlerFailed (joinLines errors))
runBootstrapNative CheckElaborationContract _ _ =
  case checkNativeElaborationContract of
    [] ->
      pure (succeedArtifact ElaborationContractEvidence "native elaboration contract passed")
    errors ->
      pure (HandlerFailed (joinLines errors))
runBootstrapNative BuildMinimalCoreReport _ _ =
  case buildNativeFrameworkCoreReport of
    Left message ->
      pure (HandlerFailed message)
    Right plan ->
      pure
        ( succeedArtifact
            MinimalCoreReportArtifact
            ("native constraints: " ++ show (length (nativeAppPlanConstraints plan)))
        )
runBootstrapNative GenerateConstraintIR _ _ =
  case buildNativeFrameworkCoreReport of
    Left message ->
      pure (HandlerFailed message)
    Right plan ->
      pure
        ( succeedArtifact
            ConstraintIRArtifact
            ("native constraint facts: " ++ show (length (nativeAppPlanConstraints plan)))
        )
runBootstrapNative RunSmtProof _ _ =
  case buildNativeFrameworkCoreReport of
    Left message ->
      pure (HandlerFailed message)
    Right plan
      | nativePlanPassed plan ->
          pure (succeedArtifact SmtProofEvidence "native proof passed; external solver not required")
      | otherwise ->
          pure (HandlerFailed (renderNativePlanErrors plan))
runBootstrapNative RunRuntimeSmoke _ _ =
  case buildNativeApp runtimeClosureSmokeAst runtimeClosureSmokeEffects of
    Left message ->
      pure (HandlerFailed message)
    Right plan
      | nativePlanPassed plan ->
          pure (succeedArtifact RuntimeSmokeEvidence "native runtime fact closure passed")
      | otherwise ->
          pure (HandlerFailed (renderNativePlanErrors plan))
runBootstrapNative PublishFrameworkCoreReport _ _ =
  pure (succeedArtifact FrameworkCoreReportArtifact "framework-core expression published natively")
runBootstrapNative currentSend _ _ =
  pure (HandlerFailed ("unhandled framework-core bootstrap send " ++ show currentSend))

buildNativeFrameworkCoreReport :: Either String NativeAppPlan
buildNativeFrameworkCoreReport =
  case buildNativeApp BootstrapBlueprint.coreBootstrapBlueprint BootstrapEffects.coreBootstrapEffects of
    Left message ->
      Left message
    Right plan
      | nativePlanPassed plan ->
          Right plan
      | otherwise ->
          Left (renderNativePlanErrors plan)

runtimeClosureSmokeAst :: Workflow.AppBlueprint
runtimeClosureSmokeAst =
  Workflow.AppBlueprint
    { Workflow.blueprintApp =
        Workflow.fact (Workflow.factItems [runtimeClosureRootFact])
    , Workflow.blueprintHanging =
        Workflow.hanging []
    }

runtimeClosureSmokeEffects :: Effect.EffectTheory
runtimeClosureSmokeEffects =
  Effect.theory
    [ Effect.effect
        (Effect.EffectName "FrameworkCoreRuntimeClosureSmokeEffect")
        [ Effect.fact runtimeClosureRootFact
            [ Effect.needs runtimeClosureDependencyFact
            ]
        , Effect.fact runtimeClosureDependencyFact
        ]
    ]

runtimeClosureRootFact :: Workflow.WorkflowFact
runtimeClosureRootFact =
  Workflow.WorkflowFact "FrameworkCoreRuntimeClosureRootFact"

runtimeClosureDependencyFact :: Workflow.WorkflowFact
runtimeClosureDependencyFact =
  Workflow.WorkflowFact "FrameworkCoreRuntimeClosureDependencyFact"

nativeFactRules :: EffectTheory -> [NativeFactRule]
nativeFactRules (EffectTheory units) =
  concatMap unitFactRules units

unitFactRules :: Effect.EffectUnit -> [NativeFactRule]
unitFactRules unit =
  concatMap sectionFactRules (Effect.effectUnitSections unit)

sectionFactRules :: EffectSection -> [NativeFactRule]
sectionFactRules (FactClaimSection producer) =
  [factRuleFromProducer producer]
sectionFactRules (ExternalTakeSection boundary) =
  [factRuleFromExternalTake boundary]
sectionFactRules _ =
  []

factRuleFromProducer :: FactProducer -> NativeFactRule
factRuleFromProducer producer =
  NativeFactRule
    { nativeRuleFact = Effect.producerFact producer
    , nativeRuleNeeds =
        [ fact
        | Needs fact <- steps
        ]
    , nativeRuleTakes =
        [ typeName
        | Take typeName <- steps
        ]
    , nativeRuleMakes =
        explicitMakes ++ sendOutputs ++ transformOutputs
    , nativeRuleUses =
        [ send
        | Uses send <- steps
        ]
    , nativeRuleTransforms =
        [ (input, output, name)
        | Transform input output name <- steps
        ]
    , nativeRuleErrors =
        [ send
        | Error send <- steps
        ]
    , nativeRuleExternal = False
    }
  where
    steps =
      Effect.producerSteps producer
    explicitMakes =
      [ typeName
      | Make typeName <- steps
      , isPipeType typeName
      ]
    sendOutputs =
      [ sendOutput signature
      | Uses send <- steps
      , Just signature <- [sendSignatureByName send BootstrapEffects.coreBootstrapEffects]
      , isPipeType (sendOutput signature)
      ]
    transformOutputs =
      [ output
      | Transform _ output _ <- steps
      , isPipeType output
      ]

factRuleFromExternalTake :: ExternalTakeBoundary -> NativeFactRule
factRuleFromExternalTake boundary =
  NativeFactRule
    { nativeRuleFact = externalTakeFact boundary
    , nativeRuleNeeds = []
    , nativeRuleTakes = []
    , nativeRuleMakes =
        [ output
        | Just output <- [externalTakeOutput boundary]
        , isPipeType output
        ]
    , nativeRuleUses = []
    , nativeRuleTransforms = []
    , nativeRuleErrors = []
    , nativeRuleExternal = True
    }

nativeSendContracts :: EffectTheory -> [SendContract]
nativeSendContracts effects =
  [ SendContract
      { sendContractName = sendBoundaryName boundary
      , sendContractSignature = sendBoundarySignature boundary
      , sendContractIdempotency = sendPolicyIdempotencyFor (sendBoundaryName boundary) policies
      , sendContractRetry = sendPolicyRetryFor (sendBoundaryName boundary) policies
      }
  | boundary <- sendBoundaries effects
  ]
  where
    policies =
      sendPolicies effects

sendBoundaries :: EffectTheory -> [SendBoundary]
sendBoundaries (EffectTheory units) =
  [ boundary
  | unit <- units
  , section <- Effect.effectUnitSections unit
  , SendSection boundary <- [section]
  ]

sendPolicies :: EffectTheory -> [SendPolicy]
sendPolicies (EffectTheory units) =
  [ policy
  | unit <- units
  , section <- Effect.effectUnitSections unit
  , SendPolicySection policy <- [section]
  ]

sendSignatureByName :: SendName -> EffectTheory -> Maybe SendSignature
sendSignatureByName currentSend effects =
  firstJust
    [ Just (sendBoundarySignature boundary)
    | boundary <- sendBoundaries effects
    , sendBoundaryName boundary == currentSend
    ]

sendPolicyIdempotencyFor :: SendName -> [SendPolicy] -> IdempotencyPolicy
sendPolicyIdempotencyFor currentSend policies =
  maybe
    NonIdempotent
    id
    ( firstJust
        [ sendPolicyIdempotency policy
        | policy <- policies
        , sendPolicyName policy == currentSend
        ]
    )

sendPolicyRetryFor :: SendName -> [SendPolicy] -> RetryPolicy
sendPolicyRetryFor currentSend policies =
  maybe
    NoRetry
    id
    ( firstJust
        [ sendPolicyRetry policy
        | policy <- policies
        , sendPolicyName policy == currentSend
        ]
    )

nativeConstraints :: [WorkflowFact] -> [NativeFactRule] -> [SendContract] -> [NativeConstraint]
nativeConstraints rootFacts rules contracts =
  concat
    [ map (factDeclaredConstraint rules) rootFacts
    , map (ruleNeedsDeclaredConstraint rules) rules
    , map (ruleSendsDeclaredConstraint contracts) rules
    , duplicatePipeMakerConstraints rules
    , map (ruleTakesHaveMakerConstraint rules) rules
    ]

factDeclaredConstraint :: [NativeFactRule] -> WorkflowFact -> NativeConstraint
factDeclaredConstraint rules currentFact =
  NativeConstraint
    ("root fact declared " ++ show currentFact)
    (any ((== currentFact) . nativeRuleFact) rules)
    ("root fact has no effect rule: " ++ show currentFact)

ruleNeedsDeclaredConstraint :: [NativeFactRule] -> NativeFactRule -> NativeConstraint
ruleNeedsDeclaredConstraint rules rule =
  NativeConstraint
    ("needs declared " ++ show (nativeRuleFact rule))
    (all (`elem` ruleFacts) (nativeRuleNeeds rule))
    ("missing needed fact for " ++ show (nativeRuleFact rule))
  where
    ruleFacts =
      map nativeRuleFact rules

ruleSendsDeclaredConstraint :: [SendContract] -> NativeFactRule -> NativeConstraint
ruleSendsDeclaredConstraint contracts rule =
  NativeConstraint
    ("sends declared " ++ show (nativeRuleFact rule))
    (all (`elem` declaredSends) (nativeRuleUses rule))
    ("missing send boundary for " ++ show (nativeRuleFact rule))
  where
    declaredSends =
      map sendContractName contracts

duplicatePipeMakerConstraints :: [NativeFactRule] -> [NativeConstraint]
duplicatePipeMakerConstraints rules =
  [ NativeConstraint
      ("single pipe maker " ++ show currentType)
      (length makers == 1)
      ("duplicate pipe makers for " ++ show currentType ++ ": " ++ show makers)
  | currentType <- unique (concatMap nativeRuleMakes rules)
  , let makers = sourceFactsForTypeFromRules rules currentType
  , isPipeType currentType
  ]

ruleTakesHaveMakerConstraint :: [NativeFactRule] -> NativeFactRule -> NativeConstraint
ruleTakesHaveMakerConstraint rules rule =
  NativeConstraint
    ("takes have makers " ++ show (nativeRuleFact rule))
    (all hasSingleMaker (filter isPipeType (nativeRuleTakes rule)))
    ("missing or duplicate pipe maker for " ++ show (nativeRuleFact rule))
  where
    hasSingleMaker currentType =
      length (sourceFactsForTypeFromRules rules currentType) == 1

nativePlanPassed :: NativeAppPlan -> Bool
nativePlanPassed =
  all nativeConstraintPassed . nativeAppPlanConstraints

renderNativePlanErrors :: NativeAppPlan -> String
renderNativePlanErrors plan =
  joinLines
    [ nativeConstraintMessage constraint
    | constraint <- nativeAppPlanConstraints plan
    , not (nativeConstraintPassed constraint)
    ]

ruleFor :: NativeAppPlan -> WorkflowFact -> Maybe NativeFactRule
ruleFor plan currentFact =
  firstJust
    [ Just rule
    | rule <- nativeAppPlanFactRules plan
    , nativeRuleFact rule == currentFact
    ]

sendContractFor :: NativeAppPlan -> SendName -> Maybe SendContract
sendContractFor plan currentSend =
  firstJust
    [ Just contract
    | contract <- nativeAppPlanSendContracts plan
    , sendContractName contract == currentSend
    ]

sourceFactsForType :: NativeAppPlan -> TypeName -> [WorkflowFact]
sourceFactsForType plan =
  sourceFactsForTypeFromRules (nativeAppPlanFactRules plan)

sourceFactsForTypeFromRules :: [NativeFactRule] -> TypeName -> [WorkflowFact]
sourceFactsForTypeFromRules rules currentType =
  [ nativeRuleFact rule
  | rule <- rules
  , currentType `elem` nativeRuleMakes rule
  ]

collectWorkflowFacts :: Workflow.Workflow WorkflowFact hook -> [WorkflowFact]
collectWorkflowFacts workflow =
  case workflow of
    FactWorkflow (Fact expression) ->
      collectFactExpr expression
    ChainWorkflow _ steps ->
      unique (concatMap collectWorkflowFacts (chainItems steps))
    ParallelWorkflow _ branches ->
      unique (concatMap collectWorkflowFacts (parallelItems branches))
    FallbackWorkflow branches ->
      unique (concatMap collectWorkflowFacts (fallbackItems branches))
    RaceWorkflow branches ->
      unique (concatMap collectWorkflowFacts (raceItems branches))
    ChoiceWorkflow _ branches ->
      unique (concatMap (collectWorkflowFacts . snd) (choiceItems branches))
    WaitWorkflow wait body ->
      unique (collectFactExpr (Workflow.waitFacts wait) ++ collectWorkflowFacts body)

collectFactExpr :: FactExpr WorkflowFact -> [WorkflowFact]
collectFactExpr expression =
  case expression of
    FactItems requirements ->
      requirementItems requirements
    FactAll expressions ->
      unique (concatMap collectFactExpr expressions)
    FactAny expressions ->
      unique (concatMap collectFactExpr expressions)

readSourceImportGraph :: [FilePath] -> IO SourceImportGraph
readSourceImportGraph roots = do
  files <- concat <$> mapM collectHaskellFiles roots
  modules <- mapM readSourceModule files
  pure (SourceImportGraph modules)

collectHaskellFiles :: FilePath -> IO [FilePath]
collectHaskellFiles root = do
  isFile <- doesFileExist root
  isDirectory <- doesDirectoryExist root
  if isFile
    then pure [root | takeExtension root == ".hs"]
    else
      if isDirectory
        then do
          children <- listDirectory root
          concat <$> mapM (collectHaskellFiles . (root </>)) children
        else pure []

readSourceModule :: FilePath -> IO SourceModule
readSourceModule path = do
  text <- readFile path
  pure
    SourceModule
      { sourceModuleName = moduleNameFromFile path text
      , sourceModulePath = normalise path
      , sourceModuleImports = mapMaybeImport (lines text)
      }

moduleNameFromFile :: FilePath -> String -> String
moduleNameFromFile path text =
  case firstJust (map parseModuleLine (lines text)) of
    Just name ->
      name
    Nothing ->
      path

parseModuleLine :: String -> Maybe String
parseModuleLine line =
  case words line of
    ("module" : name : _) ->
      Just (takeModuleName name)
    _ ->
      Nothing

mapMaybeImport :: [String] -> [String]
mapMaybeImport =
  unique . foldr collect []
  where
    collect line imports =
      case parseImportLine line of
        Just currentImport ->
          currentImport : imports
        Nothing ->
          imports

parseImportLine :: String -> Maybe String
parseImportLine line =
  case words (stripLineComment line) of
    ("import" : rest) ->
      parseImportWords rest
    _ ->
      Nothing

parseImportWords :: [String] -> Maybe String
parseImportWords [] =
  Nothing
parseImportWords ("qualified" : rest) =
  parseImportWords rest
parseImportWords (name : _) =
  Just (takeModuleName name)

takeModuleName :: String -> String
takeModuleName =
  takeWhile (\char -> isAlphaNum char || char == '_' || char == '.')

stripLineComment :: String -> String
stripLineComment [] =
  []
stripLineComment ('-' : '-' : _) =
  []
stripLineComment (char : rest) =
  char : stripLineComment rest

checkNativeCoreBoundary :: SourceImportGraph -> [String]
checkNativeCoreBoundary graph =
  duplicateSliceErrors
    ++ unknownDependencyErrors
    ++ runtimeLeakErrors
    ++ importBoundaryErrors graph

duplicateSliceErrors :: [String]
duplicateSliceErrors =
  [ "duplicate core slice " ++ currentSlice
  | currentSlice <- duplicates (map CoreSurface.coreSurfaceSliceName CoreSurface.coreSurfaceSlices)
  ]

unknownDependencyErrors :: [String]
unknownDependencyErrors =
  [ "unknown core dependency " ++ dependency ++ " required by " ++ CoreSurface.coreSurfaceSliceName currentSlice
  | currentSlice <- CoreSurface.coreSurfaceSlices
  , dependency <- CoreSurface.coreSurfaceSliceDependsOn currentSlice
  , dependency `notElem` sliceNames
  ]
  where
    sliceNames =
      map CoreSurface.coreSurfaceSliceName CoreSurface.coreSurfaceSlices

runtimeLeakErrors :: [String]
runtimeLeakErrors =
  [ "non-runtime slice " ++ CoreSurface.coreSurfaceSliceName currentSlice ++ " depends on runtime slice " ++ dependency
  | currentSlice <- CoreSurface.coreSurfaceSlices
  , CoreSurface.coreSurfaceSliceRole currentSlice /= "runtime-backend"
  , dependency <- CoreSurface.coreSurfaceSliceDependsOn currentSlice
  , dependency `elem` runtimeSliceNames
  ]
  where
    runtimeSliceNames =
      [ CoreSurface.coreSurfaceSliceName currentSlice
      | currentSlice <- CoreSurface.coreSurfaceSlices
      , CoreSurface.coreSurfaceSliceRole currentSlice == "runtime-backend"
      ]

importBoundaryErrors :: SourceImportGraph -> [String]
importBoundaryErrors graph =
  [ "undeclared core import "
      ++ sourceModuleName currentModule
      ++ " -> "
      ++ currentImport
      ++ " ("
      ++ sourceSlice
      ++ " cannot depend on "
      ++ targetSlice
      ++ ")"
  | currentModule <- sourceImportModules graph
  , Just sourceSlice <- [sliceForModule (sourceModuleName currentModule)]
  , currentImport <- sourceModuleImports currentModule
  , Just targetSlice <- [sliceForModule currentImport]
  , sourceSlice /= targetSlice
  , targetSlice `notElem` dependenciesForSlice sourceSlice
  ]

sliceForModule :: String -> Maybe String
sliceForModule currentModule =
  firstJust
    [ Just (CoreSurface.coreSurfaceSliceName currentSlice)
    | currentSlice <- CoreSurface.coreSurfaceSlices
    , currentModule `elem` expandedSliceModules currentSlice
    ]

expandedSliceModules :: CoreSurface.CoreSurfaceSlice -> [String]
expandedSliceModules currentSlice =
  concatMap expandSliceModule (CoreSurface.coreSurfaceSliceModules currentSlice)

expandSliceModule :: String -> [String]
expandSliceModule "Interpreter.Runtime.Workflow.*" =
  [ "Interpreter.Runtime.Workflow.Choice"
  , "Interpreter.Runtime.Workflow.FreeAlternative"
  , "Interpreter.Runtime.Workflow.FreeApplicative"
  , "Interpreter.Runtime.Workflow.FreeMonad"
  , "Interpreter.Runtime.Workflow.Node"
  , "Interpreter.Runtime.Workflow.Wait"
  ]
expandSliceModule currentModule =
  [currentModule]

dependenciesForSlice :: String -> [String]
dependenciesForSlice sliceName =
  transitiveSliceDependencies [] (directDependenciesForSlice sliceName)

transitiveSliceDependencies :: [String] -> [String] -> [String]
transitiveSliceDependencies seen [] =
  seen
transitiveSliceDependencies seen (sliceName : rest)
  | sliceName `elem` seen =
      transitiveSliceDependencies seen rest
  | otherwise =
      transitiveSliceDependencies
        (seen ++ [sliceName])
        (rest ++ directDependenciesForSlice sliceName)

directDependenciesForSlice :: String -> [String]
directDependenciesForSlice sliceName =
  concat
    [ CoreSurface.coreSurfaceSliceDependsOn currentSlice
    | currentSlice <- CoreSurface.coreSurfaceSlices
    , CoreSurface.coreSurfaceSliceName currentSlice == sliceName
    ]

checkNativeFrontendBoundary :: SourceImportGraph -> [String]
checkNativeFrontendBoundary graph =
  [ "forbidden frontend import: "
      ++ sourceModulePath currentModule
      ++ " imports "
      ++ currentImport
  | currentModule <- sourceImportModules graph
  , not (isExcludedFrontendPath (sourceModulePath currentModule))
  , currentImport <- sourceModuleImports currentModule
  , isForbiddenFrontendImportFor (sourceModulePath currentModule) currentImport
      || not (isAllowedFrontendImportFor (sourceModulePath currentModule) currentImport)
  ]

checkNativeLanguageSpec :: [String]
checkNativeLanguageSpec =
  missingCapabilities
    "language spec"
    [ "chain"
    , "parallel"
    , "wait"
    , "fact"
    , "externalMake"
    , "take"
    , "make"
    , "buildApp"
    ]

checkNativeElaborationContract :: [String]
checkNativeElaborationContract =
  missingCapabilities
    "elaboration contract"
    [ "Framework.Workflow"
    , "Framework.Effect"
    , "Framework.Hylo"
    , "Interpreter.Runtime"
    , "Core.App"
    ]

missingCapabilities :: String -> [String] -> [String]
missingCapabilities label names =
  [ label ++ " missing expressed capability " ++ name
  | name <- names
  , not (any (contains name) expressedNames)
  ]
  where
    expressedNames =
      map (CoreSurface.capabilityName . snd) CoreSurface.coreSurfaceCapabilities
        ++ map CoreSurface.surfaceModuleName CoreSurface.coreSurfaceModules

packageSourceRoots :: [FilePath]
packageSourceRoots =
  [ "new-framework-core/src"
  , "domain-app/src"
  ]

frameworkCoreSourceRoots :: [FilePath]
frameworkCoreSourceRoots =
  [ "new-framework-core/src"
  ]

frontendBoundaryRoots :: [FilePath]
frontendBoundaryRoots =
  [ "new-framework-core/app/Main.hs"
  , "new-framework-core/src/Bootstrap"
  , "new-framework-core/src/Domain"
  ]

isExcludedFrontendPath :: FilePath -> Bool
isExcludedFrontendPath path =
  any (`isSuffixOf` normalise path)
    [ normalise "new-framework-core/src/Bootstrap/Runtime.hs"
    , normalise "new-framework-core/src/Bootstrap/Report.hs"
    , normalise "new-framework-core/src/Domain/EffectHandlers.hs"
    , normalise "new-framework-core/src/Domain/Interpreter.hs"
    , normalise "new-framework-core/src/Domain/Registry.hs"
    ]

isAllowedFrontendImport :: String -> Bool
isAllowedFrontendImport currentImport =
  currentImport
    `elem`
      [ "Bootstrap.Blueprint"
      , "Bootstrap.CoreSurface"
      , "Bootstrap.Effect"
      , "Bootstrap.Effects"
      , "Bootstrap.Vocabulary"
      , "Bootstrap.Workflow"
      , "Blueprint"
      , "Domain.Ast"
      , "Domain.AppBlueprint"
      , "Domain.Effects"
      , "Domain.Registry"
      , "Domain.Vocabulary"
      , "Prelude"
      ]
    || "Bootstrap.Effects." `isPrefixOf` currentImport

isAllowedFrontendImportFor :: FilePath -> String -> Bool
isAllowedFrontendImportFor path currentImport =
  isAllowedFrontendImport currentImport
    || (isSelfDomainExpressionPath path && currentImport `elem` selfDomainFacadeImports)

isForbiddenFrontendImport :: String -> Bool
isForbiddenFrontendImport currentImport =
  any (`matchesModule` currentImport)
    [ "Core"
    , "Core."
    , "AST"
    , "AST."
    , "Interpreter"
    , "Interpreter."
    , "Framework.Workflow"
    , "Framework.Effect"
    , "Framework.Background"
    , "Framework.Background."
    , "Effects.EffectTheory"
    , "Effects.Names"
    ]

isForbiddenFrontendImportFor :: FilePath -> String -> Bool
isForbiddenFrontendImportFor path currentImport
  | isSelfDomainExpressionPath path && currentImport `elem` selfDomainFacadeImports =
      False
  | otherwise =
      isForbiddenFrontendImport currentImport

selfDomainFacadeImports :: [String]
selfDomainFacadeImports =
  [ "Framework.Workflow"
  , "Framework.Effect"
  , "Domain.Vocabulary"
  ]

isSelfDomainExpressionPath :: FilePath -> Bool
isSelfDomainExpressionPath path =
  normalise "new-framework-core/src/Domain" `isPrefixOf` normalise path

matchesModule :: String -> String -> Bool
matchesModule modulePattern currentImport
  | "." `isSuffixOf` modulePattern =
      modulePattern `isPrefixOf` currentImport
  | otherwise =
      modulePattern == currentImport

succeedArtifact :: TypeName -> String -> HandlerResult
succeedArtifact currentType text =
  HandlerSucceeded [RuntimeArtifact currentType text]

artifactAvailable :: TypeName -> NativeRuntime -> Bool
artifactAvailable currentType runtime =
  any ((== currentType) . artifactType) (runtimeArtifacts runtime)

isPipeType :: TypeName -> Bool
isPipeType NoInput =
  False
isPipeType Unit =
  False
isPipeType ErrorInput =
  False
isPipeType _ =
  True

upsertArtifact :: [RuntimeArtifact] -> RuntimeArtifact -> [RuntimeArtifact]
upsertArtifact [] artifact =
  [artifact]
upsertArtifact (existing : rest) artifact
  | artifactType existing == artifactType artifact =
      artifact : rest
  | otherwise =
      existing : upsertArtifact rest artifact

bootstrapHandlerName :: SendName -> HandlerName
bootstrapHandlerName (SendName name) =
  HandlerName ("Bootstrap" ++ name ++ "Handler")

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest

unique :: Eq item => [item] -> [item]
unique =
  foldl appendUnique []

appendUnique :: Eq item => [item] -> item -> [item]
appendUnique items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

duplicates :: Ord item => [item] -> [item]
duplicates =
  map head . filter multiple . groupSorted . sort
  where
    multiple (_ : _ : _) =
      True
    multiple _ =
      False

groupSorted :: Eq item => [item] -> [[item]]
groupSorted [] =
  []
groupSorted (item : rest) =
  let (same, different) =
        span (== item) rest
   in (item : same) : groupSorted different

contains :: String -> String -> Bool
contains needle haystack =
  needle `isPrefixOf` haystack || containsInfix needle haystack

containsInfix :: String -> String -> Bool
containsInfix needle haystack
  | needle == haystack =
      True
  | null haystack =
      False
  | needle `isPrefixOf` haystack =
      True
  | otherwise =
      containsInfix needle (tail haystack)

joinLines :: [String] -> String
joinLines [] =
  ""
joinLines [line] =
  line
joinLines (line : rest) =
  line ++ "\n" ++ joinLines rest
