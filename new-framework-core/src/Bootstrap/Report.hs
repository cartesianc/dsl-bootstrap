{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Report
  ( ConstraintReport (..)
  , FactClosureReport (..)
  , FrameworkCoreReport (..)
  , FrameworkCoreReportStatus (..)
  , HandlerCoverage (..)
  , buildFrameworkCoreReport
  , frameworkCoreReportPassed
  , printFrameworkCoreReport
  , renderConstraintReport
  , renderFactClosureReport
  , renderFrameworkCoreReport
  , renderHandlerCoverage
  ) where

import Bootstrap.Blueprint
  ( coreBootstrapBlueprint )
import Bootstrap.CoreSurface
  ( coreSurfaceCapabilityCount
  , coreSurfaceModuleCount
  )
import Bootstrap.Effects
  ( coreBootstrapEffects )
import Bootstrap.Runtime
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , NativeRuntime (..)
  , RuntimeArtifact (..)
  , RuntimeEffectEnvironment (..)
  , bootstrapRuntimeEffectEnvironment
  , buildNativeApp
  , renderNativeAppError
  , runNativeBlueprintWithEffectEnvironmentResult
  )
import Bootstrap.Effect
  ( SendName )
import Bootstrap.Vocabulary
  ( pattern FrameworkCoreReportPublishedFact )
import Bootstrap.Workflow
  ( WorkflowFact )

data FrameworkCoreReport = FrameworkCoreReport
  { frameworkCoreReportName :: String
  , frameworkCoreReportStatus :: FrameworkCoreReportStatus
  , frameworkCoreReportSurfaceModules :: Int
  , frameworkCoreReportSurfaceCapabilities :: Int
  , frameworkCoreReportConstraints :: ConstraintReport
  , frameworkCoreReportFactClosure :: FactClosureReport
  , frameworkCoreReportHandlerCoverage :: [HandlerCoverage]
  , frameworkCoreReportArtifacts :: [RuntimeArtifact]
  , frameworkCoreReportFailures :: [String]
  }

data FrameworkCoreReportStatus
  = FrameworkCoreReportPassed
  | FrameworkCoreReportFailed [String]
  deriving (Eq, Show)

data ConstraintReport = ConstraintReport
  { constraintReportTotal :: Int
  , constraintReportPassed :: Int
  , constraintReportFailed :: [NativeConstraint]
  }

data FactClosureReport = FactClosureReport
  { factClosureDeclaredFacts :: [WorkflowFact]
  , factClosureRootFacts :: [WorkflowFact]
  , factClosurePlannedRuntimeFacts :: [WorkflowFact]
  , factClosureFinalRuntimeFacts :: [WorkflowFact]
  , factClosureDeclaredOutsideRuntime :: [WorkflowFact]
  , factClosureMissingFinalFacts :: [WorkflowFact]
  , factClosureExtraFinalFacts :: [WorkflowFact]
  }

data HandlerCoverage = HandlerCoverage
  { handlerCoverageSend :: SendName
  , handlerCoverageHandlers :: [String]
  , handlerCoverageCovered :: Bool
  }

buildFrameworkCoreReport :: IO FrameworkCoreReport
buildFrameworkCoreReport =
  case buildNativeApp coreBootstrapBlueprint coreBootstrapEffects of
    Left errorReport ->
      pure (failedBuildReport (renderNativeAppError errorReport))
    Right plan -> do
      runtimeResult <-
        runNativeBlueprintWithEffectEnvironmentResult
          bootstrapRuntimeEffectEnvironment
          coreBootstrapEffects
          coreBootstrapBlueprint
      pure (reportFromPlan plan runtimeResult)

frameworkCoreReportPassed :: FrameworkCoreReport -> Bool
frameworkCoreReportPassed report =
  case frameworkCoreReportStatus report of
    FrameworkCoreReportPassed ->
      True
    FrameworkCoreReportFailed _ ->
      False

printFrameworkCoreReport :: IO ()
printFrameworkCoreReport =
  buildFrameworkCoreReport >>= mapM_ putStrLn . renderFrameworkCoreReport

renderFrameworkCoreReport :: FrameworkCoreReport -> [String]
renderFrameworkCoreReport report =
  [ "framework-core report"
  , "status: " ++ renderStatus (frameworkCoreReportStatus report)
  , "surface modules: " ++ show (frameworkCoreReportSurfaceModules report)
  , "surface capabilities: " ++ show (frameworkCoreReportSurfaceCapabilities report)
  ]
    ++ renderConstraintReport (frameworkCoreReportConstraints report)
    ++ renderFactClosureReport (frameworkCoreReportFactClosure report)
    ++ renderHandlerCoverage (frameworkCoreReportHandlerCoverage report)
    ++ renderArtifacts (frameworkCoreReportArtifacts report)
    ++ renderFailures (frameworkCoreReportFailures report)

renderConstraintReport :: ConstraintReport -> [String]
renderConstraintReport report =
  [ "constraints:"
  , "  total: " ++ show (constraintReportTotal report)
  , "  passed: " ++ show (constraintReportPassed report)
  , "  failed: " ++ show (length (constraintReportFailed report))
  ]
    ++ renderFailedConstraints (constraintReportFailed report)

renderFactClosureReport :: FactClosureReport -> [String]
renderFactClosureReport report =
  [ "fact closure:"
  , "  declared facts: " ++ show (length (factClosureDeclaredFacts report))
  , "  root facts: " ++ show (length (factClosureRootFacts report))
  , "  planned runtime facts: " ++ show (length (factClosurePlannedRuntimeFacts report))
  , "  final runtime facts: " ++ show (length (factClosureFinalRuntimeFacts report))
  , "  declared outside runtime closure: " ++ show (length (factClosureDeclaredOutsideRuntime report))
  , "  missing final facts: " ++ show (length (factClosureMissingFinalFacts report))
  , "  extra final facts: " ++ show (length (factClosureExtraFinalFacts report))
  ]
    ++ renderNamedFacts "declared outside runtime closure" (factClosureDeclaredOutsideRuntime report)
    ++ renderNamedFacts "missing final facts" (factClosureMissingFinalFacts report)
    ++ renderNamedFacts "extra final facts" (factClosureExtraFinalFacts report)

renderHandlerCoverage :: [HandlerCoverage] -> [String]
renderHandlerCoverage coverage =
  [ "handler coverage:"
  , "  send boundaries: " ++ show (length coverage)
  , "  covered: " ++ show (length (filter handlerCoverageCovered coverage))
  , "  missing: " ++ show (length (filter (not . handlerCoverageCovered) coverage))
  ]
    ++ renderMissingHandlers coverage

reportFromPlan :: NativeAppPlan -> Either String NativeRuntime -> FrameworkCoreReport
reportFromPlan plan runtimeResult =
  FrameworkCoreReport
    { frameworkCoreReportName = "framework-core"
    , frameworkCoreReportStatus = status
    , frameworkCoreReportSurfaceModules = coreSurfaceModuleCount
    , frameworkCoreReportSurfaceCapabilities = coreSurfaceCapabilityCount
    , frameworkCoreReportConstraints = constraints
    , frameworkCoreReportFactClosure = facts
    , frameworkCoreReportHandlerCoverage = handlers
    , frameworkCoreReportArtifacts = artifacts
    , frameworkCoreReportFailures = failures
    }
  where
    constraints =
      constraintReport plan
    facts =
      factClosureReport plan runtimeFacts
    handlers =
      handlerCoverageReport plan bootstrapRuntimeEffectEnvironment
    runtimeFacts =
      case runtimeResult of
        Right runtime ->
          availableFacts runtime
        Left _ ->
          []
    artifacts =
      case runtimeResult of
        Right runtime ->
          runtimeArtifacts runtime
        Left _ ->
          []
    failures =
      case runtimeResult of
        Right runtime ->
          runtimeFailures runtime
        Left message ->
          [message]
    status =
      reportStatus plan runtimeResult constraints facts handlers

failedBuildReport :: String -> FrameworkCoreReport
failedBuildReport message =
  FrameworkCoreReport
    { frameworkCoreReportName = "framework-core"
    , frameworkCoreReportStatus = FrameworkCoreReportFailed [message]
    , frameworkCoreReportSurfaceModules = coreSurfaceModuleCount
    , frameworkCoreReportSurfaceCapabilities = coreSurfaceCapabilityCount
    , frameworkCoreReportConstraints = ConstraintReport 0 0 []
    , frameworkCoreReportFactClosure = FactClosureReport [] [] [] [] [] [] []
    , frameworkCoreReportHandlerCoverage = []
    , frameworkCoreReportArtifacts = []
    , frameworkCoreReportFailures = [message]
    }

constraintReport :: NativeAppPlan -> ConstraintReport
constraintReport plan =
  ConstraintReport
    { constraintReportTotal = length constraints
    , constraintReportPassed = length (filter nativeConstraintPassed constraints)
    , constraintReportFailed = filter (not . nativeConstraintPassed) constraints
    }
  where
    constraints =
      nativeAppPlanConstraints plan

factClosureReport :: NativeAppPlan -> [WorkflowFact] -> FactClosureReport
factClosureReport plan finalFacts =
  FactClosureReport
    { factClosureDeclaredFacts = declaredFacts
    , factClosureRootFacts = nativeAppPlanRootFacts plan
    , factClosurePlannedRuntimeFacts = plannedFacts
    , factClosureFinalRuntimeFacts = finalFacts
    , factClosureDeclaredOutsideRuntime = declaredFacts `minus` plannedFacts
    , factClosureMissingFinalFacts = plannedFacts `minus` finalFacts
    , factClosureExtraFinalFacts = finalFacts `minus` plannedFacts
    }
  where
    declaredFacts =
      nativeAppPlanFacts plan
    plannedFacts =
      plannedRuntimeFacts plan

handlerCoverageReport :: NativeAppPlan -> RuntimeEffectEnvironment -> [HandlerCoverage]
handlerCoverageReport plan environment =
  [ HandlerCoverage
      { handlerCoverageSend = currentSend
      , handlerCoverageHandlers = map (show . handlerBindingName) handlers
      , handlerCoverageCovered = not (null handlers)
      }
  | currentSend <- nativeAppPlanSendBoundaries plan
  , let handlers = handlersFor registry currentSend
  ]
  where
    registry =
      runtimeEffectHandlers environment

handlersFor :: HandlerRegistry -> SendName -> [HandlerBinding]
handlersFor registry currentSend =
  [ binding
  | binding <- handlerRegistryBindings registry
  , handlerBindingSend binding == currentSend
  ]

reportStatus ::
  NativeAppPlan ->
  Either String NativeRuntime ->
  ConstraintReport ->
  FactClosureReport ->
  [HandlerCoverage] ->
  FrameworkCoreReportStatus
reportStatus plan runtimeResult constraints facts handlers =
  case reportProblems plan runtimeResult constraints facts handlers of
    [] ->
      FrameworkCoreReportPassed
    problems ->
      FrameworkCoreReportFailed problems

reportProblems ::
  NativeAppPlan ->
  Either String NativeRuntime ->
  ConstraintReport ->
  FactClosureReport ->
  [HandlerCoverage] ->
  [String]
reportProblems _ runtimeResult constraints facts handlers =
  constraintProblems
    ++ runtimeProblems
    ++ handlerProblems
    ++ factProblems
    ++ reportPublicationProblems
  where
    constraintProblems =
      [ "failed native constraints: " ++ show (length (constraintReportFailed constraints))
      | not (null (constraintReportFailed constraints))
      ]
    runtimeProblems =
      case runtimeResult of
        Left message ->
          ["runtime failed: " ++ message]
        Right runtime ->
          runtimeFailures runtime
    handlerProblems =
      [ "missing handler for " ++ show (handlerCoverageSend coverage)
      | coverage <- handlers
      , not (handlerCoverageCovered coverage)
      ]
    factProblems =
      [ "runtime closure missing facts: " ++ show (factClosureMissingFinalFacts facts)
      | not (null (factClosureMissingFinalFacts facts))
      ]
        ++
      [ "runtime closure produced extra facts: " ++ show (factClosureExtraFinalFacts facts)
      | not (null (factClosureExtraFinalFacts facts))
      ]
    reportPublicationProblems =
      [ "framework report fact was not published"
      | FrameworkCoreReportPublishedFact `notElem` factClosureFinalRuntimeFacts facts
      ]

plannedRuntimeFacts :: NativeAppPlan -> [WorkflowFact]
plannedRuntimeFacts plan =
  closeFacts [] (nativeAppPlanRootFacts plan)
  where
    closeFacts seen [] =
      seen
    closeFacts seen (currentFact : rest)
      | currentFact `elem` seen =
          closeFacts seen rest
      | otherwise =
          case nativeRuleFor plan currentFact of
            Nothing ->
              closeFacts (seen ++ [currentFact]) rest
            Just rule ->
              closeFacts
                (seen ++ [currentFact])
                ( rest
                    ++ nativeRuleNeeds rule
                    ++ sourceFactsForTakes plan rule
                )

sourceFactsForTakes :: NativeAppPlan -> NativeFactRule -> [WorkflowFact]
sourceFactsForTakes plan rule =
  unique
    [ nativeRuleFact sourceRule
    | currentType <- nativeRuleTakes rule
    , sourceRule <- nativeAppPlanFactRules plan
    , currentType `elem` nativeRuleMakes sourceRule
    ]

nativeRuleFor :: NativeAppPlan -> WorkflowFact -> Maybe NativeFactRule
nativeRuleFor plan currentFact =
  firstJust
    [ Just rule
    | rule <- nativeAppPlanFactRules plan
    , nativeRuleFact rule == currentFact
    ]

renderStatus :: FrameworkCoreReportStatus -> String
renderStatus FrameworkCoreReportPassed =
  "passed"
renderStatus (FrameworkCoreReportFailed _) =
  "failed"

renderFailedConstraints :: [NativeConstraint] -> [String]
renderFailedConstraints [] =
  []
renderFailedConstraints constraints =
  "  failed constraints:"
    : indentLines
      4
      [ nativeConstraintName constraint ++ ": " ++ nativeConstraintMessage constraint
      | constraint <- constraints
      ]

renderNamedFacts :: String -> [WorkflowFact] -> [String]
renderNamedFacts _ [] =
  []
renderNamedFacts label facts =
  ("  " ++ label ++ ":")
    : indentLines 4 (map show facts)

renderMissingHandlers :: [HandlerCoverage] -> [String]
renderMissingHandlers coverage =
  case filter (not . handlerCoverageCovered) coverage of
    [] ->
      []
    missing ->
      "  missing handlers:"
        : indentLines 4 (map (show . handlerCoverageSend) missing)

renderArtifacts :: [RuntimeArtifact] -> [String]
renderArtifacts artifacts =
  [ "runtime artifacts:"
  , "  total: " ++ show (length artifacts)
  ]

renderFailures :: [String] -> [String]
renderFailures [] =
  []
renderFailures failures =
  "failures:"
    : indentLines 2 failures

minus :: Eq item => [item] -> [item] -> [item]
minus left right =
  [ item
  | item <- left
  , item `notElem` right
  ]

unique :: Eq item => [item] -> [item]
unique =
  foldl appendUnique []

appendUnique :: Eq item => [item] -> item -> [item]
appendUnique items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (current : rest) =
  case current of
    Just item ->
      Just item
    Nothing ->
      firstJust rest

indentLines :: Int -> [String] -> [String]
indentLines count =
  map (replicate count ' ' ++)
