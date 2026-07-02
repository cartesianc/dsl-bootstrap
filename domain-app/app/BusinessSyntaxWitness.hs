{-# LANGUAGE PackageImports #-}

module Main
  ( main
  ) where

import "domain-app" Domain.Business
  ( allDomainCapabilities
  , generateReportCapability
  )
import "domain-app" Domain.EffectVocabulary
import "domain-app" Domain.Vocabulary
import "new-framework-core" Framework.Business
  ( businessShapePassed
  , capabilityEffectSections
  , checkBusinessShape
  , pipelineTransformCandidates
  , renderBusinessShapeIssue
  )
import "new-framework-core" Framework.Effect
  ( EffectSection (..)
  , FactProducer (..)
  , ProducerStep (..)
  , SendBoundary (..)
  , SendSignature (..)
  )

main :: IO ()
main =
  case failedClaims of
    [] ->
      putStrLn "[witness] ok business syntax evidence 3 claims"
    failures ->
      ioError (userError (unlines failures))

failedClaims :: [String]
failedClaims =
  [ message
  | (message, passed) <-
      [ ("capability lowering failed", capabilityLoweringPassed)
      , ("pipeline lowering failed", pipelineLoweringPassed)
      , ("business shape failed: " ++ unlines (map renderBusinessShapeIssue (checkBusinessShape allDomainCapabilities)), businessShapePassed allDomainCapabilities)
      ]
  , not passed
  ]

capabilityLoweringPassed :: Bool
capabilityLoweringPassed =
  all
    id
    [ hasReportStep (Needs AddCalculatedFact)
    , hasReportStep (Needs FactorialCalculatedFact)
    , hasReportStep (Needs SquaresCalculatedFact)
    , hasReportStep (Needs UserNameAskedFact)
    , hasReportStep (Take UserName)
    , hasReportStep (Transform UserName ReportInput UserNameToReportInput)
    , hasReportStep (Uses GenerateReport)
    , hasReportStep (Make ReportOutput)
    , hasGenerateReportBoundary
    ]

pipelineLoweringPassed :: Bool
pipelineLoweringPassed =
  (UserName, ReportInput) `elem` candidates
    && (ReportInput, ReportOutput) `elem` candidates
  where
    candidates =
      pipelineTransformCandidates generateReportCapability

hasReportStep :: ProducerStep -> Bool
hasReportStep expected =
  any (producerStepMatches expected) reportProducerSteps

producerStepMatches :: ProducerStep -> ProducerStep -> Bool
producerStepMatches expected actual =
  case (expected, actual) of
    (Needs left, Needs right) ->
      left == right
    (Uses left, Uses right) ->
      left == right
    (Take left, Take right) ->
      left == right
    (Make left, Make right) ->
      left == right
    (Transform leftInput leftOutput leftName, Transform rightInput rightOutput rightName) ->
      leftInput == rightInput
        && leftOutput == rightOutput
        && leftName == rightName
    (Error left, Error right) ->
      left == right
    (External, External) ->
      True
    (OnFailure left, OnFailure right) ->
      left == right
    _ ->
      False

reportProducerSteps :: [ProducerStep]
reportProducerSteps =
  concat
    [ producerSteps producer
    | FactClaimSection producer <- reportSections
    , producerFact producer == ReportGeneratedFact
    ]

hasGenerateReportBoundary :: Bool
hasGenerateReportBoundary =
  any isGenerateReportBoundary reportSections

isGenerateReportBoundary :: EffectSection -> Bool
isGenerateReportBoundary section =
  case section of
    SendSection boundary ->
      sendBoundaryName boundary == GenerateReport
        && sendInput (sendBoundarySignature boundary) == ReportInput
        && sendOutput (sendBoundarySignature boundary) == ReportOutput
    _ ->
      False

reportSections :: [EffectSection]
reportSections =
  capabilityEffectSections generateReportCapability
