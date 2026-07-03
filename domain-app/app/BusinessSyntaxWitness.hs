{-# LANGUAGE PackageImports #-}
{-# LANGUAGE PatternSynonyms #-}

module Main
  ( main
  ) where

import "domain-app" Domain.Business
  ( allDomainCapabilities
  , generateReportCapability
  , loggingCapabilities
  , reportCapabilities
  , systemCapabilities
  , userCapabilities
  )
import "domain-app" Domain.EffectVocabulary
import "domain-app" Domain.Vocabulary
import "domain-app" Domain.Runtime
  ( LogMessageValue (..)
  , ReportInputValue (..)
  , ReportOutputValue (..)
  , UserNameValue (..)
  , pattern LogMessageTag
  , pattern ReportInputTag
  , pattern ReportOutputTag
  , pattern UserNameTag
  , domainHandlerRegistry
  )
import qualified "domain-app" Effects.Logging as LoggingEffects
import qualified "domain-app" Effects.Report as ReportEffects
import qualified "domain-app" Effects.System as SystemEffects
import qualified "domain-app" Effects.User as UserEffects
import "new-framework-core" Framework.Business
  ( BusinessShapeIssue
  , capabilitiesEffect
  , capabilityEffectSections
  , checkBusinessShape
  , pipelineTransformCandidates
  , renderBusinessShapeIssue
  )
import qualified "new-framework-core" Framework.Effect as Effect
import "new-framework-core" Framework.Effect
  ( EffectSection (..)
  , EffectName (..)
  , EffectUnit (..)
  , ExternalTakeBoundary (..)
  , FactProducer (..)
  , ProducerStep (..)
  , SendBoundary (..)
  , SendPolicy (..)
  , SendSignature (..)
  , TransformName (..)
  , WorkflowFact (..)
  )
import "new-framework-core" Framework.Handler
  ( RuntimeEffectEnvironment (..)
  , RuntimeTransform (..)
  , SomeRuntimeValue
  , TransformBinding (..)
  , TransformRegistry (..)
  , someRuntimeValueText
  , someRuntimeValueType
  )
import qualified "new-framework-core" Framework.Ast as Workflow
import "new-framework-core" Framework.TrustBase
  ( Runtime (..)
  , runBlueprintWithEffectEnvironmentResult
  )
import Data.List
  ( isInfixOf )

main :: IO ()
main = do
  runtimePipelinePassed <- pipelineRuntimeAdapterPassed
  domainBusinessBoundaryPassed <- domainBusinessAuthoringBoundaryPassed
  domainVocabularyBoundaryPassed <- domainEffectVocabularyBoundaryPassed
  let claims = allClaims runtimePipelinePassed domainBusinessBoundaryPassed domainVocabularyBoundaryPassed
  case failedClaims claims of
    [] ->
      putStrLn ("[witness] ok business syntax evidence " ++ show (length claims) ++ " claims")
    failures ->
      ioError (userError (unlines failures))

allClaims :: Bool -> Bool -> Bool -> [(String, Bool)]
allClaims runtimePipelinePassed domainBusinessBoundaryPassed domainVocabularyBoundaryPassed =
  [ ("needs lowering failed", needsLoweringPassed)
  , ("take lowering failed", takeLoweringPassed)
  , ("make lowering failed", makeLoweringPassed)
  , ("uses lowering failed", usesLoweringPassed)
  , ("externalMake lowering failed", externalMakeLoweringPassed)
  , ("transform lowering failed", transformLoweringPassed)
  , ("Effects.* lowering facade drifted from Domain.Business", effectFacadeLoweringPassed)
  , ("Domain.Business authoring boundary drifted", domainBusinessBoundaryPassed)
  , ("Domain.EffectVocabulary authoring boundary drifted", domainVocabularyBoundaryPassed)
  , ("handler binding alignment failed: " ++ unlines (map renderBusinessShapeIssue businessShapeIssues), null businessShapeIssues)
  , ("pipeline adjacent transform failed", pipelineLoweringPassed)
  , ("runtime pipeline adapter failed", runtimePipelinePassed)
  ]

failedClaims :: [(String, Bool)] -> [String]
failedClaims claims =
  [ message
  | (message, passed) <- claims
  , not passed
  ]

needsLoweringPassed :: Bool
needsLoweringPassed =
  all
    hasReportStep
    [ Needs AddCalculatedFact
    , Needs FactorialCalculatedFact
    , Needs SquaresCalculatedFact
    , Needs UserNameAskedFact
    ]

takeLoweringPassed :: Bool
takeLoweringPassed =
  hasReportStep (Take UserName)

makeLoweringPassed :: Bool
makeLoweringPassed =
  hasReportStep (Make ReportOutput)

usesLoweringPassed :: Bool
usesLoweringPassed =
  hasReportStep (Uses GenerateReport)

externalMakeLoweringPassed :: Bool
externalMakeLoweringPassed =
  hasGenerateReportBoundary

transformLoweringPassed :: Bool
transformLoweringPassed =
  hasReportStep (Transform UserName ReportInput UserNameToReportInput)

businessShapeIssues :: [BusinessShapeIssue]
businessShapeIssues =
  checkBusinessShape allDomainCapabilities

pipelineLoweringPassed :: Bool
pipelineLoweringPassed =
  (UserName, ReportInput) `elem` candidates
    && (ReportInput, ReportOutput) `elem` candidates
  where
    candidates =
      pipelineTransformCandidates generateReportCapability

domainBusinessAuthoringBoundaryPassed :: IO Bool
domainBusinessAuthoringBoundaryPassed = do
  source <- readFile "domain-app/src/Domain/Business.hs"
  pure
    ( "import Framework.Business" `isInfixOf` source
        && not ("import Framework.Effect" `isInfixOf` source)
    )

domainEffectVocabularyBoundaryPassed :: IO Bool
domainEffectVocabularyBoundaryPassed = do
  source <- readFile "domain-app/src/Domain/EffectVocabulary.hs"
  pure
    ( "import Framework.Business" `isInfixOf` source
        && not ("import Framework.Effect" `isInfixOf` source)
        && not ("import Framework.Runtime" `isInfixOf` source)
        && not ("import Bootstrap." `isInfixOf` source)
    )

effectFacadeLoweringPassed :: Bool
effectFacadeLoweringPassed =
  all
    id
    [ effectUnitMatches
        SystemEffects.systemEffect
        (capabilitiesEffect SystemEffect systemCapabilities)
    , effectUnitMatches
        UserEffects.userEffect
        (capabilitiesEffect UserEffect userCapabilities)
    , effectUnitMatches
        ReportEffects.reportEffect
        (capabilitiesEffect ReportEffect reportCapabilities)
    , effectUnitMatches
        LoggingEffects.loggingEffect
        (capabilitiesEffect LoggingEffect loggingCapabilities)
    ]

effectUnitMatches :: EffectUnit -> EffectUnit -> Bool
effectUnitMatches actual expected =
  effectUnitName actual == effectUnitName expected
    && effectSectionsMatch (effectUnitSections actual) (effectUnitSections expected)

effectSectionsMatch :: [EffectSection] -> [EffectSection] -> Bool
effectSectionsMatch actual expected =
  length actual == length expected
    && and (zipWith effectSectionMatches actual expected)

effectSectionMatches :: EffectSection -> EffectSection -> Bool
effectSectionMatches actual expected =
  case (actual, expected) of
    (FactClaimSection left, FactClaimSection right) ->
      factProducerMatches left right
    (SendSection left, SendSection right) ->
      sendBoundaryName left == sendBoundaryName right
        && sendInput (sendBoundarySignature left) == sendInput (sendBoundarySignature right)
        && sendOutput (sendBoundarySignature left) == sendOutput (sendBoundarySignature right)
    (SendPolicySection left, SendPolicySection right) ->
      sendPolicyName left == sendPolicyName right
        && sendPolicyIdempotency left == sendPolicyIdempotency right
        && sendPolicyRetry left == sendPolicyRetry right
    (ExternalTakeSection left, ExternalTakeSection right) ->
      externalTakeFact left == externalTakeFact right
        && externalTakeOutput left == externalTakeOutput right
    _ ->
      False

factProducerMatches :: FactProducer -> FactProducer -> Bool
factProducerMatches actual expected =
  producerFact actual == producerFact expected
    && length (producerSteps actual) == length (producerSteps expected)
    && and (zipWith producerStepMatches (producerSteps actual) (producerSteps expected))

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

pipelineRuntimeAdapterPassed :: IO Bool
pipelineRuntimeAdapterPassed = do
  result <-
    runBlueprintWithEffectEnvironmentResult
      pipelineRuntimeEnvironment
      pipelineRuntimeEffects
      pipelineRuntimeAst
  case result of
    Left _ ->
      pure False
    Right runtime ->
      pure
        ( hasTypedValue LogMessage "log:runtime-report" runtime
            && "[runtime] transform UserNameToReportInput" `elem` runtimeTrace runtime
            && "[runtime] transform ReportOutputToLogMessage" `elem` runtimeTrace runtime
        )

pipelineRuntimeAst :: Workflow.AppBlueprint
pipelineRuntimeAst =
  Workflow.AppBlueprint
    { Workflow.blueprintApp =
        Workflow.run
          ( Workflow.effectSystem
              (Workflow.EffectSystemName "PipelineRuntimeAdapterSystem")
              (Workflow.factItems [pipelineAdapterFact])
          )
    , Workflow.blueprintHanging =
        Workflow.hanging []
    }

pipelineRuntimeEffects :: Effect.EffectTheory
pipelineRuntimeEffects =
  Effect.theory
    [ Effect.effect
        (EffectName "PipelineRuntimeAdapterEffect")
        [ Effect.fact pipelineSourceFact
            [ Effect.uses AskUserName
            , Effect.make UserName
            ]
        , Effect.fact pipelineAdapterFact
            [ Effect.needs pipelineSourceFact
            , Effect.take UserName
            , Effect.transform UserName ReportInput UserNameToReportInput
            , Effect.uses GenerateReport
            , Effect.transform ReportOutput LogMessage reportOutputToLogMessage
            , Effect.make LogMessage
            ]
        , Effect.externalMake AskUserName Effect.NoInput UserName
        , Effect.externalMake GenerateReport ReportInput ReportOutput
        ]
    ]

pipelineRuntimeEnvironment :: RuntimeEffectEnvironment
pipelineRuntimeEnvironment =
  RuntimeEffectEnvironment domainHandlerRegistry pipelineTransformRegistry

pipelineTransformRegistry :: TransformRegistry
pipelineTransformRegistry =
  TransformRegistry
    [ TransformBinding
        UserNameToReportInput
        ( RuntimeTransform
            UserNameTag
            ReportInputTag
            ( \(UserNameValue text) ->
                ReportInputValue ("report-input:" ++ text)
            )
        )
    , TransformBinding
        reportOutputToLogMessage
        ( RuntimeTransform
            ReportOutputTag
            LogMessageTag
            ( \(ReportOutputValue text) ->
                LogMessageValue ("log:" ++ text)
            )
        )
    ]

pipelineSourceFact :: WorkflowFact
pipelineSourceFact =
  WorkflowFact "PipelineSourceFact"

pipelineAdapterFact :: WorkflowFact
pipelineAdapterFact =
  WorkflowFact "PipelineAdapterFact"

reportOutputToLogMessage :: TransformName
reportOutputToLogMessage =
  TransformName "ReportOutputToLogMessage"

hasTypedValue :: Effect.TypeName -> String -> Runtime -> Bool
hasTypedValue expectedType expectedText runtime =
  any matches (runtimeTypedValues runtime)
  where
    matches :: SomeRuntimeValue -> Bool
    matches value =
      someRuntimeValueType value == expectedType
        && someRuntimeValueText value == expectedText
