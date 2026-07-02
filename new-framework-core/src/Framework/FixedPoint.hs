module Framework.FixedPoint
  ( EvidenceDiff (..)
  , FixedPointReport (..)
  , FixedPointStatus (..)
  , StageEvidence (..)
  , buildFixedPointReport
  , fixedPointPassed
  , renderFixedPointReport
  ) where

import Data.List
  ( sort )

import Bootstrap.Report
  ( ConstraintReport (..)
  , FactClosureReport (..)
  , FrameworkCoreReport (..)
  , FrameworkCoreReportStatus (..)
  , HandlerCoverage (..)
  , buildFrameworkCoreReport
  )
import Bootstrap.Runtime
  ( RuntimeArtifact (..)
  )
import Framework.Domain
  ( DomainHandlerCoverage (..)
  , DomainReport (..)
  , DomainReportStatus (..)
  , buildDomainReport
  , frameworkCoreFacadeDomain
  )

data StageEvidence = StageEvidence
  { stageEvidenceName :: String
  , stageEvidenceStatus :: String
  , stageEvidenceSurfaceModules :: Int
  , stageEvidenceSurfaceCapabilities :: Int
  , stageEvidenceConstraintTotal :: Int
  , stageEvidenceConstraintFailed :: Int
  , stageEvidenceDeclaredFacts :: [String]
  , stageEvidenceRootFacts :: [String]
  , stageEvidencePlannedRuntimeFacts :: [String]
  , stageEvidenceFinalRuntimeFacts :: [String]
  , stageEvidenceMissingFinalFacts :: [String]
  , stageEvidenceExtraFinalFacts :: [String]
  , stageEvidenceHandlerCoverage :: [String]
  , stageEvidenceArtifactTypes :: [String]
  , stageEvidenceFailures :: [String]
  }

data EvidenceDiff = EvidenceDiff
  { evidenceDiffField :: String
  , evidenceDiffStage0 :: String
  , evidenceDiffStage1 :: String
  }

data FixedPointReport = FixedPointReport
  { fixedPointStatus :: FixedPointStatus
  , fixedPointStage0 :: StageEvidence
  , fixedPointStage1 :: StageEvidence
  , fixedPointDiffs :: [EvidenceDiff]
  }

data FixedPointStatus
  = FixedPointPassed
  | FixedPointFailed
  deriving (Eq, Show)

buildFixedPointReport :: IO FixedPointReport
buildFixedPointReport = do
  stage0Report <- buildFrameworkCoreReport
  stage1Report <- buildDomainReport frameworkCoreFacadeDomain
  let stage0 = evidenceFromFrameworkCoreReport "stage0-bootstrap" stage0Report
      stage1 = evidenceFromDomainReport "stage1-framework-facade" stage1Report
      diffs = diffEvidence stage0 stage1
      status =
        if null diffs && stageEvidenceStatus stage0 == "passed" && stageEvidenceStatus stage1 == "passed"
          then FixedPointPassed
          else FixedPointFailed
  pure
    FixedPointReport
      { fixedPointStatus = status
      , fixedPointStage0 = stage0
      , fixedPointStage1 = stage1
      , fixedPointDiffs = diffs
      }

fixedPointPassed :: FixedPointReport -> Bool
fixedPointPassed report =
  fixedPointStatus report == FixedPointPassed

renderFixedPointReport :: FixedPointReport -> [String]
renderFixedPointReport report =
  [ "fixed-point report"
  , "status: " ++ renderFixedPointStatus (fixedPointStatus report)
  , "stage0: " ++ stageEvidenceName (fixedPointStage0 report)
  , "stage1: " ++ stageEvidenceName (fixedPointStage1 report)
  , "diffs: " ++ show (length (fixedPointDiffs report))
  ]
    ++ renderDiffs (fixedPointDiffs report)

evidenceFromFrameworkCoreReport :: String -> FrameworkCoreReport -> StageEvidence
evidenceFromFrameworkCoreReport name report =
  StageEvidence
    { stageEvidenceName = name
    , stageEvidenceStatus = frameworkCoreStatusText (frameworkCoreReportStatus report)
    , stageEvidenceSurfaceModules = frameworkCoreReportSurfaceModules report
    , stageEvidenceSurfaceCapabilities = frameworkCoreReportSurfaceCapabilities report
    , stageEvidenceConstraintTotal = constraintReportTotal constraints
    , stageEvidenceConstraintFailed = length (constraintReportFailed constraints)
    , stageEvidenceDeclaredFacts = sortedShows (factClosureDeclaredFacts facts)
    , stageEvidenceRootFacts = sortedShows (factClosureRootFacts facts)
    , stageEvidencePlannedRuntimeFacts = sortedShows (factClosurePlannedRuntimeFacts facts)
    , stageEvidenceFinalRuntimeFacts = sortedShows (factClosureFinalRuntimeFacts facts)
    , stageEvidenceMissingFinalFacts = sortedShows (factClosureMissingFinalFacts facts)
    , stageEvidenceExtraFinalFacts = sortedShows (factClosureExtraFinalFacts facts)
    , stageEvidenceHandlerCoverage = sort (map renderCoreHandlerCoverage (frameworkCoreReportHandlerCoverage report))
    , stageEvidenceArtifactTypes = sortedShows (map artifactType (frameworkCoreReportArtifacts report))
    , stageEvidenceFailures = sort (frameworkCoreReportFailures report)
    }
  where
    constraints =
      frameworkCoreReportConstraints report
    facts =
      frameworkCoreReportFactClosure report

evidenceFromDomainReport :: String -> DomainReport -> StageEvidence
evidenceFromDomainReport name report =
  StageEvidence
    { stageEvidenceName = name
    , stageEvidenceStatus = domainStatusText (domainReportStatus report)
    , stageEvidenceSurfaceModules = domainReportSurfaceModules report
    , stageEvidenceSurfaceCapabilities = domainReportSurfaceCapabilities report
    , stageEvidenceConstraintTotal = domainReportConstraintTotal report
    , stageEvidenceConstraintFailed = domainReportConstraintFailed report
    , stageEvidenceDeclaredFacts = sortedShows (domainReportDeclaredFacts report)
    , stageEvidenceRootFacts = sortedShows (domainReportRootFacts report)
    , stageEvidencePlannedRuntimeFacts = sortedShows (domainReportPlannedRuntimeFacts report)
    , stageEvidenceFinalRuntimeFacts = sortedShows (domainReportFinalRuntimeFacts report)
    , stageEvidenceMissingFinalFacts = sortedShows (domainReportMissingFinalFacts report)
    , stageEvidenceExtraFinalFacts = sortedShows (domainReportExtraFinalFacts report)
    , stageEvidenceHandlerCoverage = sort (map renderDomainHandlerCoverage (domainReportHandlerCoverage report))
    , stageEvidenceArtifactTypes = sortedShows (map artifactType (domainReportArtifacts report))
    , stageEvidenceFailures = sort (domainReportFailures report)
    }

diffEvidence :: StageEvidence -> StageEvidence -> [EvidenceDiff]
diffEvidence stage0 stage1 =
  concat
    [ diffValue "status" (stageEvidenceStatus stage0) (stageEvidenceStatus stage1)
    , diffValue "surface modules" (show (stageEvidenceSurfaceModules stage0)) (show (stageEvidenceSurfaceModules stage1))
    , diffValue "surface capabilities" (show (stageEvidenceSurfaceCapabilities stage0)) (show (stageEvidenceSurfaceCapabilities stage1))
    , diffValue "constraint total" (show (stageEvidenceConstraintTotal stage0)) (show (stageEvidenceConstraintTotal stage1))
    , diffValue "constraint failed" (show (stageEvidenceConstraintFailed stage0)) (show (stageEvidenceConstraintFailed stage1))
    , diffValue "declared facts" (show (stageEvidenceDeclaredFacts stage0)) (show (stageEvidenceDeclaredFacts stage1))
    , diffValue "root facts" (show (stageEvidenceRootFacts stage0)) (show (stageEvidenceRootFacts stage1))
    , diffValue "planned runtime facts" (show (stageEvidencePlannedRuntimeFacts stage0)) (show (stageEvidencePlannedRuntimeFacts stage1))
    , diffValue "final runtime facts" (show (stageEvidenceFinalRuntimeFacts stage0)) (show (stageEvidenceFinalRuntimeFacts stage1))
    , diffValue "missing final facts" (show (stageEvidenceMissingFinalFacts stage0)) (show (stageEvidenceMissingFinalFacts stage1))
    , diffValue "extra final facts" (show (stageEvidenceExtraFinalFacts stage0)) (show (stageEvidenceExtraFinalFacts stage1))
    , diffValue "handler coverage" (show (stageEvidenceHandlerCoverage stage0)) (show (stageEvidenceHandlerCoverage stage1))
    , diffValue "artifact types" (show (stageEvidenceArtifactTypes stage0)) (show (stageEvidenceArtifactTypes stage1))
    , diffValue "failures" (show (stageEvidenceFailures stage0)) (show (stageEvidenceFailures stage1))
    ]

diffValue :: String -> String -> String -> [EvidenceDiff]
diffValue field left right
  | left == right =
      []
  | otherwise =
      [ EvidenceDiff
          { evidenceDiffField = field
          , evidenceDiffStage0 = left
          , evidenceDiffStage1 = right
          }
      ]

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

renderCoreHandlerCoverage :: HandlerCoverage -> String
renderCoreHandlerCoverage coverage =
  show (handlerCoverageSend coverage)
    ++ ":"
    ++ show (handlerCoverageCovered coverage)
    ++ ":"
    ++ show (sort (handlerCoverageHandlers coverage))

renderDomainHandlerCoverage :: DomainHandlerCoverage -> String
renderDomainHandlerCoverage coverage =
  show (domainHandlerCoverageSend coverage)
    ++ ":"
    ++ show (domainHandlerCoverageCovered coverage)
    ++ ":"
    ++ show (sort (domainHandlerCoverageHandlers coverage))

renderFixedPointStatus :: FixedPointStatus -> String
renderFixedPointStatus FixedPointPassed =
  "passed"
renderFixedPointStatus FixedPointFailed =
  "failed"

renderDiffs :: [EvidenceDiff] -> [String]
renderDiffs [] =
  []
renderDiffs diffs =
  "evidence diffs:" : concatMap renderDiff diffs

renderDiff :: EvidenceDiff -> [String]
renderDiff diffReport =
  [ "  " ++ evidenceDiffField diffReport
  , "    stage0: " ++ evidenceDiffStage0 diffReport
  , "    stage1: " ++ evidenceDiffStage1 diffReport
  ]

sortedShows :: Show item => [item] -> [String]
sortedShows =
  sort . map show

