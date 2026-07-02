{-# LANGUAGE PatternSynonyms #-}

module Core.Effect.Semantics
  ( BoundarySource (..)
  , EffectBoundary (..)
  , EffectSemantics (..)
  , FactContract (..)
  , FactSource (..)
  , IdempotencyPolicy (..)
  , PipeTake (..)
  , ProducerRequirement (..)
  , RetryPolicy (..)
  , SendContract (..)
  , SendUse (..)
  , TakeMakeRule (..)
  , TakeMakeSource (..)
  , TransformContract (..)
  , TransformUse (..)
  , effectSemantics
  , effectBoundariesForFact
  , factContractFor
  , sendContractFor
  , takeMakeRuleFor
  , takeMakeRulesFor
  , transformContractFor
  ) where

import AST.Facts
  ( WorkflowFact
  )
import Effects.EffectTheory
  ( EffectSection (..)
  , EffectTheory (..)
  , EffectUnit (..)
  , ExternalTakeBoundary (..)
  , FactProducer (..)
  , IdempotencyPolicy (..)
  , ProducerStep (..)
  , RetryPolicy (..)
  , SendBoundary (..)
  , SendName
  , SendPolicy (..)
  , SendSignature (..)
  , TransformName
  , TypeName (..)
  , pattern NoInput
  , pattern Unit
  )

data EffectSemantics = EffectSemantics
  { semanticFactContracts :: [FactContract]
  , semanticSendContracts :: [SendContract]
  , semanticTransformContracts :: [TransformContract]
  , semanticEffectBoundaries :: [EffectBoundary]
  , semanticTakeMakeRules :: [TakeMakeRule]
  }

data FactContract = FactContract
  { factContractFact :: WorkflowFact
  , factContractSource :: FactSource
  , factContractRequirements :: [ProducerRequirement]
  , factContractSendUses :: [SendUse]
  , factContractTransforms :: [TransformUse]
  , factContractPipeTakes :: [TypeName]
  , factContractPipeMakes :: [TypeName]
  , factContractErrorHandlers :: [SendName]
  }

data FactSource
  = ProducedInternally
  | ReceivedExternally
  deriving (Eq, Show)

data ProducerRequirement
  = NeedsFact WorkflowFact
  | OnFailureFact WorkflowFact
  deriving (Eq, Show)

data SendUse = SendUse
  { sendUseFact :: WorkflowFact
  , sendUseName :: SendName
  }
  deriving (Eq, Show)

data EffectBoundary
  = BoundaryExternalMake WorkflowFact SendName TypeName TypeName BoundarySource
  | BoundaryInternalTake WorkflowFact TypeName BoundarySource
  | BoundaryInternalMake WorkflowFact TypeName BoundarySource
  | BoundaryExternalTake WorkflowFact (Maybe TypeName) BoundarySource
  deriving (Eq, Show)

data BoundarySource
  = DerivedFromUses SendName
  | DerivedFromTransform TransformName
  | DeclaredExplicitly
  | DeclaredExternalTake
  deriving (Eq, Show)

data TakeMakeRule = TakeMakeRule
  { takeMakeRuleFact :: WorkflowFact
  , takeFacts :: [WorkflowFact]
  , pipeInputTypes :: [TypeName]
  , pipeOutputTypes :: [TypeName]
  , pipeTakeFacts :: [PipeTake]
  , makeFacts :: [WorkflowFact]
  , externalMakeNames :: [SendName]
  , transformUses :: [TransformUse]
  , errorHandlerNames :: [SendName]
  , failureMakeFacts :: [WorkflowFact]
  , takeMakeSource :: TakeMakeSource
  }
  deriving (Eq, Show)

data PipeTake = PipeTake
  { pipeTakeInput :: TypeName
  , pipeTakeFact :: WorkflowFact
  }
  deriving (Eq, Show)

data TransformUse = TransformUse
  { transformUseFact :: WorkflowFact
  , transformUseName :: TransformName
  , transformUseInput :: TypeName
  , transformUseOutput :: TypeName
  }
  deriving (Eq, Show)

data TransformContract = TransformContract
  { transformContractFact :: WorkflowFact
  , transformContractName :: TransformName
  , transformContractInput :: TypeName
  , transformContractOutput :: TypeName
  }
  deriving (Eq, Show)

data TakeMakeSource
  = InternalMake
  | ExternalTake
  deriving (Eq, Show)

data SendContract = SendContract
  { sendContractName :: SendName
  , sendContractSignature :: SendSignature
  , sendContractIdempotency :: IdempotencyPolicy
  , sendContractRetry :: RetryPolicy
  }

effectSemantics :: EffectTheory -> EffectSemantics
effectSemantics effects =
  EffectSemantics
    { semanticFactContracts = factContracts
    , semanticSendContracts = sendContractsWithPolicies
    , semanticTransformContracts =
        transformContractsFromFactContracts factContracts
    , semanticEffectBoundaries =
        effectBoundariesFromFactContracts sendContractsWithPolicies factContracts
    , semanticTakeMakeRules = map (takeMakeRuleFromFactContract sendContractsWithPolicies factContracts) factContracts
    }
  where
    units =
      theoryUnits effects
    factContracts =
      concatMap unitFactContracts units
    sendContracts =
      concatMap unitSendContracts units
    sendPolicies =
      concatMap unitSendPolicies units
    sendContractsWithPolicies =
      applySendPolicies sendPolicies sendContracts

factContractFor :: EffectSemantics -> WorkflowFact -> Maybe FactContract
factContractFor semantics currentFact =
  firstJust
    [ Just currentContract
    | currentContract <- semanticFactContracts semantics
    , factContractFact currentContract == currentFact
    ]

sendContractFor :: EffectSemantics -> SendName -> Maybe SendContract
sendContractFor semantics currentSend =
  sendContractByName (semanticSendContracts semantics) currentSend

transformContractFor :: EffectSemantics -> TransformName -> Maybe TransformContract
transformContractFor semantics currentTransform =
  firstJust
    [ Just currentContract
    | currentContract <- semanticTransformContracts semantics
    , transformContractName currentContract == currentTransform
    ]

effectBoundariesForFact :: EffectSemantics -> WorkflowFact -> [EffectBoundary]
effectBoundariesForFact semantics currentFact =
  [ currentBoundary
  | currentBoundary <- semanticEffectBoundaries semantics
  , boundaryFact currentBoundary == currentFact
  ]

takeMakeRuleFor :: EffectSemantics -> WorkflowFact -> Maybe TakeMakeRule
takeMakeRuleFor semantics currentFact =
  firstJust
    [ Just currentRule
    | currentRule <- semanticTakeMakeRules semantics
    , takeMakeRuleFact currentRule == currentFact
    ]

takeMakeRulesFor :: EffectSemantics -> [WorkflowFact] -> [TakeMakeRule]
takeMakeRulesFor semantics requiredFacts =
  [ currentRule
  | currentFact <- requiredFacts
  , Just currentRule <- [takeMakeRuleFor semantics currentFact]
  ]

unitFactContracts :: EffectUnit -> [FactContract]
unitFactContracts =
  concatMap sectionFactContracts . effectUnitSections

unitSendContracts :: EffectUnit -> [SendContract]
unitSendContracts =
  concatMap sectionSendContracts . effectUnitSections

unitSendPolicies :: EffectUnit -> [SendPolicy]
unitSendPolicies =
  concatMap sectionSendPolicies . effectUnitSections

sectionFactContracts :: EffectSection -> [FactContract]
sectionFactContracts (FactClaimSection currentProducer) =
  [factContractFromProducer currentProducer]
sectionFactContracts (ExternalTakeSection currentTake) =
  [factContractFromExternalTake currentTake]
sectionFactContracts _ =
  []

sectionSendContracts :: EffectSection -> [SendContract]
sectionSendContracts (SendSection currentSend) =
  [sendContractFromBoundary currentSend]
sectionSendContracts _ =
  []

sectionSendPolicies :: EffectSection -> [SendPolicy]
sectionSendPolicies (SendPolicySection currentPolicy) =
  [currentPolicy]
sectionSendPolicies _ =
  []

factContractFromProducer :: FactProducer -> FactContract
factContractFromProducer currentProducer =
  FactContract
    { factContractFact = producerFact currentProducer
    , factContractSource = sourceFromSteps steps
    , factContractRequirements = concatMap requirementFromStep steps
    , factContractSendUses =
        [ SendUse (producerFact currentProducer) currentSend
        | Uses currentSend <- steps
        ]
    , factContractTransforms =
        [ TransformUse (producerFact currentProducer) currentTransform currentInput currentOutput
        | Transform currentInput currentOutput currentTransform <- steps
        ]
    , factContractPipeTakes =
        unique (concatMap pipeTakeFromStep steps)
    , factContractPipeMakes =
        unique (concatMap pipeMakeFromStep steps)
    , factContractErrorHandlers =
        [ currentSend
        | Error currentSend <- steps
        ]
    }
  where
    steps =
      producerSteps currentProducer

factContractFromExternalTake :: ExternalTakeBoundary -> FactContract
factContractFromExternalTake currentTake =
  FactContract
    { factContractFact = externalTakeFact currentTake
    , factContractSource = ReceivedExternally
    , factContractRequirements = []
    , factContractSendUses = []
    , factContractTransforms = []
    , factContractPipeTakes = []
    , factContractPipeMakes =
        [ currentOutput
        | Just currentOutput <- [externalTakeOutput currentTake]
        , isPipeOutput currentOutput
        ]
    , factContractErrorHandlers = []
    }

effectBoundariesFromFactContracts :: [SendContract] -> [FactContract] -> [EffectBoundary]
effectBoundariesFromFactContracts sendContracts =
  unique . concatMap (effectBoundariesFromFactContract sendContracts)

effectBoundariesFromFactContract :: [SendContract] -> FactContract -> [EffectBoundary]
effectBoundariesFromFactContract sendContracts currentContract =
  externalTakeBoundaries currentContract
    ++ explicitPipeBoundaries currentContract
    ++ concatMap transformBoundaries (factContractTransforms currentContract)
    ++ concatMap (derivedBoundariesFromUse sendContracts (factContractFact currentContract)) (factContractSendUses currentContract)

externalTakeBoundaries :: FactContract -> [EffectBoundary]
externalTakeBoundaries currentContract =
  case factContractSource currentContract of
    ReceivedExternally ->
      case factContractPipeMakes currentContract of
        [] ->
          [BoundaryExternalTake (factContractFact currentContract) Nothing DeclaredExternalTake]
        currentOutputs ->
          concatMap externalTakeOutputBoundaries currentOutputs
    ProducedInternally ->
      []
  where
    externalTakeOutputBoundaries currentOutput =
      [ BoundaryExternalTake (factContractFact currentContract) (Just currentOutput) DeclaredExternalTake
      , BoundaryInternalMake (factContractFact currentContract) currentOutput DeclaredExternalTake
      ]

explicitPipeBoundaries :: FactContract -> [EffectBoundary]
explicitPipeBoundaries currentContract =
  case factContractSource currentContract of
    ReceivedExternally ->
      []
    ProducedInternally ->
      map explicitTakeBoundary (factContractPipeTakes currentContract)
        ++ map explicitMakeBoundary (factContractPipeMakes currentContract)
  where
    explicitTakeBoundary currentInput =
      BoundaryInternalTake (factContractFact currentContract) currentInput DeclaredExplicitly
    explicitMakeBoundary currentOutput =
      BoundaryInternalMake (factContractFact currentContract) currentOutput DeclaredExplicitly

transformBoundaries :: TransformUse -> [EffectBoundary]
transformBoundaries currentTransform =
  [ BoundaryInternalTake
      (transformUseFact currentTransform)
      (transformUseInput currentTransform)
      (DerivedFromTransform (transformUseName currentTransform))
  , BoundaryInternalMake
      (transformUseFact currentTransform)
      (transformUseOutput currentTransform)
      (DerivedFromTransform (transformUseName currentTransform))
  ]

derivedBoundariesFromUse :: [SendContract] -> WorkflowFact -> SendUse -> [EffectBoundary]
derivedBoundariesFromUse sendContracts currentFact currentUse =
  case sendContractByName sendContracts (sendUseName currentUse) of
    Nothing ->
      []
    Just currentSendContract ->
      let currentSignature =
            sendContractSignature currentSendContract
       in externalMakeBoundary currentSignature
            ++ internalTakeBoundary currentSignature
            ++ internalMakeBoundary currentSignature
  where
    currentSend =
      sendUseName currentUse
    currentSource =
      DerivedFromUses currentSend
    externalMakeBoundary currentSignatureValue =
      [ BoundaryExternalMake
          currentFact
          currentSend
          (sendInput currentSignatureValue)
          (sendOutput currentSignatureValue)
          currentSource
      ]
    internalTakeBoundary currentSignatureValue
      | isPipeInput (sendInput currentSignatureValue) =
          [BoundaryInternalTake currentFact (sendInput currentSignatureValue) currentSource]
      | otherwise =
          []
    internalMakeBoundary currentSignatureValue
      | isPipeOutput (sendOutput currentSignatureValue) =
          [BoundaryInternalMake currentFact (sendOutput currentSignatureValue) currentSource]
      | otherwise =
          []

takeMakeRuleFromFactContract :: [SendContract] -> [FactContract] -> FactContract -> TakeMakeRule
takeMakeRuleFromFactContract sendContracts factContracts currentContract =
  TakeMakeRule
    { takeMakeRuleFact = factContractFact currentContract
    , takeFacts = concatMap takeFactFromRequirement requirements
    , pipeInputTypes = inputTypes
    , pipeOutputTypes = outputTypes
    , pipeTakeFacts = pipeTakes
    , makeFacts = [factContractFact currentContract]
    , externalMakeNames = map sendUseName (factContractSendUses currentContract)
    , transformUses = factContractTransforms currentContract
    , errorHandlerNames = factContractErrorHandlers currentContract
    , failureMakeFacts = concatMap failureFactFromRequirement requirements
    , takeMakeSource = takeMakeSourceFromFactSource (factContractSource currentContract)
    }
  where
    requirements =
      factContractRequirements currentContract
    inputTypes =
      pipeInputTypesFromContract sendContracts currentContract
    outputTypes =
      pipeOutputTypesFromContract sendContracts currentContract
    pipeTakes =
      [ PipeTake currentInput sourceFact
      | currentInput <- inputTypes
      , sourceFact <- pipeSourceFactsFor sendContracts factContracts currentContract currentInput
      ]

takeFactFromRequirement :: ProducerRequirement -> [WorkflowFact]
takeFactFromRequirement (NeedsFact currentFact) =
  [currentFact]
takeFactFromRequirement _ =
  []

pipeTakeFromStep :: ProducerStep -> [TypeName]
pipeTakeFromStep (Take currentInput)
  | isPipeInput currentInput =
      [currentInput]
pipeTakeFromStep _ =
  []

pipeMakeFromStep :: ProducerStep -> [TypeName]
pipeMakeFromStep (Make currentOutput)
  | isPipeOutput currentOutput =
      [currentOutput]
pipeMakeFromStep _ =
  []

transformContractsFromFactContracts :: [FactContract] -> [TransformContract]
transformContractsFromFactContracts =
  unique . concatMap transformContractsFromFactContract

transformContractsFromFactContract :: FactContract -> [TransformContract]
transformContractsFromFactContract currentContract =
  [ TransformContract
      { transformContractFact = transformUseFact currentTransform
      , transformContractName = transformUseName currentTransform
      , transformContractInput = transformUseInput currentTransform
      , transformContractOutput = transformUseOutput currentTransform
      }
  | currentTransform <- factContractTransforms currentContract
  ]

failureFactFromRequirement :: ProducerRequirement -> [WorkflowFact]
failureFactFromRequirement (OnFailureFact currentFact) =
  [currentFact]
failureFactFromRequirement _ =
  []

takeMakeSourceFromFactSource :: FactSource -> TakeMakeSource
takeMakeSourceFromFactSource ProducedInternally =
  InternalMake
takeMakeSourceFromFactSource ReceivedExternally =
  ExternalTake

sourceFromSteps :: [ProducerStep] -> FactSource
sourceFromSteps steps
  | any isExternal steps = ReceivedExternally
  | otherwise = ProducedInternally

isExternal :: ProducerStep -> Bool
isExternal External =
  True
isExternal _ =
  False

requirementFromStep :: ProducerStep -> [ProducerRequirement]
requirementFromStep (Needs currentFact) =
  [NeedsFact currentFact]
requirementFromStep (OnFailure currentFact) =
  [OnFailureFact currentFact]
requirementFromStep _ =
  []

sendContractFromBoundary :: SendBoundary -> SendContract
sendContractFromBoundary currentBoundary =
  SendContract
    { sendContractName = sendBoundaryName currentBoundary
    , sendContractSignature = sendBoundarySignature currentBoundary
    , sendContractIdempotency = NonIdempotent
    , sendContractRetry = NoRetry
    }

applySendPolicies :: [SendPolicy] -> [SendContract] -> [SendContract]
applySendPolicies policies =
  map (applyPoliciesToSend policies)

applyPoliciesToSend :: [SendPolicy] -> SendContract -> SendContract
applyPoliciesToSend policies currentContract =
  foldl applySendPolicy currentContract matchingPolicies
  where
    matchingPolicies =
      [ currentPolicy
      | currentPolicy <- policies
      , sendPolicyName currentPolicy == sendContractName currentContract
      ]

applySendPolicy :: SendContract -> SendPolicy -> SendContract
applySendPolicy currentContract currentPolicy =
  currentContract
    { sendContractIdempotency =
        maybe (sendContractIdempotency currentContract) id (sendPolicyIdempotency currentPolicy)
    , sendContractRetry =
        maybe (sendContractRetry currentContract) id (sendPolicyRetry currentPolicy)
    }

sendContractByName :: [SendContract] -> SendName -> Maybe SendContract
sendContractByName sendContracts currentSend =
  firstJust
    [ Just currentContract
    | currentContract <- sendContracts
    , sendContractName currentContract == currentSend
    ]

pipeInputTypesFromContract :: [SendContract] -> FactContract -> [TypeName]
pipeInputTypesFromContract sendContracts currentContract =
  unique
    ( factContractPipeTakes currentContract
        ++ [ transformUseInput currentTransform
           | currentTransform <- factContractTransforms currentContract
           , isPipeInput (transformUseInput currentTransform)
           ]
        ++ [ sendInput currentSignature
           | currentSignature <- sendUseSignatures sendContracts currentContract
           , isPipeInput (sendInput currentSignature)
           ]
    )

pipeOutputTypesFromContract :: [SendContract] -> FactContract -> [TypeName]
pipeOutputTypesFromContract sendContracts currentContract =
  unique
    ( factContractPipeMakes currentContract
        ++ [ transformUseOutput currentTransform
           | currentTransform <- factContractTransforms currentContract
           , isPipeOutput (transformUseOutput currentTransform)
           ]
        ++ [ sendOutput currentSignature
           | currentSignature <- sendUseSignatures sendContracts currentContract
           , isPipeOutput (sendOutput currentSignature)
           ]
    )

sendUseSignatures :: [SendContract] -> FactContract -> [SendSignature]
sendUseSignatures sendContracts currentContract =
  [ sendContractSignature currentSend
  | currentUse <- factContractSendUses currentContract
  , currentSend <- sendContracts
  , sendContractName currentSend == sendUseName currentUse
  ]

pipeSourceFactsFor ::
  [SendContract] ->
  [FactContract] ->
  FactContract ->
  TypeName ->
  [WorkflowFact]
pipeSourceFactsFor sendContracts factContracts currentContract currentInput =
  [ factContractFact sourceContract
  | sourceContract <- factContracts
  , factContractFact sourceContract /= factContractFact currentContract
  , currentInput `elem` pipeOutputTypesFromContract sendContracts sourceContract
  ]

isPipeInput :: TypeName -> Bool
isPipeInput NoInput =
  False
isPipeInput Unit =
  False
isPipeInput _ =
  True

isPipeOutput :: TypeName -> Bool
isPipeOutput NoInput =
  False
isPipeOutput Unit =
  False
isPipeOutput _ =
  True

boundaryFact :: EffectBoundary -> WorkflowFact
boundaryFact currentBoundary =
  case currentBoundary of
    BoundaryExternalMake currentFact _ _ _ _ ->
      currentFact
    BoundaryInternalTake currentFact _ _ ->
      currentFact
    BoundaryInternalMake currentFact _ _ ->
      currentFact
    BoundaryExternalTake currentFact _ _ ->
      currentFact

unique :: Eq item => [item] -> [item]
unique =
  foldl addUnique []
  where
    addUnique items item
      | item `elem` items = items
      | otherwise = items ++ [item]

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest
