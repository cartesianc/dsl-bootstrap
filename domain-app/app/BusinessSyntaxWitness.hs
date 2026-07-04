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
  , capabilityEffectSystem
  , capabilityEffectSystemBoundary
  , capability
  , checkBusinessShape
  , idempotentPolicy
  , pipelineTransformCandidates
  , policy
  , renderBusinessShapeIssue
  , retryOnce
  , produces
  , uses
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
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  runtimePipelinePassed <- pipelineRuntimeAdapterPassed
  domainBusinessBoundaryPassed <- domainBusinessAuthoringBoundaryPassed
  domainVocabularyBoundaryPassed <- domainEffectVocabularyBoundaryPassed
  effectFacadeBoundaryPassed <- effectsFacadeBoundaryPassed
  let payloads =
        businessSyntaxEvidencePayloads
          runtimePipelinePassed
          domainBusinessBoundaryPassed
          domainVocabularyBoundaryPassed
          effectFacadeBoundaryPassed
      failures =
        evidenceFailures payloads
  case args of
    ["--json"] -> do
      putStrLn (renderBusinessSyntaxEvidencePayloadsJson payloads)
      failWhenEvidenceFailed failures
    _ ->
      case failures of
        [] ->
          putStrLn ("[witness] ok business syntax evidence " ++ show (length payloads) ++ " payload claims")
        currentFailures ->
          ioError (userError (unlines currentFailures))

data BusinessSyntaxEvidencePayload = BusinessSyntaxEvidencePayload
  { businessSyntaxEvidenceClaim :: String
  , businessSyntaxEvidenceStatus :: BusinessSyntaxEvidenceStatus
  , businessSyntaxEvidenceExpected :: String
  , businessSyntaxEvidenceObserved :: String
  , businessSyntaxEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data BusinessSyntaxEvidenceStatus
  = BusinessSyntaxEvidencePassed
  | BusinessSyntaxEvidenceFailed
  deriving (Eq, Show)

businessSyntaxEvidencePayloadPassed :: BusinessSyntaxEvidencePayload -> Bool
businessSyntaxEvidencePayloadPassed payload =
  businessSyntaxEvidenceStatus payload == BusinessSyntaxEvidencePassed

businessSyntaxEvidencePayloads :: Bool -> Bool -> Bool -> Bool -> [BusinessSyntaxEvidencePayload]
businessSyntaxEvidencePayloads runtimePipelinePassed domainBusinessBoundaryPassed domainVocabularyBoundaryPassed effectFacadeBoundaryPassed =
  [ businessEvidence
      "business-syntax-needs-lowering"
      needsLoweringPassed
      "capability requires lower to needs"
      (observedBool needsLoweringPassed)
      "BusinessNeedsLoweringArtifact"
  , businessEvidence
      "business-syntax-take-lowering"
      takeLoweringPassed
      "capability input lowers to take"
      (observedBool takeLoweringPassed)
      "BusinessTakeLoweringArtifact"
  , businessEvidence
      "business-syntax-make-lowering"
      makeLoweringPassed
      "capability output lowers to make"
      (observedBool makeLoweringPassed)
      "BusinessMakeLoweringArtifact"
  , businessEvidence
      "business-syntax-uses-lowering"
      usesLoweringPassed
      "capability uses lowers to uses"
      (observedBool usesLoweringPassed)
      "BusinessUsesLoweringArtifact"
  , businessEvidence
      "business-syntax-external-make-lowering"
      externalMakeLoweringPassed
      "capability uses also emits externalMake boundary"
      (observedBool externalMakeLoweringPassed)
      "BusinessExternalMakeLoweringArtifact"
  , businessEvidence
      "business-syntax-transform-lowering"
      transformLoweringPassed
      "capability transform lowers to transform step"
      (observedBool transformLoweringPassed)
      "BusinessTransformLoweringArtifact"
  , businessEvidence
      "business-syntax-effects-facade-lowering"
      effectFacadeLoweringPassed
      "Effects.* facade matches Domain.Business lowering"
      (observedBool effectFacadeLoweringPassed)
      "BusinessEffectsFacadeLoweringArtifact"
  , businessEvidence
      "business-syntax-domain-business-boundary"
      domainBusinessBoundaryPassed
      "Domain.Business imports Framework.Business without Framework.Effect"
      (observedBool domainBusinessBoundaryPassed)
      "DomainBusinessBoundaryArtifact"
  , businessEvidence
      "business-syntax-domain-effect-vocabulary-boundary"
      domainVocabularyBoundaryPassed
      "Domain.EffectVocabulary imports Framework.Business without Framework.Effect, Framework.Runtime, or Bootstrap.*"
      (observedBool domainVocabularyBoundaryPassed)
      "DomainEffectVocabularyBoundaryArtifact"
  , businessEvidence
      "business-syntax-effects-facade-boundary"
      effectFacadeBoundaryPassed
      "Effects.* lowering facade imports Framework.Business without Framework.Effect"
      (observedBool effectFacadeBoundaryPassed)
      "BusinessEffectsFacadeBoundaryArtifact"
  , businessEvidence
      "business-syntax-handler-binding-alignment"
      (null businessShapeIssues)
      "handler bindings align with capability consumes/emits/claims"
      (observedBusinessShapeIssues businessShapeIssues)
      "BusinessHandlerBindingAlignmentArtifact"
  , businessEvidence
      "business-syntax-pipeline-adjacent-transform"
      pipelineLoweringPassed
      "pipeline adjacent types define transform candidates"
      (observedBool pipelineLoweringPassed)
      "BusinessPipelineTransformArtifact"
  , businessEvidence
      "business-syntax-runtime-pipeline-adapter"
      runtimePipelinePassed
      "typed runtime executes capability-lowered pipeline with transforms"
      (observedBool runtimePipelinePassed)
      "BusinessRuntimePipelineAdapterArtifact"
  , businessEvidence
      "effect-system-boundary-metadata"
      effectSystemBoundaryMetadataPassed
      "EffectSystemBoundary metadata exposes imports, private facts, and exports for runtime semantics"
      (observedBool effectSystemBoundaryMetadataPassed)
      "EffectSystemBoundaryMetadataArtifact"
  , businessEvidence
      "business-syntax-capability-system-boundary"
      capabilitySystemBoundaryPassed
      "capability lowers to EffectSystemBoundary with send, handler, transform, policy, and pipeline contracts"
      (observedBool capabilitySystemBoundaryPassed)
      "BusinessCapabilitySystemBoundaryArtifact"
  ]

businessEvidence :: String -> Bool -> String -> String -> String -> BusinessSyntaxEvidencePayload
businessEvidence claim passed expected observed artifact =
  BusinessSyntaxEvidencePayload
    { businessSyntaxEvidenceClaim = claim
    , businessSyntaxEvidenceStatus =
        if passed
          then BusinessSyntaxEvidencePassed
          else BusinessSyntaxEvidenceFailed
    , businessSyntaxEvidenceExpected = expected
    , businessSyntaxEvidenceObserved = observed
    , businessSyntaxEvidenceArtifact = artifact
    }

observedBool :: Bool -> String
observedBool True =
  "passed"
observedBool False =
  "failed"

observedBusinessShapeIssues :: [BusinessShapeIssue] -> String
observedBusinessShapeIssues [] =
  "no business shape issues"
observedBusinessShapeIssues issues =
  joinWith "; " (map renderBusinessShapeIssue issues)

evidenceFailures :: [BusinessSyntaxEvidencePayload] -> [String]
evidenceFailures payloads =
  [ businessSyntaxEvidenceClaim payload
      ++ ": "
      ++ businessSyntaxEvidenceObserved payload
  | payload <- payloads
  , not (businessSyntaxEvidencePayloadPassed payload)
  ]

failWhenEvidenceFailed :: [String] -> IO ()
failWhenEvidenceFailed [] =
  pure ()
failWhenEvidenceFailed failures =
  ioError (userError (unlines failures))

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

effectSystemBoundaryMetadataPassed :: Bool
effectSystemBoundaryMetadataPassed =
  explicitBoundaryMatches
    && derivedBoundaryMatches
    && derivedRuntimeSystemMatches
    && defaultEffectUnitBoundaryMatches
    && explicitEffectUnitMetadataMatches
    && explicitEffectUnitBoundaryMatches
    && explicitEffectUnitSystemMatches
  where
    privateFact =
      WorkflowFact "PipelinePrivateFact"
    explicitBoundary =
      Workflow.systemBoundary
        (Workflow.EffectSystemName "BoundaryProbe")
        [pipelineSourceFact]
        [privateFact]
        [pipelineAdapterFact]
    derivedSystem =
      Workflow.effectSystem
        (Workflow.EffectSystemName "BoundaryProbe")
        (Workflow.factItems [pipelineAdapterFact])
    derivedBoundary =
      Workflow.effectSystemBoundary derivedSystem
    derivedRuntimeSystem =
      Workflow.effectSystemFromBoundary explicitBoundary
    defaultEffectUnit =
      Effect.effect
        (EffectName "BoundaryProbe")
        [Effect.fact pipelineAdapterFact ([] :: [ProducerStep])]
    defaultEffectUnitBoundary =
      Effect.effectUnitBoundary defaultEffectUnit
    explicitEffectUnit =
      Effect.effectSystem
        (EffectName "BoundaryProbe")
        [ Effect.imports [pipelineSourceFact]
        , Effect.privateFacts [privateFact]
        , Effect.exports [pipelineAdapterFact]
        , Effect.pipeline "BoundaryProbePipeline" [UserName, ReportInput, ReportOutput]
        , Effect.handler GenerateReport RuntimeGenerateReport
        ]
        [ Effect.fact privateFact
            [ Effect.needs pipelineSourceFact
            , Effect.take UserName
            , Effect.transform UserName ReportInput UserNameToReportInput
            ]
        , Effect.fact pipelineAdapterFact
            [ Effect.needs privateFact
            , Effect.uses GenerateReport
            , Effect.make ReportOutput
            ]
        , Effect.externalMake GenerateReport ReportInput ReportOutput
        ]
    explicitEffectUnitBoundary =
      Effect.effectUnitBoundary explicitEffectUnit
    explicitEffectUnitSystem =
      Effect.effectUnitSystem explicitEffectUnit
    explicitBoundaryMatches =
      Workflow.effectSystemBoundaryName explicitBoundary == Workflow.EffectSystemName "BoundaryProbe"
        && Workflow.effectSystemBoundaryImports explicitBoundary == [pipelineSourceFact]
        && Workflow.effectSystemBoundaryPrivateFacts explicitBoundary == [privateFact]
        && Workflow.effectSystemBoundaryExports explicitBoundary == [pipelineAdapterFact]
    derivedBoundaryMatches =
      Workflow.effectSystemBoundaryName derivedBoundary == Workflow.EffectSystemName "BoundaryProbe"
        && null (Workflow.effectSystemBoundaryImports derivedBoundary)
        && null (Workflow.effectSystemBoundaryPrivateFacts derivedBoundary)
        && Workflow.effectSystemBoundaryExports derivedBoundary == [pipelineAdapterFact]
    derivedRuntimeSystemMatches =
      Workflow.effectSystemName derivedRuntimeSystem == Workflow.EffectSystemName "BoundaryProbe"
        && case Workflow.effectSystemSuccess derivedRuntimeSystem of
          Workflow.FactItems requirement ->
            Workflow.requirementItems requirement == [pipelineAdapterFact]
          _ ->
            False
    defaultEffectUnitBoundaryMatches =
      Workflow.effectSystemBoundaryName defaultEffectUnitBoundary == Workflow.EffectSystemName "BoundaryProbe"
        && null (Workflow.effectSystemBoundaryImports defaultEffectUnitBoundary)
        && null (Workflow.effectSystemBoundaryPrivateFacts defaultEffectUnitBoundary)
        && Workflow.effectSystemBoundaryExports defaultEffectUnitBoundary == [pipelineAdapterFact]
    explicitEffectUnitMetadataMatches =
      effectUnitImports explicitEffectUnit == [pipelineSourceFact]
        && effectUnitPrivateFacts explicitEffectUnit == [privateFact]
        && effectUnitExports explicitEffectUnit == [pipelineAdapterFact]
        && Effect.effectUnitProducedFacts explicitEffectUnit == [privateFact, pipelineAdapterFact]
        && effectUnitPipelineArtifacts explicitEffectUnit == [show UserName, show ReportInput, show ReportOutput]
        && map Effect.effectSystemHandlerName (effectUnitHandlers explicitEffectUnit) == [RuntimeGenerateReport]
        && map Effect.effectSystemHandlerSend (effectUnitHandlers explicitEffectUnit) == [GenerateReport]
    explicitEffectUnitBoundaryMatches =
      Workflow.effectSystemBoundaryName explicitEffectUnitBoundary == Workflow.EffectSystemName "BoundaryProbe"
        && Workflow.effectSystemBoundaryImports explicitEffectUnitBoundary == [pipelineSourceFact]
        && Workflow.effectSystemBoundaryPrivateFacts explicitEffectUnitBoundary == [privateFact]
        && Workflow.effectSystemBoundaryExports explicitEffectUnitBoundary == [pipelineAdapterFact]
        && boundaryPipelineArtifacts explicitEffectUnitBoundary == [show UserName, show ReportInput, show ReportOutput]
        && map Workflow.effectSystemBoundaryHandlerName (Workflow.effectSystemBoundaryHandlers explicitEffectUnitBoundary) == [show RuntimeGenerateReport]
        && map show (Workflow.effectSystemBoundarySends explicitEffectUnitBoundary) == [show GenerateReport]
        && map show (Workflow.effectSystemBoundaryTransforms explicitEffectUnitBoundary) == [show UserNameToReportInput]
    explicitEffectUnitSystemMatches =
      Workflow.effectSystemBoundaryExplicit explicitEffectUnitSystem
        && case Workflow.effectSystemSuccess explicitEffectUnitSystem of
          Workflow.FactItems requirement ->
            Workflow.requirementItems requirement == [pipelineAdapterFact]
          _ ->
            False

capabilitySystemBoundaryPassed :: Bool
capabilitySystemBoundaryPassed =
  generateReportBoundaryMatches
    && generateReportSystemMatches
    && policyBoundaryMatches
  where
    generateBoundary =
      capabilityEffectSystemBoundary "GenerateReportSystem" generateReportCapability
    generateSystem =
      capabilityEffectSystem "GenerateReportSystem" generateReportCapability
    generateReportBoundaryMatches =
      Workflow.effectSystemBoundaryName generateBoundary == Workflow.EffectSystemName "GenerateReportSystem"
        && Workflow.effectSystemBoundaryImports generateBoundary
          == [ AddCalculatedFact
             , FactorialCalculatedFact
             , SquaresCalculatedFact
             , UserNameAskedFact
             ]
        && null (Workflow.effectSystemBoundaryPrivateFacts generateBoundary)
        && Workflow.effectSystemBoundaryExports generateBoundary == [ReportGeneratedFact]
        && map show (Workflow.effectSystemBoundarySends generateBoundary) == [show GenerateReport]
        && map (show . Workflow.effectSystemBoundaryHandlerSend) (Workflow.effectSystemBoundaryHandlers generateBoundary) == [show GenerateReport]
        && map Workflow.effectSystemBoundaryHandlerName (Workflow.effectSystemBoundaryHandlers generateBoundary) == [show RuntimeGenerateReport]
        && map show (Workflow.effectSystemBoundaryTransforms generateBoundary) == [show UserNameToReportInput]
        && boundaryPipelineArtifacts generateBoundary == [show UserName, show ReportInput, show ReportOutput]
    generateReportSystemMatches =
      Workflow.effectSystemName generateSystem == Workflow.EffectSystemName "GenerateReportSystem"
        && Workflow.effectSystemBoundaryExplicit generateSystem
        && Workflow.effectSystemBoundaryExports (Workflow.effectSystemBoundary generateSystem) == [ReportGeneratedFact]
    policyBoundaryMatches =
      map show (Workflow.effectSystemBoundarySends policyBoundary) == [show GenerateReport]
        && map show (Workflow.effectSystemBoundaryPolicies policyBoundary)
          == [ "idempotent " ++ show GenerateReport
             , "retry-once " ++ show GenerateReport
             ]
    policyBoundary =
      capabilityEffectSystemBoundary
        "PolicyProbeSystem"
        ( capability
            "PolicyProbe"
            [ uses GenerateReport ReportInput ReportOutput
            , policy (idempotentPolicy GenerateReport)
            , policy (retryOnce GenerateReport)
            , produces ReportGeneratedFact
            ]
        )

boundaryPipelineArtifacts :: Workflow.EffectSystemBoundary Workflow.WorkflowFact -> [String]
boundaryPipelineArtifacts boundary =
  concatMap
    (map show . Workflow.effectSystemBoundaryPipelineArtifacts)
    (Workflow.effectSystemBoundaryPipelines boundary)

effectUnitPipelineArtifacts :: EffectUnit -> [String]
effectUnitPipelineArtifacts unit =
  concatMap
    (map show . Effect.effectSystemPipelineTypes)
    (effectUnitPipelines unit)

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

effectsFacadeBoundaryPassed :: IO Bool
effectsFacadeBoundaryPassed = do
  sources <-
    mapM
      readFile
      [ "domain-app/src/Effects/System.hs"
      , "domain-app/src/Effects/User.hs"
      , "domain-app/src/Effects/Report.hs"
      , "domain-app/src/Effects/Logging.hs"
      ]
  pure (all effectFacadeSourcePassed sources)

effectFacadeSourcePassed :: String -> Bool
effectFacadeSourcePassed source =
  "import Framework.Business" `isInfixOf` source
    && not ("import Framework.Effect" `isInfixOf` source)
    && not ("import Framework.Runtime" `isInfixOf` source)
    && not ("import Bootstrap." `isInfixOf` source)

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
    && effectUnitImports actual == effectUnitImports expected
    && effectUnitPrivateFacts actual == effectUnitPrivateFacts expected
    && effectUnitExports actual == effectUnitExports expected
    && effectUnitPipelines actual == effectUnitPipelines expected
    && effectUnitHandlers actual == effectUnitHandlers expected
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

renderBusinessSyntaxEvidencePayloadsJson :: [BusinessSyntaxEvidencePayload] -> String
renderBusinessSyntaxEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "business-syntax-evidence.v1")
    , jsonField "status" (jsonString statusText)
    , jsonField "payloads" (jsonArray (map businessSyntaxEvidencePayloadJson payloads))
    ]
  where
    statusText =
      if all businessSyntaxEvidencePayloadPassed payloads
        then "passed"
        else "failed"

businessSyntaxEvidencePayloadJson :: BusinessSyntaxEvidencePayload -> String
businessSyntaxEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (businessSyntaxEvidenceClaim payload))
    , jsonField "status" (jsonString (renderBusinessSyntaxEvidenceStatus (businessSyntaxEvidenceStatus payload)))
    , jsonField "expected" (jsonString (businessSyntaxEvidenceExpected payload))
    , jsonField "observed" (jsonString (businessSyntaxEvidenceObserved payload))
    , jsonField "artifact" (jsonString (businessSyntaxEvidenceArtifact payload))
    ]

renderBusinessSyntaxEvidenceStatus :: BusinessSyntaxEvidenceStatus -> String
renderBusinessSyntaxEvidenceStatus BusinessSyntaxEvidencePassed =
  "passed"
renderBusinessSyntaxEvidenceStatus BusinessSyntaxEvidenceFailed =
  "failed"

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
