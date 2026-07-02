module Framework.Domain
  ( DomainHandlerCoverage (..)
  , DomainReport (..)
  , DomainReportStatus (..)
  , DomainRegistration (..)
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
import Bootstrap.Runtime
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , NativeAppPlan (..)
  , NativeConstraint (..)
  , NativeFactRule (..)
  , NativeRuntime (..)
  , RuntimeArtifact (..)
  , RuntimeEffectEnvironment (..)
  , buildNativeApp
  , runNativeBlueprintWithEffectEnvironmentResult
  )
import Bootstrap.Workflow
  ( AppBlueprint
  , WorkflowFact
  )
import Domain.Ast
  ( AstRegistration (..)
  )
import Domain.EffectHandlers
  ( EffectHandlerRegistration (..)
  )
import Domain.Effects
  ( EffectRegistration (..)
  )
import Domain.Interpreter
  ( InterpreterRegistration
  , runtimeInterpreter
  )
import Domain.Registry
  ( DomainRegistration (..)
  , frameworkCoreDomain
  , runDomain
  )

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

domain ::
  String ->
  AppBlueprint ->
  EffectTheory ->
  RuntimeEffectEnvironment ->
  InterpreterRegistration ->
  DomainRegistration
domain name ast effects handlers interpreter =
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
        EffectHandlerRegistration
          { effectHandlerRegistrationName = name ++ "-runtime"
          , effectHandlerEnvironment = handlers
          , effectHandlerRegistry = runtimeEffectHandlers handlers
          , effectHandlerTransforms = runtimeEffectTransforms handlers
          }
    , domainInterpreter = interpreter
    }

domainWithRuntime ::
  String ->
  AppBlueprint ->
  EffectTheory ->
  RuntimeEffectEnvironment ->
  DomainRegistration
domainWithRuntime name ast effects handlers =
  domain name ast effects handlers runtimeInterpreter

frameworkCoreFacadeDomain :: DomainRegistration
frameworkCoreFacadeDomain =
  frameworkCoreDomain
    { domainRegistrationName = "framework-core-stage1"
    }

buildDomainReport :: DomainRegistration -> IO DomainReport
buildDomainReport registration =
  case buildNativeApp blueprint effects of
    Left message ->
      pure (failedDomainReport (domainRegistrationName registration) message)
    Right plan -> do
      runtimeResult <-
        runNativeBlueprintWithEffectEnvironmentResult
          environment
          effects
          blueprint
      pure (domainReportFromPlan registration plan runtimeResult)
  where
    blueprint =
      astRegistrationBlueprint (domainAst registration)
    effects =
      effectRegistrationTheory (domainEffects registration)
    environment =
      effectHandlerEnvironment (domainEffectHandlers registration)

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

domainReportFromPlan :: DomainRegistration -> NativeAppPlan -> Either String NativeRuntime -> DomainReport
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
        Right runtime ->
          availableFacts runtime
        Left _ ->
          []
    missingFinal =
      plannedFacts `minus` finalFacts
    extraFinal =
      finalFacts `minus` plannedFacts
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
    coverage =
      handlerCoverageReport plan (effectHandlerEnvironment (domainEffectHandlers registration))

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
  Either String NativeRuntime ->
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
        Left message ->
          ["runtime failed: " ++ message]
        Right runtime ->
          runtimeFailures runtime
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

handlerCoverageReport :: NativeAppPlan -> RuntimeEffectEnvironment -> [DomainHandlerCoverage]
handlerCoverageReport plan environment =
  [ DomainHandlerCoverage
      { domainHandlerCoverageSend = currentSend
      , domainHandlerCoverageHandlers = map (show . handlerBindingName) handlers
      , domainHandlerCoverageCovered = not (null handlers)
      }
  | currentSend <- nativeAppPlanSendBoundaries plan
  , let handlers = handlersFor (runtimeEffectHandlers environment) currentSend
  ]

handlersFor :: HandlerRegistry -> SendName -> [HandlerBinding]
handlersFor registry currentSend =
  [ binding
  | binding <- handlerRegistryBindings registry
  , handlerBindingSend binding == currentSend
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
