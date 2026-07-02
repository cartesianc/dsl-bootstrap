module Framework.Domain
  ( DomainEffectHandlerRegistration (..)
  , DomainHandlerCoverage (..)
  , DomainReport (..)
  , DomainReportStatus (..)
  , DomainRegistration (..)
  , DomainRuntimeBackend (..)
  , buildDomainReport
  , domain
  , domainWithRuntime
  , frameworkCoreDomain
  , frameworkCoreFacadeDomain
  , renderDomainReport
  , runDomain
  ) where

import Bootstrap.CoreSurface
  ( coreSurfaceCapabilityCount
  , coreSurfaceModuleCount
  )
import Bootstrap.Effect
  ( EffectTheory
  , SendName
  )
import qualified Bootstrap.Runtime as Native
import Bootstrap.Runtime
  ( NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , RuntimeArtifact (..)
  , buildNativeApp
  )
import Bootstrap.Workflow
  ( AppBlueprint
  , WorkflowFact
  )
import Domain.Ast
  ( AstRegistration (..)
  )
import Domain.Effects
  ( EffectRegistration (..)
  )
import qualified Domain.EffectHandlers as RegistryHandlers
import qualified Domain.Interpreter as RegistryInterpreter
import qualified Domain.Registry as Registry
import qualified Framework.Runtime as Runtime

data DomainRuntimeBackend
  = DomainNativeRuntime Native.RuntimeEffectEnvironment
  | DomainFrameworkRuntime Runtime.RuntimeEffectEnvironment

data DomainEffectHandlerRegistration = DomainEffectHandlerRegistration
  { effectHandlerRegistrationName :: String
  , effectHandlerRuntime :: DomainRuntimeBackend
  }

data DomainRegistration = DomainRegistration
  { domainRegistrationName :: String
  , domainAst :: AstRegistration
  , domainEffects :: EffectRegistration
  , domainEffectHandlers :: DomainEffectHandlerRegistration
  , domainInterpreterName :: String
  }

data DomainReport = DomainReport
  { domainReportName :: String
  , domainReportStatus :: DomainReportStatus
  , domainReportSurfaceModules :: Int
  , domainReportSurfaceCapabilities :: Int
  , domainReportConstraintTotal :: Int
  , domainReportConstraintPassed :: Int
  , domainReportConstraintFailed :: Int
  , domainReportDeclaredFacts :: [WorkflowFact]
  , domainReportRootFacts :: [WorkflowFact]
  , domainReportPlannedRuntimeFacts :: [WorkflowFact]
  , domainReportFinalRuntimeFacts :: [WorkflowFact]
  , domainReportMissingFinalFacts :: [WorkflowFact]
  , domainReportExtraFinalFacts :: [WorkflowFact]
  , domainReportHandlerCoverage :: [DomainHandlerCoverage]
  , domainReportArtifacts :: [RuntimeArtifact]
  , domainReportFailures :: [String]
  }

data DomainReportStatus
  = DomainReportPassed
  | DomainReportFailed [String]
  deriving (Eq, Show)

data DomainHandlerCoverage = DomainHandlerCoverage
  { domainHandlerCoverageSend :: SendName
  , domainHandlerCoverageHandlers :: [String]
  , domainHandlerCoverageCovered :: Bool
  }

data DomainRuntimeResult
  = DomainRuntimeSucceeded [WorkflowFact] [RuntimeArtifact] [String]
  | DomainRuntimeFailed String

domain ::
  String ->
  AppBlueprint ->
  EffectTheory ->
  Runtime.RuntimeEffectEnvironment ->
  DomainRegistration
domain =
  domainWithRuntime

domainWithRuntime ::
  String ->
  AppBlueprint ->
  EffectTheory ->
  Runtime.RuntimeEffectEnvironment ->
  DomainRegistration
domainWithRuntime name ast effects handlers =
  DomainRegistration
    { domainRegistrationName = name
    , domainAst =
        AstRegistration
          { astRegistrationName = name
          , astRegistrationBlueprint = ast
          }
    , domainEffects =
        EffectRegistration
          { effectRegistrationName = name
          , effectRegistrationTheory = effects
          }
    , domainEffectHandlers =
        DomainEffectHandlerRegistration
          { effectHandlerRegistrationName = name ++ "-runtime"
          , effectHandlerRuntime = DomainFrameworkRuntime handlers
          }
    , domainInterpreterName = "runtime"
    }

frameworkCoreDomain :: DomainRegistration
frameworkCoreDomain =
  nativeDomainFromRegistry "framework-core" Registry.frameworkCoreDomain

frameworkCoreFacadeDomain :: DomainRegistration
frameworkCoreFacadeDomain =
  nativeDomainFromRegistry "framework-core-stage1" Registry.frameworkCoreDomain

nativeDomainFromRegistry :: String -> Registry.DomainRegistration -> DomainRegistration
nativeDomainFromRegistry name registration =
  DomainRegistration
    { domainRegistrationName = name
    , domainAst = Registry.domainAst registration
    , domainEffects = Registry.domainEffects registration
    , domainEffectHandlers =
        DomainEffectHandlerRegistration
          { effectHandlerRegistrationName =
              RegistryHandlers.effectHandlerRegistrationName
                (Registry.domainEffectHandlers registration)
          , effectHandlerRuntime =
              DomainNativeRuntime
                (RegistryHandlers.effectHandlerEnvironment (Registry.domainEffectHandlers registration))
          }
    , domainInterpreterName =
        RegistryInterpreter.interpreterRegistrationName (Registry.domainInterpreter registration)
    }

runDomain :: DomainRegistration -> IO ()
runDomain registration =
  case effectHandlerRuntime (domainEffectHandlers registration) of
    DomainNativeRuntime environment ->
      Native.runNativeBlueprintWithEffectEnvironment environment effects blueprint
    DomainFrameworkRuntime environment ->
      Runtime.runBlueprintWithEffectEnvironment environment effects blueprint
  where
    blueprint =
      astRegistrationBlueprint (domainAst registration)
    effects =
      effectRegistrationTheory (domainEffects registration)

buildDomainReport :: DomainRegistration -> IO DomainReport
buildDomainReport registration =
  case buildNativeApp blueprint effects of
    Left message ->
      pure (failedDomainReport (domainRegistrationName registration) message)
    Right plan -> do
      runtimeResult <- runDomainRuntime (effectHandlerRuntime (domainEffectHandlers registration)) effects blueprint
      pure (domainReportFromPlan registration plan runtimeResult)
  where
    blueprint =
      astRegistrationBlueprint (domainAst registration)
    effects =
      effectRegistrationTheory (domainEffects registration)

renderDomainReport :: DomainReport -> [String]
renderDomainReport report =
  [ "domain report"
  , "domain: " ++ domainReportName report
  , "status: " ++ renderDomainStatus (domainReportStatus report)
  , "surface modules: " ++ show (domainReportSurfaceModules report)
  , "surface capabilities: " ++ show (domainReportSurfaceCapabilities report)
  , "constraints:"
  , "  total: " ++ show (domainReportConstraintTotal report)
  , "  passed: " ++ show (domainReportConstraintPassed report)
  , "  failed: " ++ show (domainReportConstraintFailed report)
  , "fact closure:"
  , "  declared facts: " ++ show (length (domainReportDeclaredFacts report))
  , "  root facts: " ++ show (length (domainReportRootFacts report))
  , "  planned runtime facts: " ++ show (length (domainReportPlannedRuntimeFacts report))
  , "  final runtime facts: " ++ show (length (domainReportFinalRuntimeFacts report))
  , "  missing final facts: " ++ show (length (domainReportMissingFinalFacts report))
  , "  extra final facts: " ++ show (length (domainReportExtraFinalFacts report))
  , "handler coverage:"
  , "  send boundaries: " ++ show (length (domainReportHandlerCoverage report))
  , "  covered: " ++ show (length (filter domainHandlerCoverageCovered (domainReportHandlerCoverage report)))
  , "  missing: " ++ show (length (filter (not . domainHandlerCoverageCovered) (domainReportHandlerCoverage report)))
  , "runtime artifacts:"
  , "  total: " ++ show (length (domainReportArtifacts report))
  ]
    ++ renderFailures (domainReportFailures report)

runDomainRuntime ::
  DomainRuntimeBackend ->
  EffectTheory ->
  AppBlueprint ->
  IO DomainRuntimeResult
runDomainRuntime backend effects blueprint =
  case backend of
    DomainNativeRuntime environment -> do
      result <- Native.runNativeBlueprintWithEffectEnvironmentResult environment effects blueprint
      pure
        ( case result of
            Left message ->
              DomainRuntimeFailed message
            Right runtime ->
              DomainRuntimeSucceeded
                (Native.availableFacts runtime)
                (Native.runtimeArtifacts runtime)
                (Native.runtimeFailures runtime)
        )
    DomainFrameworkRuntime environment -> do
      result <- Runtime.runBlueprintWithEffectEnvironmentResult environment effects blueprint
      pure
        ( case result of
            Left errorReport ->
              DomainRuntimeFailed (Runtime.renderRuntimeError errorReport)
            Right runtime ->
              DomainRuntimeSucceeded
                (Runtime.availableFacts runtime)
                (frameworkRuntimeArtifacts runtime)
                []
        )

frameworkRuntimeArtifacts :: Runtime.Runtime -> [RuntimeArtifact]
frameworkRuntimeArtifacts runtime =
  [ RuntimeArtifact
      { artifactType = Runtime.runtimeValueType currentValue
      , artifactText = Runtime.runtimeValueText currentValue
      }
  | currentValue <- Runtime.runtimeValues runtime
  ]

domainReportFromPlan :: DomainRegistration -> NativeAppPlan -> DomainRuntimeResult -> DomainReport
domainReportFromPlan registration plan runtimeResult =
  DomainReport
    { domainReportName = domainRegistrationName registration
    , domainReportStatus = reportStatus runtimeResult failedConstraints missingFinal extraFinal coverage
    , domainReportSurfaceModules = coreSurfaceModuleCount
    , domainReportSurfaceCapabilities = coreSurfaceCapabilityCount
    , domainReportConstraintTotal = length constraints
    , domainReportConstraintPassed = length (filter nativeConstraintPassed constraints)
    , domainReportConstraintFailed = length failedConstraints
    , domainReportDeclaredFacts = nativeAppPlanFacts plan
    , domainReportRootFacts = nativeAppPlanRootFacts plan
    , domainReportPlannedRuntimeFacts = plannedFacts
    , domainReportFinalRuntimeFacts = finalFacts
    , domainReportMissingFinalFacts = missingFinal
    , domainReportExtraFinalFacts = extraFinal
    , domainReportHandlerCoverage = coverage
    , domainReportArtifacts = artifacts
    , domainReportFailures = failures
    }
  where
    constraints =
      nativeAppPlanConstraints plan
    failedConstraints =
      filter (not . nativeConstraintPassed) constraints
    plannedFacts =
      plannedRuntimeFacts plan
    finalFacts =
      case runtimeResult of
        DomainRuntimeSucceeded facts _ _ ->
          facts
        DomainRuntimeFailed _ ->
          []
    missingFinal =
      plannedFacts `minus` finalFacts
    extraFinal =
      finalFacts `minus` plannedFacts
    artifacts =
      case runtimeResult of
        DomainRuntimeSucceeded _ currentArtifacts _ ->
          currentArtifacts
        DomainRuntimeFailed _ ->
          []
    failures =
      case runtimeResult of
        DomainRuntimeSucceeded _ _ runtimeFailures ->
          runtimeFailures
        DomainRuntimeFailed message ->
          [message]
    coverage =
      handlerCoverageReport plan (effectHandlerRuntime (domainEffectHandlers registration))

failedDomainReport :: String -> String -> DomainReport
failedDomainReport name message =
  DomainReport
    { domainReportName = name
    , domainReportStatus = DomainReportFailed [message]
    , domainReportSurfaceModules = coreSurfaceModuleCount
    , domainReportSurfaceCapabilities = coreSurfaceCapabilityCount
    , domainReportConstraintTotal = 0
    , domainReportConstraintPassed = 0
    , domainReportConstraintFailed = 0
    , domainReportDeclaredFacts = []
    , domainReportRootFacts = []
    , domainReportPlannedRuntimeFacts = []
    , domainReportFinalRuntimeFacts = []
    , domainReportMissingFinalFacts = []
    , domainReportExtraFinalFacts = []
    , domainReportHandlerCoverage = []
    , domainReportArtifacts = []
    , domainReportFailures = [message]
    }

reportStatus ::
  DomainRuntimeResult ->
  [constraint] ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  [DomainHandlerCoverage] ->
  DomainReportStatus
reportStatus runtimeResult failedConstraints missingFinal extraFinal coverage =
  case problems of
    [] ->
      DomainReportPassed
    _ ->
      DomainReportFailed problems
  where
    problems =
      constraintProblems
        ++ runtimeProblems
        ++ factProblems
        ++ handlerProblems
    constraintProblems =
      [ "failed native constraints: " ++ show (length failedConstraints)
      | not (null failedConstraints)
      ]
    runtimeProblems =
      case runtimeResult of
        DomainRuntimeFailed message ->
          ["runtime failed: " ++ message]
        DomainRuntimeSucceeded _ _ runtimeFailures ->
          runtimeFailures
    factProblems =
      [ "runtime closure missing facts: " ++ show missingFinal
      | not (null missingFinal)
      ]
        ++
      [ "runtime closure produced extra facts: " ++ show extraFinal
      | not (null extraFinal)
      ]
    handlerProblems =
      [ "missing handler for " ++ show (domainHandlerCoverageSend currentCoverage)
      | currentCoverage <- coverage
      , not (domainHandlerCoverageCovered currentCoverage)
      ]

handlerCoverageReport :: NativeAppPlan -> DomainRuntimeBackend -> [DomainHandlerCoverage]
handlerCoverageReport plan backend =
  case backend of
    DomainNativeRuntime environment ->
      nativeHandlerCoverageReport plan environment
    DomainFrameworkRuntime environment ->
      frameworkHandlerCoverageReport plan environment

nativeHandlerCoverageReport :: NativeAppPlan -> Native.RuntimeEffectEnvironment -> [DomainHandlerCoverage]
nativeHandlerCoverageReport plan environment =
  [ DomainHandlerCoverage
      { domainHandlerCoverageSend = currentSend
      , domainHandlerCoverageHandlers = map (show . Native.handlerBindingName) handlers
      , domainHandlerCoverageCovered = not (null handlers)
      }
  | currentSend <- nativeAppPlanSendBoundaries plan
  , let handlers = nativeHandlersFor (Native.runtimeEffectHandlers environment) currentSend
  ]

frameworkHandlerCoverageReport :: NativeAppPlan -> Runtime.RuntimeEffectEnvironment -> [DomainHandlerCoverage]
frameworkHandlerCoverageReport plan environment =
  [ DomainHandlerCoverage
      { domainHandlerCoverageSend = currentSend
      , domainHandlerCoverageHandlers = map (show . Runtime.handlerBindingName) handlers
      , domainHandlerCoverageCovered = not (null handlers)
      }
  | currentSend <- nativeAppPlanSendBoundaries plan
  , let handlers = frameworkHandlersFor (Runtime.runtimeEffectHandlers environment) currentSend
  ]

nativeHandlersFor :: Native.HandlerRegistry -> SendName -> [Native.HandlerBinding]
nativeHandlersFor registry currentSend =
  [ binding
  | binding <- Native.handlerRegistryBindings registry
  , Native.handlerBindingSend binding == currentSend
  ]

frameworkHandlersFor :: Runtime.HandlerRegistry -> SendName -> [Runtime.HandlerBinding]
frameworkHandlersFor registry currentSend =
  [ binding
  | binding <- Runtime.handlerRegistryBindings registry
  , Runtime.handlerBindingSend binding == currentSend
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

renderDomainStatus :: DomainReportStatus -> String
renderDomainStatus DomainReportPassed =
  "passed"
renderDomainStatus (DomainReportFailed _) =
  "failed"

renderFailures :: [String] -> [String]
renderFailures [] =
  []
renderFailures failures =
  "failures:" : map ("  " ++) failures

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
