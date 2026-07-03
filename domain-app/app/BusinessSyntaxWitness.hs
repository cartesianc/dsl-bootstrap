{-# LANGUAGE PackageImports #-}
{-# LANGUAGE PatternSynonyms #-}

module Main
  ( main
  ) where

import "domain-app" Domain.Business
  ( allDomainCapabilities
  , generateReportCapability
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
import "new-framework-core" Framework.Business
  ( businessShapePassed
  , capabilityEffectSections
  , checkBusinessShape
  , pipelineTransformCandidates
  , renderBusinessShapeIssue
  )
import qualified "new-framework-core" Framework.Effect as Effect
import "new-framework-core" Framework.Effect
  ( EffectSection (..)
  , EffectName (..)
  , FactProducer (..)
  , ProducerStep (..)
  , SendBoundary (..)
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

main :: IO ()
main = do
  runtimePipelinePassed <- pipelineRuntimeAdapterPassed
  case failedClaims runtimePipelinePassed of
    [] ->
      putStrLn "[witness] ok business syntax evidence 4 claims"
    failures ->
      ioError (userError (unlines failures))

failedClaims :: Bool -> [String]
failedClaims runtimePipelinePassed =
  [ message
  | (message, passed) <-
      [ ("capability lowering failed", capabilityLoweringPassed)
      , ("pipeline lowering failed", pipelineLoweringPassed)
      , ("business shape failed: " ++ unlines (map renderBusinessShapeIssue (checkBusinessShape allDomainCapabilities)), businessShapePassed allDomainCapabilities)
      , ("runtime pipeline adapter failed", runtimePipelinePassed)
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
        Workflow.fact (Workflow.factItems [pipelineAdapterFact])
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
