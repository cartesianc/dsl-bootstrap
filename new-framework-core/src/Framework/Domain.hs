{-# LANGUAGE PatternSynonyms #-}

module Framework.Domain
  ( DomainEffectHandlerRegistration (..)
  , DomainHandlerCoverage (..)
  , DomainReport (..)
  , DomainReportStatus (..)
  , DomainRegistration (..)
  , DomainRuntimeBackend (..)
  , pattern DomainFrameworkRuntime
  , pattern DomainNativeRuntime
  , DomainSemanticCheck (..)
  , DomainSemanticEvidence (..)
  , DomainSemanticEvidenceStatus (..)
  , buildDomainReport
  , domain
  , domainEvidenceFailed
  , domainEvidencePassed
  , domainReportSemanticEvidencePassed
  , domainSemanticEvidencePassed
  , domainWithRuntimeAndEvidence
  , domainWithRuntime
  , frameworkCoreDomain
  , frameworkCoreFacadeDomain
  , renderDomainReport
  , renderDomainReportJson
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
  , WorkflowFact (..)
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
import qualified Framework.Background.ConstraintProof as Proof
import qualified Framework.Runtime.Interpreter as Runtime

data DomainRuntimeBackend
  = DomainBootstrapBackend Native.RuntimeEffectEnvironment
  | DomainTypedRuntimeBackend Runtime.RuntimeEffectEnvironment

pattern DomainNativeRuntime :: Native.RuntimeEffectEnvironment -> DomainRuntimeBackend
pattern DomainNativeRuntime environment = DomainBootstrapBackend environment

pattern DomainFrameworkRuntime :: Runtime.RuntimeEffectEnvironment -> DomainRuntimeBackend
pattern DomainFrameworkRuntime environment = DomainTypedRuntimeBackend environment

{-# COMPLETE DomainBootstrapBackend, DomainTypedRuntimeBackend #-}

data DomainEffectHandlerRegistration = DomainEffectHandlerRegistration
  { effectHandlerRegistrationName :: String
  , effectHandlerRuntime :: DomainRuntimeBackend
  }

data DomainSemanticCheck = DomainSemanticCheck
  { domainSemanticCheckName :: String
  , runDomainSemanticCheck :: DomainRegistration -> NativeAppPlan -> IO DomainSemanticEvidence
  }

data DomainSemanticEvidence = DomainSemanticEvidence
  { domainSemanticEvidenceName :: String
  , domainSemanticEvidenceStatus :: DomainSemanticEvidenceStatus
  , domainSemanticEvidenceDetails :: [String]
  }

data DomainSemanticEvidenceStatus
  = DomainSemanticEvidencePassed
  | DomainSemanticEvidenceFailed
  deriving (Eq, Show)

data DomainRegistration = DomainRegistration
  { domainRegistrationName :: String
  , domainAst :: AstRegistration
  , domainEffects :: EffectRegistration
  , domainEffectHandlers :: DomainEffectHandlerRegistration
  , domainInterpreterName :: String
  , domainSemanticChecks :: [DomainSemanticCheck]
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
  , domainReportProofResults :: [Proof.SmtResult]
  , domainReportSemanticEvidence :: [DomainSemanticEvidence]
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
  domainWithRuntimeAndEvidence name ast effects handlers []

domainWithRuntimeAndEvidence ::
  String ->
  AppBlueprint ->
  EffectTheory ->
  Runtime.RuntimeEffectEnvironment ->
  [DomainSemanticCheck] ->
  DomainRegistration
domainWithRuntimeAndEvidence name ast effects handlers semanticChecks =
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
          , effectHandlerRuntime = DomainTypedRuntimeBackend handlers
          }
    , domainInterpreterName = "runtime"
    , domainSemanticChecks = semanticChecks
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
              DomainBootstrapBackend
                (RegistryHandlers.effectHandlerEnvironment (Registry.domainEffectHandlers registration))
          }
    , domainInterpreterName =
        RegistryInterpreter.interpreterRegistrationName (Registry.domainInterpreter registration)
    , domainSemanticChecks = []
    }

runDomain :: DomainRegistration -> IO ()
runDomain registration =
  case effectHandlerRuntime (domainEffectHandlers registration) of
    DomainBootstrapBackend environment ->
      Native.runNativeBlueprintWithEffectEnvironment environment effects blueprint
    DomainTypedRuntimeBackend environment ->
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
      let proofResults =
            domainProofResults blueprint effects plan
      semanticEvidence <-
        domainSemanticEvidence
          registration
          blueprint
          effects
          plan
          proofResults
          runtimeResult
      pure (domainReportFromPlan registration plan proofResults semanticEvidence runtimeResult)
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
    ++ renderProofResults (domainReportProofResults report)
    ++ renderSemanticEvidence (domainReportSemanticEvidence report)
    ++ renderFailures (domainReportFailures report)

renderDomainReportJson :: DomainReport -> String
renderDomainReportJson report =
  jsonObject
    [ jsonField "schema" (jsonString "domain-report.v1")
    , jsonField "domain" (jsonString (domainReportName report))
    , jsonField "status" (jsonString (renderDomainStatus (domainReportStatus report)))
    , jsonField "surfaceModules" (jsonNumber (domainReportSurfaceModules report))
    , jsonField "surfaceCapabilities" (jsonNumber (domainReportSurfaceCapabilities report))
    , jsonField "constraints" (domainConstraintsJson report)
    , jsonField "factClosure" (domainFactClosureJson report)
    , jsonField "handlerCoverage" (jsonArray (map domainHandlerCoverageJson (domainReportHandlerCoverage report)))
    , jsonField "runtimeArtifacts" (jsonArray (map runtimeArtifactJson (domainReportArtifacts report)))
    , jsonField "proof" (jsonArray (map proofResultJson (domainReportProofResults report)))
    , jsonField "semanticEvidence" (jsonArray (map semanticEvidenceJson (domainReportSemanticEvidence report)))
    , jsonField "failures" (jsonStringArray (domainReportFailures report))
    ]

runDomainRuntime ::
  DomainRuntimeBackend ->
  EffectTheory ->
  AppBlueprint ->
  IO DomainRuntimeResult
runDomainRuntime backend effects blueprint =
  case backend of
    DomainBootstrapBackend environment -> do
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
    DomainTypedRuntimeBackend environment -> do
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

domainReportFromPlan :: DomainRegistration -> NativeAppPlan -> [Proof.SmtResult] -> [DomainSemanticEvidence] -> DomainRuntimeResult -> DomainReport
domainReportFromPlan registration plan proofResults semanticEvidence runtimeResult =
  DomainReport
    { domainReportName = domainRegistrationName registration
    , domainReportStatus = reportStatus runtimeResult failedConstraints missingFinal extraFinal coverage proofResults semanticEvidence
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
    , domainReportProofResults = proofResults
    , domainReportSemanticEvidence = semanticEvidence
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
domainProofResults :: AppBlueprint -> EffectTheory -> NativeAppPlan -> [Proof.SmtResult]
domainProofResults blueprint effects plan =
  case Proof.constraintsFromAppPlan blueprint effects of
    Right constraints ->
      Proof.proveMinimalCore constraints
    Left _ ->
      Proof.proveMinimalCore (Proof.constraintsFromNativeAppPlan plan)

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
    , domainReportProofResults = []
    , domainReportSemanticEvidence = []
    , domainReportFailures = [message]
    }

reportStatus ::
  DomainRuntimeResult ->
  [constraint] ->
  [WorkflowFact] ->
  [WorkflowFact] ->
  [DomainHandlerCoverage] ->
  [Proof.SmtResult] ->
  [DomainSemanticEvidence] ->
  DomainReportStatus
reportStatus runtimeResult failedConstraints missingFinal extraFinal coverage proofResults semanticEvidence =
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
        ++ proofProblems
        ++ semanticEvidenceProblems
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
    proofProblems =
      [ "failed proof propositions: " ++ show (length failedProofs)
      | not (null failedProofs)
      ]
    failedProofs =
      [ result
      | result <- proofResults
      , Proof.smtResultStatus result == Proof.SmtFailed
      ]
    semanticEvidenceProblems =
      [ "failed semantic evidence: " ++ domainSemanticEvidenceName evidence
      | evidence <- semanticEvidence
      , not (domainSemanticEvidencePassed evidence)
      ]

domainSemanticEvidence ::
  DomainRegistration ->
  AppBlueprint ->
  EffectTheory ->
  NativeAppPlan ->
  [Proof.SmtResult] ->
  DomainRuntimeResult ->
  IO [DomainSemanticEvidence]
domainSemanticEvidence registration blueprint effects plan proofResults runtimeResult = do
  customEvidence <-
    mapM
      (\currentCheck -> runDomainSemanticCheck currentCheck registration plan)
      (domainSemanticChecks registration)
  pure
    ( builtInDomainSemanticEvidence blueprint effects plan proofResults runtimeResult
        ++ customEvidence
    )

builtInDomainSemanticEvidence ::
  AppBlueprint ->
  EffectTheory ->
  NativeAppPlan ->
  [Proof.SmtResult] ->
  DomainRuntimeResult ->
  [DomainSemanticEvidence]
builtInDomainSemanticEvidence blueprint effects plan proofResults runtimeResult =
  [ constraintIrBuiltEvidence constraints
  , pureSmtProofEvidence proofResults
  , negativeConstraintEvidence
  , runtimeClosureEvidence runtimeResult
  ]
  where
    constraints =
      case Proof.constraintsFromAppPlan blueprint effects of
        Right currentConstraints ->
          currentConstraints
        Left _ ->
          Proof.constraintsFromNativeAppPlan plan

constraintIrBuiltEvidence :: [Proof.ConstraintFact] -> DomainSemanticEvidence
constraintIrBuiltEvidence constraints
  | null constraints =
      domainEvidenceFailed "constraint-ir-built" ["constraint fact set is empty"]
  | otherwise =
      domainEvidencePassed "constraint-ir-built" ["constraint facts: " ++ show (length constraints)]

pureSmtProofEvidence :: [Proof.SmtResult] -> DomainSemanticEvidence
pureSmtProofEvidence results
  | Proof.smtPassed results =
      domainEvidencePassed "constraint-proof-passed" ["pure propositions: " ++ show (length results)]
  | otherwise =
      domainEvidenceFailed
        "constraint-proof-passed"
        [ Proof.renderSmtResult result
        | result <- results
        , Proof.smtResultStatus result == Proof.SmtFailed
        ]

negativeConstraintEvidence :: DomainSemanticEvidence
negativeConstraintEvidence =
  if Proof.MissingFactSource missingFact `elem` errors
    then domainEvidencePassed "constraint-negative-check" ["missing fact source is detected"]
    else domainEvidenceFailed "constraint-negative-check" ["missing fact source was accepted"]
  where
    missingFact =
      WorkflowFact "SelfEvidenceMissingFact"
    errors =
      Proof.checkConstraintFacts [Proof.RequiresFact missingFact]

runtimeClosureEvidence :: DomainRuntimeResult -> DomainSemanticEvidence
runtimeClosureEvidence runtimeResult =
  case runtimeResult of
    DomainRuntimeSucceeded _ _ [] ->
      domainEvidencePassed "runtime-closure-executed" ["runtime result is successful"]
    DomainRuntimeSucceeded _ _ runtimeFailures ->
      domainEvidenceFailed "runtime-closure-executed" runtimeFailures
    DomainRuntimeFailed message ->
      domainEvidenceFailed "runtime-closure-executed" [message]

domainEvidencePassed :: String -> [String] -> DomainSemanticEvidence
domainEvidencePassed name details =
  DomainSemanticEvidence
    { domainSemanticEvidenceName = name
    , domainSemanticEvidenceStatus = DomainSemanticEvidencePassed
    , domainSemanticEvidenceDetails = details
    }

domainEvidenceFailed :: String -> [String] -> DomainSemanticEvidence
domainEvidenceFailed name details =
  DomainSemanticEvidence
    { domainSemanticEvidenceName = name
    , domainSemanticEvidenceStatus = DomainSemanticEvidenceFailed
    , domainSemanticEvidenceDetails = details
    }

domainSemanticEvidencePassed :: DomainSemanticEvidence -> Bool
domainSemanticEvidencePassed evidence =
  domainSemanticEvidenceStatus evidence == DomainSemanticEvidencePassed

domainReportSemanticEvidencePassed :: DomainReport -> Bool
domainReportSemanticEvidencePassed report =
  all domainSemanticEvidencePassed (domainReportSemanticEvidence report)

handlerCoverageReport :: NativeAppPlan -> DomainRuntimeBackend -> [DomainHandlerCoverage]
handlerCoverageReport plan backend =
  case backend of
    DomainBootstrapBackend environment ->
      nativeHandlerCoverageReport plan environment
    DomainTypedRuntimeBackend environment ->
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

renderProofResults :: [Proof.SmtResult] -> [String]
renderProofResults results =
  [ "proof:"
  , "  propositions: " ++ show (length results)
  , "  passed: " ++ show (countProofStatus Proof.SmtPassed results)
  , "  failed: " ++ show (countProofStatus Proof.SmtFailed results)
  , "  skipped: " ++ show (countProofStatus Proof.SmtSkipped results)
  ]

renderSemanticEvidence :: [DomainSemanticEvidence] -> [String]
renderSemanticEvidence evidence =
  [ "semantic evidence:"
  , "  total: " ++ show (length evidence)
  , "  passed: " ++ show (length (filter domainSemanticEvidencePassed evidence))
  , "  failed: " ++ show (length (filter (not . domainSemanticEvidencePassed) evidence))
  ]
    ++ concatMap renderSemanticEvidenceItem evidence

renderSemanticEvidenceItem :: DomainSemanticEvidence -> [String]
renderSemanticEvidenceItem evidence =
  ("  " ++ renderSemanticEvidenceStatus (domainSemanticEvidenceStatus evidence) ++ " " ++ domainSemanticEvidenceName evidence)
    : map ("    " ++) (domainSemanticEvidenceDetails evidence)

renderSemanticEvidenceStatus :: DomainSemanticEvidenceStatus -> String
renderSemanticEvidenceStatus DomainSemanticEvidencePassed =
  "passed"
renderSemanticEvidenceStatus DomainSemanticEvidenceFailed =
  "failed"

domainConstraintsJson :: DomainReport -> String
domainConstraintsJson report =
  jsonObject
    [ jsonField "total" (jsonNumber (domainReportConstraintTotal report))
    , jsonField "passed" (jsonNumber (domainReportConstraintPassed report))
    , jsonField "failed" (jsonNumber (domainReportConstraintFailed report))
    ]

domainFactClosureJson :: DomainReport -> String
domainFactClosureJson report =
  jsonObject
    [ jsonField "declaredFacts" (jsonShowArray (domainReportDeclaredFacts report))
    , jsonField "rootFacts" (jsonShowArray (domainReportRootFacts report))
    , jsonField "plannedRuntimeFacts" (jsonShowArray (domainReportPlannedRuntimeFacts report))
    , jsonField "finalRuntimeFacts" (jsonShowArray (domainReportFinalRuntimeFacts report))
    , jsonField "missingFinalFacts" (jsonShowArray (domainReportMissingFinalFacts report))
    , jsonField "extraFinalFacts" (jsonShowArray (domainReportExtraFinalFacts report))
    ]

domainHandlerCoverageJson :: DomainHandlerCoverage -> String
domainHandlerCoverageJson coverage =
  jsonObject
    [ jsonField "send" (jsonString (show (domainHandlerCoverageSend coverage)))
    , jsonField "handlers" (jsonStringArray (domainHandlerCoverageHandlers coverage))
    , jsonField "covered" (jsonBool (domainHandlerCoverageCovered coverage))
    ]

runtimeArtifactJson :: RuntimeArtifact -> String
runtimeArtifactJson artifact =
  jsonObject
    [ jsonField "type" (jsonString (show (artifactType artifact)))
    , jsonField "text" (jsonString (artifactText artifact))
    ]

proofResultJson :: Proof.SmtResult -> String
proofResultJson result =
  jsonObject
    [ jsonField "status" (jsonString (show (Proof.smtResultStatus result)))
    , jsonField "proposition" (jsonString (show (Proof.smtResultProposition result)))
    , jsonField "evidence" (jsonString (show (Proof.smtResultEvidence result)))
    ]

semanticEvidenceJson :: DomainSemanticEvidence -> String
semanticEvidenceJson evidence =
  jsonObject
    [ jsonField "name" (jsonString (domainSemanticEvidenceName evidence))
    , jsonField "status" (jsonString (renderSemanticEvidenceStatus (domainSemanticEvidenceStatus evidence)))
    , jsonField "details" (jsonStringArray (domainSemanticEvidenceDetails evidence))
    ]

countProofStatus :: Proof.SmtStatus -> [Proof.SmtResult] -> Int
countProofStatus status results =
  length
    [ result
    | result <- results
    , Proof.smtResultStatus result == status
    ]

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

jsonObject :: [String] -> String
jsonObject fields =
  "{" ++ joinWith "," fields ++ "}"

jsonField :: String -> String -> String
jsonField name value =
  jsonString name ++ ":" ++ value

jsonArray :: [String] -> String
jsonArray values =
  "[" ++ joinWith "," values ++ "]"

jsonStringArray :: [String] -> String
jsonStringArray =
  jsonArray . map jsonString

jsonShowArray :: Show item => [item] -> String
jsonShowArray =
  jsonStringArray . map show

jsonString :: String -> String
jsonString value =
  "\"" ++ concatMap jsonChar value ++ "\""

jsonChar :: Char -> String
jsonChar currentChar =
  case currentChar of
    '"' ->
      "\\\""
    '\\' ->
      "\\\\"
    '\n' ->
      "\\n"
    '\r' ->
      "\\r"
    '\t' ->
      "\\t"
    _ ->
      [currentChar]

jsonNumber :: Int -> String
jsonNumber =
  show

jsonBool :: Bool -> String
jsonBool True =
  "true"
jsonBool False =
  "false"

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
