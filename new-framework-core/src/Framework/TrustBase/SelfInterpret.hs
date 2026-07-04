module Framework.TrustBase.SelfInterpret
  ( CoreSelfInterpretEvidencePayload (..)
  , CoreSelfInterpretEvidenceStatus (..)
  , CoreSelfInterpretReport (..)
  , CoreSelfInterpretStage (..)
  , buildCoreSelfInterpretReport
  , coreSelfInterpretEvidenceClaimNames
  , coreSelfInterpretEvidencePayloadPassed
  , coreSelfInterpretBootLayout
  , coreSelfInterpretLiveBlueprint
  , coreSelfInterpretLiveContextName
  , coreSelfInterpretLiveModes
  , coreSelfInterpretReportPassed
  , emptyBusinessBlueprint
  , emptyBusinessDomain
  , emptyBusinessEffects
  , renderCoreSelfInterpretEvidencePayload
  , renderCoreSelfInterpretEvidenceStatus
  , renderCoreSelfInterpretReport
  , renderCoreSelfInterpretReportJson
  ) where

import Data.List
  ( intercalate
  , isInfixOf
  )

import Bootstrap.Effect
  ( EffectName (..)
  , EffectTheory
  , effect
  , fact
  , theory
  )
import Bootstrap.Report
  ( FactClosureReport (..)
  , FrameworkCoreReport (..)
  , FrameworkCoreReportStatus (..)
  , buildFrameworkCoreReport
  )
import Bootstrap.Workflow
  ( AppBlueprint (..)
  , EffectSystemName (..)
  , RecursionContext
  , RecursionContextName (..)
  , RecursionSchemeMode
  , WorkflowFact (..)
  , effectSystem
  , factItems
  , hangingItems
  , histoMode
  , hanging
  , listenDuringRunMode
  , paraMode
  , recursionContext
  , recursionContextAlgebra
  , recursionModel
  , renderBeforeRunMode
  , run
  , withRecursionContext
  )
import Domain.Ast
  ( AstRegistration (..) )
import Domain.Effects
  ( EffectRegistration (..) )
import Framework.Ast.Layout
  ( AstDagEquivalenceProof (..)
  , AstDagModel (..)
  , AstDagMultiplicity (..)
  , AstLayoutModel (..)
  , AstLayoutNode (..)
  , AstRuntimeCursor (..)
  , AstRuntimeNodeStatus (..)
  , AstRuntimeStatus (..)
  , AstRuntimeStatusModel (..)
  , astDagDomainAppBlueprintProjection
  , astDagEquivalenceProofPassed
  , astLayoutNodeByPath
  , astRuntimeCursorFromEvent
  , astRuntimeStatusModel
  , layoutDomainAppBlueprint
  , renderAstRuntimeCursorOnLayout
  , renderAstRuntimeStatusModel
  )
import Framework.Domain
  ( DomainRegistration (..)
  , DomainReport (..)
  , DomainReportStatus (..)
  , buildDomainReport
  , domainWithRuntimeAndEvidence
  , frameworkCoreFacadeDomain
  )
import Framework.FixedPoint
  ( FixedPointReport (..)
  , FixedPointStatus (..)
  , StageEvidence (..)
  , buildFixedPointReport
  , fixedPointPassed
  )
import Framework.SelfArtifact
  ( ArtifactCommand (..)
  , ArtifactManifest (..)
  , defaultSelfArtifactManifest
  )
import Framework.TrustBase.Manifest
  ( TrustBaseGatePolicy (..)
  , trustBaseManifestRequiredGatePolicies
  , trustBaseManifestRequiredJsonSchemas
  )
import qualified Framework.Runtime as Runtime

data CoreSelfInterpretReport = CoreSelfInterpretReport
  { coreSelfInterpretReportSchema :: String
  , coreSelfInterpretReportStatus :: CoreSelfInterpretEvidenceStatus
  , coreSelfInterpretReportStages :: [CoreSelfInterpretStage]
  , coreSelfInterpretReportPayloads :: [CoreSelfInterpretEvidencePayload]
  }
  deriving (Eq, Show)

data CoreSelfInterpretStage = CoreSelfInterpretStage
  { coreSelfInterpretStageName :: String
  , coreSelfInterpretStageStatus :: String
  , coreSelfInterpretStageSummary :: String
  }
  deriving (Eq, Show)

data CoreSelfInterpretEvidencePayload = CoreSelfInterpretEvidencePayload
  { coreSelfInterpretEvidenceClaim :: String
  , coreSelfInterpretEvidenceStatus :: CoreSelfInterpretEvidenceStatus
  , coreSelfInterpretEvidenceExpected :: String
  , coreSelfInterpretEvidenceObserved :: String
  , coreSelfInterpretEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data CoreSelfInterpretEvidenceStatus
  = CoreSelfInterpretPassed
  | CoreSelfInterpretFailed
  deriving (Eq, Show)

data CoreSelfInterpretAstProjectionEvidence = CoreSelfInterpretAstProjectionEvidence
  { coreSelfInterpretBootLayoutRootPath :: [String]
  , coreSelfInterpretBootLayoutNodeCount :: Int
  , coreSelfInterpretBootLayoutEdgeCount :: Int
  , coreSelfInterpretBootDagNodeCount :: Int
  , coreSelfInterpretBootDagOccurrenceCount :: Int
  , coreSelfInterpretBootDagSharedNodeCount :: Int
  , coreSelfInterpretBootDagMaxMultiplicity :: Int
  , coreSelfInterpretBootDagProofPassed :: Bool
  , coreSelfInterpretBootDagProofConstraintCount :: Int
  , coreSelfInterpretDefaultHangingCount :: Int
  , coreSelfInterpretLiveHangingCount :: Int
  , coreSelfInterpretLiveContextModes :: [RecursionSchemeMode]
  , coreSelfInterpretLiveRuntimePassed :: Bool
  , coreSelfInterpretLiveContextStarted :: Bool
  , coreSelfInterpretLiveContextCompleted :: Bool
  , coreSelfInterpretLiveCursorCount :: Int
  , coreSelfInterpretLiveAlignedCursorCount :: Int
  , coreSelfInterpretLiveRenderedCursorCount :: Int
  , coreSelfInterpretLiveStatusNodeCount :: Int
  , coreSelfInterpretLiveCompletedStatusCount :: Int
  , coreSelfInterpretLiveRunningStatusCount :: Int
  , coreSelfInterpretLiveUnresolvedStatusCount :: Int
  , coreSelfInterpretLiveRenderedStatusLineCount :: Int
  , coreSelfInterpretLiveRuntimeError :: Maybe String
  }
  deriving (Eq, Show)

data CoreSelfInterpretGateConsolidationEvidence = CoreSelfInterpretGateConsolidationEvidence
  { coreSelfInterpretDefaultGatePolicyNames :: [String]
  , coreSelfInterpretHighRiskGatePolicyNames :: [String]
  , coreSelfInterpretDefaultGateCommands :: [String]
  , coreSelfInterpretHighRiskGateCommands :: [String]
  , coreSelfInterpretArtifactGateCommands :: [String]
  , coreSelfInterpretDefaultGateDuplicateCommands :: [String]
  , coreSelfInterpretArtifactGateDuplicateCommands :: [String]
  , coreSelfInterpretDemotedSchemaEntries :: [String]
  }
  deriving (Eq, Show)

buildCoreSelfInterpretReport :: IO CoreSelfInterpretReport
buildCoreSelfInterpretReport = do
  previousCoreReport <- buildFrameworkCoreReport
  newCoreReport <- buildDomainReport frameworkCoreFacadeDomain
  emptyBusinessReport <- buildDomainReport emptyBusinessDomain
  fixedPointReport <- buildFixedPointReport
  astProjectionEvidence <- buildCoreSelfInterpretAstProjectionEvidence
  let gateConsolidationEvidence =
        buildCoreSelfInterpretGateConsolidationEvidence
  let corePayloads =
        coreSelfInterpretEvidencePayloads
          previousCoreReport
          newCoreReport
          emptyBusinessReport
          fixedPointReport
          astProjectionEvidence
          gateConsolidationEvidence
      payloads =
        corePayloads ++ [coreSelfInterpretClaimManifestPayload corePayloads]
      status =
        if all coreSelfInterpretEvidencePayloadPassed payloads
          then CoreSelfInterpretPassed
          else CoreSelfInterpretFailed
  pure
    CoreSelfInterpretReport
      { coreSelfInterpretReportSchema = "core-self-interpret-report.v1"
      , coreSelfInterpretReportStatus = status
      , coreSelfInterpretReportStages =
          [ previousCoreStage previousCoreReport
          , newCoreStage newCoreReport
          , emptyBusinessStage emptyBusinessReport
          , astProjectionStage astProjectionEvidence
          , gateConsolidationStage gateConsolidationEvidence
          , fixedPointStage fixedPointReport
          ]
      , coreSelfInterpretReportPayloads = payloads
      }

coreSelfInterpretReportPassed :: CoreSelfInterpretReport -> Bool
coreSelfInterpretReportPassed report =
  coreSelfInterpretReportStatus report == CoreSelfInterpretPassed
    && all coreSelfInterpretEvidencePayloadPassed (coreSelfInterpretReportPayloads report)

coreSelfInterpretEvidencePayloadPassed :: CoreSelfInterpretEvidencePayload -> Bool
coreSelfInterpretEvidencePayloadPassed payload =
  coreSelfInterpretEvidenceStatus payload == CoreSelfInterpretPassed

coreSelfInterpretEvidenceClaimNames :: [String]
coreSelfInterpretEvidenceClaimNames =
  [ "core-self-interpret-previous-core-runs-new-core"
  , "core-self-interpret-new-core-runs-as-domain"
  , "core-self-interpret-empty-business-closes-recursion"
  , "core-self-interpret-empty-business-no-io"
  , "core-self-interpret-trustbase-non-recursive"
  , "core-self-interpret-boot-ast-layout-expands"
  , "core-self-interpret-ast-dag-equivalence"
  , "core-self-interpret-live-ast-cursor-projects"
  , "core-self-interpret-live-ast-status-projects"
  , "core-self-interpret-listener-context-explicit"
  , "core-self-interpret-default-gates-collapsed"
  , "core-self-interpret-focused-witnesses-demoted"
  , "core-self-interpret-promotion-gate-isolated"
  , "core-self-interpret-artifact-gate-collapsed"
  , "core-self-interpret-core0-core1-exchangeable"
  , "core-self-interpret-fixed-point-synced"
  , "core-self-interpret-claim-manifest"
  ]

emptyBusinessDomain :: DomainRegistration
emptyBusinessDomain =
  domainWithRuntimeAndEvidence
    "empty-business"
    emptyBusinessBlueprint
    emptyBusinessEffects
    (Runtime.runtimeEffectEnvironment Runtime.emptyHandlerRegistry)
    []

emptyBusinessBlueprint :: AppBlueprint
emptyBusinessBlueprint =
  AppBlueprint
    { blueprintApp =
        run
          ( effectSystem
              (EffectSystemName "EmptyBusinessAcceptance")
              (factItems [emptyBusinessAcceptedFact])
          )
    , blueprintHanging =
        hanging []
    }

emptyBusinessEffects :: EffectTheory
emptyBusinessEffects =
  theory
    [ effect
        (EffectName "EmptyBusinessAcceptanceEffect")
        [ fact emptyBusinessAcceptedFact ]
    ]

emptyBusinessAcceptedFact :: WorkflowFact
emptyBusinessAcceptedFact =
  WorkflowFact "EmptyBusinessAcceptedFact"

coreSelfInterpretEvidencePayloads ::
  FrameworkCoreReport ->
  DomainReport ->
  DomainReport ->
  FixedPointReport ->
  CoreSelfInterpretAstProjectionEvidence ->
  CoreSelfInterpretGateConsolidationEvidence ->
  [CoreSelfInterpretEvidencePayload]
coreSelfInterpretEvidencePayloads previousCoreReport newCoreReport emptyBusinessReport fixedPointReport astProjectionEvidence gateConsolidationEvidence =
  [ coreSelfInterpretEvidence
      "core-self-interpret-previous-core-runs-new-core"
      (frameworkCoreReportPassed previousCoreReport)
      "previous compiled core interprets the new core EDSL foreground"
      (frameworkCoreReportObserved previousCoreReport)
      "PreviousCoreRunsNewCoreArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-new-core-runs-as-domain"
      (domainReportPassed newCoreReport)
      "new core foreground runs as a framework-shaped domain"
      (domainReportObserved newCoreReport)
      "NewCoreRunsAsDomainArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-empty-business-closes-recursion"
      (domainReportPassed emptyBusinessReport && emptyBusinessAcceptedFact `elem` domainReportFinalRuntimeFacts emptyBusinessReport)
      "empty Unit business closes the new_core domain parameter"
      (emptyBusinessObserved emptyBusinessReport)
      "EmptyBusinessClosureArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-empty-business-no-io"
      (null (domainReportHandlerCoverage emptyBusinessReport) && null (domainReportArtifacts emptyBusinessReport))
      "empty business has no send boundary, handler, artifact, or host IO requirement"
      (emptyBusinessIoObserved emptyBusinessReport)
      "EmptyBusinessNoIoArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-trustbase-non-recursive"
      (trustBaseBoundaryNonRecursive emptyBusinessReport)
      "TrustBase is the previous-core seed and self-iteration boundary; it is not passed into the terminal business"
      (trustBaseBoundaryObserved emptyBusinessReport)
      "TrustBaseNonRecursiveBoundaryArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-boot-ast-layout-expands"
      (bootAstLayoutExpands astProjectionEvidence)
      "candidate core foreground can be expanded into a boot-time AST layout"
      (bootAstLayoutObserved astProjectionEvidence)
      "CoreSelfInterpretBootAstLayoutArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-ast-dag-equivalence"
      (bootAstDagEquivalent astProjectionEvidence)
      "content-addressed AST DAG and occurrence index are equivalent to the full layout expansion"
      (bootAstDagObserved astProjectionEvidence)
      "CoreSelfInterpretAstDagEquivalenceArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-live-ast-cursor-projects"
      (liveAstCursorProjects astProjectionEvidence)
      "explicit hanging context emits runtime cursors that resolve back into the AST layout"
      (liveAstCursorObserved astProjectionEvidence)
      "CoreSelfInterpretLiveAstCursorArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-live-ast-status-projects"
      (liveAstStatusProjects astProjectionEvidence)
      "runtime cursors fold into a renderable AST node status projection"
      (liveAstStatusObserved astProjectionEvidence)
      "CoreSelfInterpretLiveAstStatusArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-listener-context-explicit"
      (listenerContextExplicit astProjectionEvidence)
      "listener context is explicit evidence-only foreground and is not installed in the default empty business hot path"
      (listenerContextObserved astProjectionEvidence)
      "CoreSelfInterpretListenerContextArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-default-gates-collapsed"
      (defaultGatesCollapsed gateConsolidationEvidence)
      "ordinary gate policies are rooted in build + core-self-interpret, not parallel release witnesses"
      (defaultGatesObserved gateConsolidationEvidence)
      "CoreSelfInterpretDefaultGateConsolidationArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-focused-witnesses-demoted"
      (focusedWitnessesDemoted gateConsolidationEvidence)
      "heavy focused reports and witnesses remain cataloged but absent from default gate commands; business boundary witnesses may run in semantic/release gates"
      (focusedWitnessesObserved gateConsolidationEvidence)
      "CoreSelfInterpretFocusedWitnessDemotionArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-promotion-gate-isolated"
      (promotionGateIsolated gateConsolidationEvidence)
      "self-artifact-witness is isolated behind the explicit high-risk promotion policy"
      (promotionGateObserved gateConsolidationEvidence)
      "CoreSelfInterpretPromotionGateIsolationArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-artifact-gate-collapsed"
      (artifactGateCollapsed gateConsolidationEvidence)
      "self-artifact internal commands rerun the self-interpret release proof instead of parallel focused witnesses"
      (artifactGateObserved gateConsolidationEvidence)
      "CoreSelfInterpretArtifactGateConsolidationArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-core0-core1-exchangeable"
      (fixedPointPassed fixedPointReport)
      "release candidate core_1 is exchangeable with core_0 under normalized self-interpret evidence"
      (coreExchangeabilityObserved fixedPointReport)
      "CoreExchangeabilityArtifact"
  , coreSelfInterpretEvidence
      "core-self-interpret-fixed-point-synced"
      (fixedPointPassed fixedPointReport)
      "previous-core/new-core fixed-point evidence remains synced"
      (fixedPointObserved fixedPointReport)
      "SelfInterpretFixedPointArtifact"
  ]

coreSelfInterpretEvidence :: String -> Bool -> String -> String -> String -> CoreSelfInterpretEvidencePayload
coreSelfInterpretEvidence claim passed expected observed artifact =
  CoreSelfInterpretEvidencePayload
    { coreSelfInterpretEvidenceClaim = claim
    , coreSelfInterpretEvidenceStatus =
        if passed
          then CoreSelfInterpretPassed
          else CoreSelfInterpretFailed
    , coreSelfInterpretEvidenceExpected = expected
    , coreSelfInterpretEvidenceObserved = observed
    , coreSelfInterpretEvidenceArtifact = artifact
    }

coreSelfInterpretClaimManifestPayload ::
  [CoreSelfInterpretEvidencePayload] ->
  CoreSelfInterpretEvidencePayload
coreSelfInterpretClaimManifestPayload payloads =
  coreSelfInterpretEvidence
    "core-self-interpret-claim-manifest"
    manifestSynced
    "core self-interpret payload claims match exported claim manifest"
    observed
    "CoreSelfInterpretClaimManifestArtifact"
  where
    actualCoreClaimNames =
      map coreSelfInterpretEvidenceClaim payloads
    actualEvidenceClaimNames =
      actualCoreClaimNames ++ ["core-self-interpret-claim-manifest"]
    manifestSynced =
      actualEvidenceClaimNames == coreSelfInterpretEvidenceClaimNames
    observed =
      if manifestSynced
        then "claim manifest synced: " ++ show (length actualCoreClaimNames) ++ " core claims"
        else "expected " ++ show coreSelfInterpretEvidenceClaimNames ++ "; actual " ++ show actualEvidenceClaimNames

previousCoreStage :: FrameworkCoreReport -> CoreSelfInterpretStage
previousCoreStage report =
  CoreSelfInterpretStage
    { coreSelfInterpretStageName = "core_0-runs-new_core"
    , coreSelfInterpretStageStatus = frameworkCoreStatusText (frameworkCoreReportStatus report)
    , coreSelfInterpretStageSummary =
        "surface modules="
          ++ show (frameworkCoreReportSurfaceModules report)
          ++ ", final facts="
          ++ show (length (factClosureFinalRuntimeFacts (frameworkCoreReportFactClosure report)))
    }

newCoreStage :: DomainReport -> CoreSelfInterpretStage
newCoreStage report =
  CoreSelfInterpretStage
    { coreSelfInterpretStageName = "new_core-runs-as-domain"
    , coreSelfInterpretStageStatus = domainStatusText (domainReportStatus report)
    , coreSelfInterpretStageSummary =
        "domain="
          ++ domainReportName report
          ++ ", final facts="
          ++ show (length (domainReportFinalRuntimeFacts report))
    }

emptyBusinessStage :: DomainReport -> CoreSelfInterpretStage
emptyBusinessStage report =
  CoreSelfInterpretStage
    { coreSelfInterpretStageName = "new_core-runs-empty_business"
    , coreSelfInterpretStageStatus = domainStatusText (domainReportStatus report)
    , coreSelfInterpretStageSummary =
        "domain="
          ++ domainReportName report
          ++ ", handlers="
          ++ show (length (domainReportHandlerCoverage report))
    }

astProjectionStage :: CoreSelfInterpretAstProjectionEvidence -> CoreSelfInterpretStage
astProjectionStage evidence =
  CoreSelfInterpretStage
    { coreSelfInterpretStageName = "self-interpret-ast-projection"
    , coreSelfInterpretStageStatus =
        if bootAstLayoutExpands evidence
          && bootAstDagEquivalent evidence
          && liveAstCursorProjects evidence
          && liveAstStatusProjects evidence
          && listenerContextExplicit evidence
          then "passed"
          else "failed"
    , coreSelfInterpretStageSummary =
        "boot nodes="
          ++ show (coreSelfInterpretBootLayoutNodeCount evidence)
          ++ ", dag nodes="
          ++ show (coreSelfInterpretBootDagNodeCount evidence)
          ++ ", shared dag nodes="
          ++ show (coreSelfInterpretBootDagSharedNodeCount evidence)
          ++ ", live cursors="
          ++ show (coreSelfInterpretLiveCursorCount evidence)
          ++ ", aligned="
          ++ show (coreSelfInterpretLiveAlignedCursorCount evidence)
          ++ ", status nodes="
          ++ show (coreSelfInterpretLiveStatusNodeCount evidence)
    }

gateConsolidationStage :: CoreSelfInterpretGateConsolidationEvidence -> CoreSelfInterpretStage
gateConsolidationStage evidence =
  CoreSelfInterpretStage
    { coreSelfInterpretStageName = "self-interpret-gate-consolidation"
    , coreSelfInterpretStageStatus =
        if defaultGatesCollapsed evidence
          && focusedWitnessesDemoted evidence
          && promotionGateIsolated evidence
          && artifactGateCollapsed evidence
          then "passed"
          else "failed"
    , coreSelfInterpretStageSummary =
        "default policies="
          ++ show (length (coreSelfInterpretDefaultGatePolicyNames evidence))
          ++ ", duplicate defaults="
          ++ show (length (coreSelfInterpretDefaultGateDuplicateCommands evidence))
          ++ ", artifact duplicates="
          ++ show (length (coreSelfInterpretArtifactGateDuplicateCommands evidence))
          ++ ", high-risk policies="
          ++ show (length (coreSelfInterpretHighRiskGatePolicyNames evidence))
    }

fixedPointStage :: FixedPointReport -> CoreSelfInterpretStage
fixedPointStage report =
  CoreSelfInterpretStage
    { coreSelfInterpretStageName = "self-interpret-fixed-point"
    , coreSelfInterpretStageStatus = fixedPointStatusText (fixedPointStatus report)
    , coreSelfInterpretStageSummary =
        "diffs=" ++ show (length (fixedPointDiffs report))
    }

frameworkCoreReportObserved :: FrameworkCoreReport -> String
frameworkCoreReportObserved report =
  "status="
    ++ frameworkCoreStatusText (frameworkCoreReportStatus report)
    ++ ", failures="
    ++ show (length (frameworkCoreReportFailures report))

domainReportObserved :: DomainReport -> String
domainReportObserved report =
  "status="
    ++ domainStatusText (domainReportStatus report)
    ++ ", failures="
    ++ show (length (domainReportFailures report))

emptyBusinessObserved :: DomainReport -> String
emptyBusinessObserved report =
  domainReportObserved report
    ++ ", acceptedFactPresent="
    ++ show (emptyBusinessAcceptedFact `elem` domainReportFinalRuntimeFacts report)

emptyBusinessIoObserved :: DomainReport -> String
emptyBusinessIoObserved report =
  "handlerCoverage="
    ++ show (length (domainReportHandlerCoverage report))
    ++ ", artifacts="
    ++ show (length (domainReportArtifacts report))

trustBaseBoundaryNonRecursive :: DomainReport -> Bool
trustBaseBoundaryNonRecursive report =
  domainReportName report == "empty-business"
    && null trustBaseFacts
    && null (domainReportHandlerCoverage report)
    && null (domainReportArtifacts report)
  where
    trustBaseFacts =
      [ currentFact
      | currentFact <- domainReportFinalRuntimeFacts report
      , "TrustBase" `isInfixOf` show currentFact
      ]

trustBaseBoundaryObserved :: DomainReport -> String
trustBaseBoundaryObserved report =
  "terminal domain="
    ++ domainReportName report
    ++ ", trustbase final facts="
    ++ show (length trustBaseFacts)
    ++ ", handlerCoverage="
    ++ show (length (domainReportHandlerCoverage report))
    ++ ", artifacts="
    ++ show (length (domainReportArtifacts report))
  where
    trustBaseFacts =
      [ currentFact
      | currentFact <- domainReportFinalRuntimeFacts report
      , "TrustBase" `isInfixOf` show currentFact
      ]

buildCoreSelfInterpretAstProjectionEvidence :: IO CoreSelfInterpretAstProjectionEvidence
buildCoreSelfInterpretAstProjectionEvidence = do
  liveResult <-
    Runtime.runBlueprintWithEffectEnvironmentRuntimeResult
      (Runtime.runtimeEffectEnvironment Runtime.emptyHandlerRegistry)
      emptyBusinessEffects
      coreSelfInterpretLiveBlueprint
  let bootLayout =
        coreSelfInterpretBootLayout
      bootDag =
        fst bootDagProjection
      bootDagProof =
        snd bootDagProjection
      liveLayout =
        layoutDomainAppBlueprint emptyBusinessEffects coreSelfInterpretLiveBlueprint
      liveRuntime =
        runtimeFromResult liveResult
      liveCursors =
        [ cursor
        | event <- Runtime.runtimeContextEvents liveRuntime
        , Just cursor <- [astRuntimeCursorFromEvent event]
        , astRuntimeCursorContext cursor == coreSelfInterpretLiveContextName
        ]
      alignedCursors =
        filter (cursorAlignsWithLayout liveLayout) liveCursors
      renderedCursors =
        [ cursor
        | cursor <- alignedCursors
        , not (null (renderAstRuntimeCursorOnLayout liveLayout cursor))
        ]
      liveStatusModel =
        astRuntimeStatusModel coreSelfInterpretLiveContextName liveLayout (Runtime.runtimeContextEvents liveRuntime)
      liveStatusNodes =
        astRuntimeStatusModelNodes liveStatusModel
      renderedStatusLines =
        renderAstRuntimeStatusModel liveStatusModel
      bootDagProjection =
        coreSelfInterpretBootDagProjection
  pure
    CoreSelfInterpretAstProjectionEvidence
      { coreSelfInterpretBootLayoutRootPath = astLayoutRootPath bootLayout
      , coreSelfInterpretBootLayoutNodeCount = length (astLayoutNodes bootLayout)
      , coreSelfInterpretBootLayoutEdgeCount = length (astLayoutEdges bootLayout)
      , coreSelfInterpretBootDagNodeCount = length (astDagNodes bootDag)
      , coreSelfInterpretBootDagOccurrenceCount = length (astDagOccurrences bootDag)
      , coreSelfInterpretBootDagSharedNodeCount =
          length [item | item <- astDagMultiplicities bootDag, astDagMultiplicityCount item > 1]
      , coreSelfInterpretBootDagMaxMultiplicity =
          maximumOrZeroInt (map astDagMultiplicityCount (astDagMultiplicities bootDag))
      , coreSelfInterpretBootDagProofPassed = astDagEquivalenceProofPassed bootDagProof
      , coreSelfInterpretBootDagProofConstraintCount = length (astDagProofConstraints bootDagProof)
      , coreSelfInterpretDefaultHangingCount = length (hangingItems (blueprintHanging emptyBusinessBlueprint))
      , coreSelfInterpretLiveHangingCount = length (hangingItems (blueprintHanging coreSelfInterpretLiveBlueprint))
      , coreSelfInterpretLiveContextModes = coreSelfInterpretLiveModes
      , coreSelfInterpretLiveRuntimePassed = runtimeResultPassed liveResult
      , coreSelfInterpretLiveContextStarted =
          Runtime.RuntimeContextStarted coreSelfInterpretLiveContextName `elem` Runtime.runtimeContextEvents liveRuntime
      , coreSelfInterpretLiveContextCompleted =
          Runtime.RuntimeContextCompleted coreSelfInterpretLiveContextName `elem` Runtime.runtimeContextEvents liveRuntime
      , coreSelfInterpretLiveCursorCount = length liveCursors
      , coreSelfInterpretLiveAlignedCursorCount = length alignedCursors
      , coreSelfInterpretLiveRenderedCursorCount = length renderedCursors
      , coreSelfInterpretLiveStatusNodeCount = length liveStatusNodes
      , coreSelfInterpretLiveCompletedStatusCount =
          length [node | node <- liveStatusNodes, astRuntimeNodeStatus node == AstRuntimeCompleted]
      , coreSelfInterpretLiveRunningStatusCount =
          length [node | node <- liveStatusNodes, astRuntimeNodeStatus node == AstRuntimeRunning]
      , coreSelfInterpretLiveUnresolvedStatusCount =
          length [node | node <- liveStatusNodes, astRuntimeNodeStatus node == AstRuntimeUnresolved]
      , coreSelfInterpretLiveRenderedStatusLineCount = length renderedStatusLines
      , coreSelfInterpretLiveRuntimeError = runtimeResultError liveResult
      }

coreSelfInterpretBootDagProjection :: (AstDagModel, AstDagEquivalenceProof)
coreSelfInterpretBootDagProjection =
  astDagDomainAppBlueprintProjection coreSelfInterpretBootEffectTheory coreSelfInterpretBootBlueprint

coreSelfInterpretBootLayout :: AstLayoutModel
coreSelfInterpretBootLayout =
  layoutDomainAppBlueprint coreSelfInterpretBootEffectTheory coreSelfInterpretBootBlueprint

coreSelfInterpretBootEffectTheory :: EffectTheory
coreSelfInterpretBootEffectTheory =
  effectRegistrationTheory (domainEffects frameworkCoreFacadeDomain)

coreSelfInterpretBootBlueprint :: AppBlueprint
coreSelfInterpretBootBlueprint =
  astRegistrationBlueprint (domainAst frameworkCoreFacadeDomain)

coreSelfInterpretLiveBlueprint :: AppBlueprint
coreSelfInterpretLiveBlueprint =
  withRecursionContext coreSelfInterpretLiveContext emptyBusinessBlueprint

coreSelfInterpretLiveContext :: RecursionContext WorkflowFact
coreSelfInterpretLiveContext =
  recursionContext
    coreSelfInterpretLiveContextName
    ( recursionModel
        "core-self-interpret-live-para-histo"
        coreSelfInterpretLiveModes
        (recursionContextAlgebra "core-self-interpret-live-algebra" [])
    )

coreSelfInterpretLiveContextName :: RecursionContextName
coreSelfInterpretLiveContextName =
  RecursionContextName "CoreSelfInterpretLiveContext"

coreSelfInterpretLiveModes :: [RecursionSchemeMode]
coreSelfInterpretLiveModes =
  [paraMode, histoMode, renderBeforeRunMode, listenDuringRunMode]

bootAstLayoutExpands :: CoreSelfInterpretAstProjectionEvidence -> Bool
bootAstLayoutExpands evidence =
  not (null (coreSelfInterpretBootLayoutRootPath evidence))
    && coreSelfInterpretBootLayoutNodeCount evidence > 0
    && coreSelfInterpretBootLayoutEdgeCount evidence > 0

bootAstLayoutObserved :: CoreSelfInterpretAstProjectionEvidence -> String
bootAstLayoutObserved evidence =
  "root="
    ++ renderPath (coreSelfInterpretBootLayoutRootPath evidence)
    ++ ", nodes="
    ++ show (coreSelfInterpretBootLayoutNodeCount evidence)
    ++ ", edges="
    ++ show (coreSelfInterpretBootLayoutEdgeCount evidence)

bootAstDagEquivalent :: CoreSelfInterpretAstProjectionEvidence -> Bool
bootAstDagEquivalent evidence =
  coreSelfInterpretBootDagProofPassed evidence
    && coreSelfInterpretBootDagOccurrenceCount evidence == coreSelfInterpretBootLayoutNodeCount evidence
    && coreSelfInterpretBootDagNodeCount evidence > 0
    && coreSelfInterpretBootDagNodeCount evidence <= coreSelfInterpretBootDagOccurrenceCount evidence

bootAstDagObserved :: CoreSelfInterpretAstProjectionEvidence -> String
bootAstDagObserved evidence =
  "dag nodes="
    ++ show (coreSelfInterpretBootDagNodeCount evidence)
    ++ ", occurrences="
    ++ show (coreSelfInterpretBootDagOccurrenceCount evidence)
    ++ ", shared nodes="
    ++ show (coreSelfInterpretBootDagSharedNodeCount evidence)
    ++ ", max multiplicity="
    ++ show (coreSelfInterpretBootDagMaxMultiplicity evidence)
    ++ ", proof constraints="
    ++ show (coreSelfInterpretBootDagProofConstraintCount evidence)
    ++ ", proof passed="
    ++ show (coreSelfInterpretBootDagProofPassed evidence)

liveAstCursorProjects :: CoreSelfInterpretAstProjectionEvidence -> Bool
liveAstCursorProjects evidence =
  coreSelfInterpretLiveRuntimePassed evidence
    && coreSelfInterpretLiveContextStarted evidence
    && coreSelfInterpretLiveContextCompleted evidence
    && coreSelfInterpretLiveCursorCount evidence > 0
    && coreSelfInterpretLiveCursorCount evidence == coreSelfInterpretLiveAlignedCursorCount evidence
    && coreSelfInterpretLiveAlignedCursorCount evidence == coreSelfInterpretLiveRenderedCursorCount evidence

liveAstCursorObserved :: CoreSelfInterpretAstProjectionEvidence -> String
liveAstCursorObserved evidence =
  "runtime="
    ++ runtimeStatusObserved evidence
    ++ ", contextStarted="
    ++ show (coreSelfInterpretLiveContextStarted evidence)
    ++ ", contextCompleted="
    ++ show (coreSelfInterpretLiveContextCompleted evidence)
    ++ ", cursors="
    ++ show (coreSelfInterpretLiveCursorCount evidence)
    ++ ", aligned="
    ++ show (coreSelfInterpretLiveAlignedCursorCount evidence)
    ++ ", rendered="
    ++ show (coreSelfInterpretLiveRenderedCursorCount evidence)

liveAstStatusProjects :: CoreSelfInterpretAstProjectionEvidence -> Bool
liveAstStatusProjects evidence =
  coreSelfInterpretLiveRuntimePassed evidence
    && coreSelfInterpretLiveStatusNodeCount evidence > 0
    && coreSelfInterpretLiveCompletedStatusCount evidence > 0
    && coreSelfInterpretLiveUnresolvedStatusCount evidence == 0
    && coreSelfInterpretLiveRenderedStatusLineCount evidence > coreSelfInterpretLiveStatusNodeCount evidence

liveAstStatusObserved :: CoreSelfInterpretAstProjectionEvidence -> String
liveAstStatusObserved evidence =
  "statusNodes="
    ++ show (coreSelfInterpretLiveStatusNodeCount evidence)
    ++ ", completed="
    ++ show (coreSelfInterpretLiveCompletedStatusCount evidence)
    ++ ", running="
    ++ show (coreSelfInterpretLiveRunningStatusCount evidence)
    ++ ", unresolved="
    ++ show (coreSelfInterpretLiveUnresolvedStatusCount evidence)
    ++ ", renderedLines="
    ++ show (coreSelfInterpretLiveRenderedStatusLineCount evidence)

listenerContextExplicit :: CoreSelfInterpretAstProjectionEvidence -> Bool
listenerContextExplicit evidence =
  coreSelfInterpretDefaultHangingCount evidence == 0
    && coreSelfInterpretLiveHangingCount evidence > 0
    && all (`elem` coreSelfInterpretLiveContextModes evidence) [paraMode, histoMode, renderBeforeRunMode, listenDuringRunMode]

listenerContextObserved :: CoreSelfInterpretAstProjectionEvidence -> String
listenerContextObserved evidence =
  "defaultHanging="
    ++ show (coreSelfInterpretDefaultHangingCount evidence)
    ++ ", liveHanging="
    ++ show (coreSelfInterpretLiveHangingCount evidence)
    ++ ", model=core-self-interpret-live-para-histo"
    ++ ", modes="
    ++ intercalate "," (map show (coreSelfInterpretLiveContextModes evidence))

runtimeStatusObserved :: CoreSelfInterpretAstProjectionEvidence -> String
runtimeStatusObserved evidence =
  if coreSelfInterpretLiveRuntimePassed evidence
    then "passed"
    else "failed: " ++ maybe "unknown" id (coreSelfInterpretLiveRuntimeError evidence)

cursorAlignsWithLayout :: AstLayoutModel -> AstRuntimeCursor -> Bool
cursorAlignsWithLayout layout cursor =
  case astLayoutNodeByPath (astRuntimeCursorPath cursor) layout of
    Just node ->
      astLayoutNodeKind node == astRuntimeCursorKind cursor
        && astLayoutNodeName node == astRuntimeCursorName cursor
    Nothing ->
      False

runtimeFromResult :: Runtime.RuntimeResult Runtime.Runtime -> Runtime.Runtime
runtimeFromResult result =
  case result of
    Runtime.RuntimeSucceeded runtime _ ->
      runtime
    Runtime.RuntimeFailed _ runtime ->
      runtime

runtimeResultPassed :: Runtime.RuntimeResult Runtime.Runtime -> Bool
runtimeResultPassed result =
  case result of
    Runtime.RuntimeSucceeded _ _ ->
      True
    Runtime.RuntimeFailed _ _ ->
      False

runtimeResultError :: Runtime.RuntimeResult Runtime.Runtime -> Maybe String
runtimeResultError result =
  case result of
    Runtime.RuntimeSucceeded _ _ ->
      Nothing
    Runtime.RuntimeFailed errorReport _ ->
      Just (Runtime.renderRuntimeError errorReport)

buildCoreSelfInterpretGateConsolidationEvidence :: CoreSelfInterpretGateConsolidationEvidence
buildCoreSelfInterpretGateConsolidationEvidence =
  CoreSelfInterpretGateConsolidationEvidence
    { coreSelfInterpretDefaultGatePolicyNames =
        map trustBaseGatePolicyName defaultPolicies
    , coreSelfInterpretHighRiskGatePolicyNames =
        map trustBaseGatePolicyName highRiskPolicies
    , coreSelfInterpretDefaultGateCommands =
        defaultCommands
    , coreSelfInterpretHighRiskGateCommands =
        highRiskCommands
    , coreSelfInterpretArtifactGateCommands =
        artifactCommands
    , coreSelfInterpretDefaultGateDuplicateCommands =
        [ command
        | command <- defaultCommands
        , any (`commandMentionsExecutable` command) retiredDefaultGateExecutables
        ]
    , coreSelfInterpretArtifactGateDuplicateCommands =
        [ command
        | command <- artifactCommands
        , any (`commandMentionsExecutable` command) retiredDefaultGateExecutables
        ]
    , coreSelfInterpretDemotedSchemaEntries =
        [ entry
        | entry <- trustBaseManifestRequiredJsonSchemas
        , any (`schemaEntryMentionsExecutable` entry) demotedSchemaExecutables
        ]
    }
  where
    defaultPolicies =
      [ policy
      | policy <- trustBaseManifestRequiredGatePolicies
      , not (trustBaseGatePolicyHighRisk policy)
      ]
    highRiskPolicies =
      [ policy
      | policy <- trustBaseManifestRequiredGatePolicies
      , trustBaseGatePolicyHighRisk policy
      ]
    defaultCommands =
      concatMap trustBaseGatePolicyCommands defaultPolicies
    highRiskCommands =
      concatMap trustBaseGatePolicyCommands highRiskPolicies
    artifactCommands =
      map renderArtifactCommandBody (artifactManifestCommands defaultSelfArtifactManifest)

renderArtifactCommandBody :: ArtifactCommand -> String
renderArtifactCommandBody command =
  unwords (artifactCommandExecutable command : artifactCommandArguments command)

defaultGatesCollapsed :: CoreSelfInterpretGateConsolidationEvidence -> Bool
defaultGatesCollapsed evidence =
  all defaultPolicyStartsWithSelfInterpretLine defaultPolicies
    && null (coreSelfInterpretDefaultGateDuplicateCommands evidence)
  where
    defaultPolicies =
      [ policy
      | policy <- trustBaseManifestRequiredGatePolicies
      , not (trustBaseGatePolicyHighRisk policy)
      ]

defaultPolicyStartsWithSelfInterpretLine :: TrustBaseGatePolicy -> Bool
defaultPolicyStartsWithSelfInterpretLine policy =
  take 2 (trustBaseGatePolicyCommands policy) == coreSelfInterpretGatePrefix

defaultGatesObserved :: CoreSelfInterpretGateConsolidationEvidence -> String
defaultGatesObserved evidence =
  "policies="
    ++ intercalate "," (coreSelfInterpretDefaultGatePolicyNames evidence)
    ++ ", prefix="
    ++ intercalate " -> " coreSelfInterpretGatePrefix
    ++ ", duplicateDefaultCommands="
    ++ show (length (coreSelfInterpretDefaultGateDuplicateCommands evidence))

focusedWitnessesDemoted :: CoreSelfInterpretGateConsolidationEvidence -> Bool
focusedWitnessesDemoted evidence =
  null (coreSelfInterpretDefaultGateDuplicateCommands evidence)
    && all demotedExecutableHasSchema demotedSchemaExecutables
    && all demotedExecutableHasSchema businessDefaultGateExecutables
  where
    demotedExecutableHasSchema executable =
      any (schemaEntryMentionsExecutable executable) trustBaseManifestRequiredJsonSchemas

focusedWitnessesObserved :: CoreSelfInterpretGateConsolidationEvidence -> String
focusedWitnessesObserved evidence =
  "demotedExecutables="
    ++ intercalate "," demotedSchemaExecutables
    ++ ", businessDefaultGateExecutables="
    ++ intercalate "," businessDefaultGateExecutables
    ++ ", catalogedSchemaEntries="
    ++ show (length (coreSelfInterpretDemotedSchemaEntries evidence))
    ++ ", defaultDuplicateCommands="
    ++ renderCommandList (coreSelfInterpretDefaultGateDuplicateCommands evidence)

promotionGateIsolated :: CoreSelfInterpretGateConsolidationEvidence -> Bool
promotionGateIsolated evidence =
  not (any (commandMentionsExecutable "self-artifact-witness") (coreSelfInterpretDefaultGateCommands evidence))
    && any (commandMentionsExecutable "self-artifact-witness") (coreSelfInterpretHighRiskGateCommands evidence)
    && all highRiskPolicyStartsWithSelfInterpretLine highRiskPolicies
  where
    highRiskPolicies =
      [ policy
      | policy <- trustBaseManifestRequiredGatePolicies
      , trustBaseGatePolicyHighRisk policy
      ]

highRiskPolicyStartsWithSelfInterpretLine :: TrustBaseGatePolicy -> Bool
highRiskPolicyStartsWithSelfInterpretLine policy =
  take 2 (trustBaseGatePolicyCommands policy) == coreSelfInterpretGatePrefix

promotionGateObserved :: CoreSelfInterpretGateConsolidationEvidence -> String
promotionGateObserved evidence =
  "defaultSelfArtifactCommands="
    ++ show (length [command | command <- coreSelfInterpretDefaultGateCommands evidence, commandMentionsExecutable "self-artifact-witness" command])
    ++ ", highRiskSelfArtifactCommands="
    ++ show (length [command | command <- coreSelfInterpretHighRiskGateCommands evidence, commandMentionsExecutable "self-artifact-witness" command])
    ++ ", highRiskPolicies="
    ++ intercalate "," (coreSelfInterpretHighRiskGatePolicyNames evidence)

artifactGateCollapsed :: CoreSelfInterpretGateConsolidationEvidence -> Bool
artifactGateCollapsed evidence =
  take 2 artifactCommands == coreSelfInterpretGatePrefix
    && null (coreSelfInterpretArtifactGateDuplicateCommands evidence)
    && any (commandMentionsExecutable "trust-base-manifest-witness") artifactCommands
    && any (commandMentionsExecutable "architecture-concern-witness") artifactCommands
  where
    artifactCommands =
      coreSelfInterpretArtifactGateCommands evidence

artifactGateObserved :: CoreSelfInterpretGateConsolidationEvidence -> String
artifactGateObserved evidence =
  "artifactCommands="
    ++ show (length (coreSelfInterpretArtifactGateCommands evidence))
    ++ ", prefix="
    ++ intercalate " -> " coreSelfInterpretGatePrefix
    ++ ", duplicateArtifactCommands="
    ++ renderCommandList (coreSelfInterpretArtifactGateDuplicateCommands evidence)

coreSelfInterpretGatePrefix :: [String]
coreSelfInterpretGatePrefix =
  [ "stack --work-dir .stack-work-codex build"
  , "stack --work-dir .stack-work-codex exec core-self-interpret -- --json"
  ]

retiredDefaultGateExecutables :: [String]
retiredDefaultGateExecutables =
  demotedSchemaExecutables
    ++ [ "mytest"
       , "domain-app-self-smoke"
       , "framework-core-mytest"
       , "bootstrap-smoke"
       , "bootstrap-runtime-smoke"
       ]

demotedSchemaExecutables :: [String]
demotedSchemaExecutables =
  [ "bootstrap-report"
  , "fixed-point-smoke"
  , "framework-core-frontend-witness"
  , "runtime-evidence-witness"
  , "runtime-hot-path-witness"
  , "runtime-policy-witness"
  , "runtime-diagnosis-witness"
  , "registry-codegen-witness"
  , "workflow-semantics-witness"
  , "constraint-proof-witness"
  , "schema-catalog-witness"
  ]

businessDefaultGateExecutables :: [String]
businessDefaultGateExecutables =
  [ "business-syntax-witness"
  , "domain-app-report"
  ]

commandMentionsExecutable :: String -> String -> Bool
commandMentionsExecutable executable command =
  executable `elem` words command

schemaEntryMentionsExecutable :: String -> String -> Bool
schemaEntryMentionsExecutable executable entry =
  ("<- " ++ executable) `isInfixOf` entry

renderCommandList :: [String] -> String
renderCommandList [] =
  "[]"
renderCommandList commands =
  "[" ++ intercalate "; " commands ++ "]"

fixedPointObserved :: FixedPointReport -> String
fixedPointObserved report =
  "status="
    ++ fixedPointStatusText (fixedPointStatus report)
    ++ ", diffs="
    ++ show (length (fixedPointDiffs report))

coreExchangeabilityObserved :: FixedPointReport -> String
coreExchangeabilityObserved report =
  "core_0="
    ++ stageEvidenceName (fixedPointStage0 report)
    ++ ", core_1="
    ++ stageEvidenceName (fixedPointStage1 report)
    ++ ", status="
    ++ fixedPointStatusText (fixedPointStatus report)
    ++ ", normalizedDiffs="
    ++ show (length (fixedPointDiffs report))

renderPath :: [String] -> String
renderPath path =
  intercalate "/" path

maximumOrZeroInt :: [Int] -> Int
maximumOrZeroInt [] =
  0
maximumOrZeroInt values =
  maximum values

frameworkCoreReportPassed :: FrameworkCoreReport -> Bool
frameworkCoreReportPassed report =
  case frameworkCoreReportStatus report of
    FrameworkCoreReportPassed ->
      True
    FrameworkCoreReportFailed _ ->
      False

domainReportPassed :: DomainReport -> Bool
domainReportPassed report =
  case domainReportStatus report of
    DomainReportPassed ->
      True
    DomainReportFailed _ ->
      False

frameworkCoreStatusText :: FrameworkCoreReportStatus -> String
frameworkCoreStatusText FrameworkCoreReportPassed =
  "passed"
frameworkCoreStatusText (FrameworkCoreReportFailed _) =
  "failed"

domainStatusText :: DomainReportStatus -> String
domainStatusText DomainReportPassed =
  "passed"
domainStatusText (DomainReportFailed _) =
  "failed"

fixedPointStatusText :: FixedPointStatus -> String
fixedPointStatusText FixedPointPassed =
  "passed"
fixedPointStatusText FixedPointFailed =
  "failed"

renderCoreSelfInterpretReport :: CoreSelfInterpretReport -> [String]
renderCoreSelfInterpretReport report =
  [ "core self-interpret report"
  , "schema: " ++ coreSelfInterpretReportSchema report
  , "status: " ++ renderCoreSelfInterpretEvidenceStatus (coreSelfInterpretReportStatus report)
  , "stages:"
  ]
    ++ indentLines 2 (concatMap renderCoreSelfInterpretStage (coreSelfInterpretReportStages report))
    ++ [ "payloads:" ]
    ++ indentLines 2 (concatMap renderCoreSelfInterpretEvidencePayload (coreSelfInterpretReportPayloads report))

renderCoreSelfInterpretStage :: CoreSelfInterpretStage -> [String]
renderCoreSelfInterpretStage stage =
  [ coreSelfInterpretStageName stage
  , "status: " ++ coreSelfInterpretStageStatus stage
  , "summary: " ++ coreSelfInterpretStageSummary stage
  ]

renderCoreSelfInterpretEvidencePayload :: CoreSelfInterpretEvidencePayload -> [String]
renderCoreSelfInterpretEvidencePayload payload =
  [ "claim: " ++ coreSelfInterpretEvidenceClaim payload
  , "status: " ++ renderCoreSelfInterpretEvidenceStatus (coreSelfInterpretEvidenceStatus payload)
  , "expected: " ++ coreSelfInterpretEvidenceExpected payload
  , "observed: " ++ coreSelfInterpretEvidenceObserved payload
  , "artifact: " ++ coreSelfInterpretEvidenceArtifact payload
  ]

renderCoreSelfInterpretEvidenceStatus :: CoreSelfInterpretEvidenceStatus -> String
renderCoreSelfInterpretEvidenceStatus CoreSelfInterpretPassed =
  "passed"
renderCoreSelfInterpretEvidenceStatus CoreSelfInterpretFailed =
  "failed"

renderCoreSelfInterpretReportJson :: CoreSelfInterpretReport -> String
renderCoreSelfInterpretReportJson report =
  jsonObject
    [ jsonField "schema" (jsonString (coreSelfInterpretReportSchema report))
    , jsonField "status" (jsonString (renderCoreSelfInterpretEvidenceStatus (coreSelfInterpretReportStatus report)))
    , jsonField "stages" (jsonArray (map coreSelfInterpretStageJson (coreSelfInterpretReportStages report)))
    , jsonField "payloads" (jsonArray (map coreSelfInterpretEvidencePayloadJson (coreSelfInterpretReportPayloads report)))
    ]

coreSelfInterpretStageJson :: CoreSelfInterpretStage -> String
coreSelfInterpretStageJson stage =
  jsonObject
    [ jsonField "name" (jsonString (coreSelfInterpretStageName stage))
    , jsonField "status" (jsonString (coreSelfInterpretStageStatus stage))
    , jsonField "summary" (jsonString (coreSelfInterpretStageSummary stage))
    ]

coreSelfInterpretEvidencePayloadJson :: CoreSelfInterpretEvidencePayload -> String
coreSelfInterpretEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (coreSelfInterpretEvidenceClaim payload))
    , jsonField "status" (jsonString (renderCoreSelfInterpretEvidenceStatus (coreSelfInterpretEvidenceStatus payload)))
    , jsonField "expected" (jsonString (coreSelfInterpretEvidenceExpected payload))
    , jsonField "observed" (jsonString (coreSelfInterpretEvidenceObserved payload))
    , jsonField "artifact" (jsonString (coreSelfInterpretEvidenceArtifact payload))
    ]

indentLines :: Int -> [String] -> [String]
indentLines count =
  map (replicate count ' ' ++)

jsonObject :: [String] -> String
jsonObject fields =
  "{" ++ joinWith "," fields ++ "}"

jsonField :: String -> String -> String
jsonField name value =
  jsonString name ++ ":" ++ value

jsonArray :: [String] -> String
jsonArray values =
  "[" ++ joinWith "," values ++ "]"

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

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
