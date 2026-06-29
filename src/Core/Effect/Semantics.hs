module Core.Effect.Semantics
  ( EffectSemantics (..)
  , FactContract (..)
  , FactSource (..)
  , HandlerContract (..)
  , ProducerRequirement (..)
  , ProfileContract (..)
  , SendContract (..)
  , SendUse (..)
  , TakeMakeRule (..)
  , TakeMakeSource (..)
  , effectSemantics
  , factContractFor
  , handlerContractFor
  , handlerContractsFor
  , profileContractFor
  , sendContractFor
  , takeMakeRuleFor
  , takeMakeRulesFor
  ) where

import AST.Facts
  ( WorkflowFact
  )
import Effects.EffectTheory
  ( EffectProfile (..)
  , EffectSection (..)
  , EffectTheory (..)
  , EffectUnit (..)
  , FactProducer (..)
  , ImplementationBinding (..)
  , ProducerStep (..)
  , ProfileName
  , SendBoundary (..)
  , SendName
  , SendSignature
  )

data EffectSemantics = EffectSemantics
  { semanticFactContracts :: [FactContract]
  , semanticSendContracts :: [SendContract]
  , semanticProfileContracts :: [ProfileContract]
  , semanticTakeMakeRules :: [TakeMakeRule]
  }

data FactContract = FactContract
  { factContractFact :: WorkflowFact
  , factContractSource :: FactSource
  , factContractRequirements :: [ProducerRequirement]
  , factContractSendUses :: [SendUse]
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

data TakeMakeRule = TakeMakeRule
  { takeMakeRuleFact :: WorkflowFact
  , takeFacts :: [WorkflowFact]
  , makeFacts :: [WorkflowFact]
  , externalMakeNames :: [SendName]
  , failureMakeFacts :: [WorkflowFact]
  , takeMakeSource :: TakeMakeSource
  }
  deriving (Eq, Show)

data TakeMakeSource
  = InternalMake
  | ExternalTake
  deriving (Eq, Show)

data SendContract = SendContract
  { sendContractName :: SendName
  , sendContractSignature :: SendSignature
  }

data ProfileContract = ProfileContract
  { profileContractName :: ProfileName
  , profileContractHandlers :: [HandlerContract]
  }

data HandlerContract = HandlerContract
  { handlerContractSend :: SendName
  , handlerContractImplementation :: ImplementationBinding
  , handlerContractSignature :: Maybe SendSignature
  }

effectSemantics :: EffectTheory -> EffectSemantics
effectSemantics effects =
  EffectSemantics
    { semanticFactContracts = factContracts
    , semanticSendContracts = sendContracts
    , semanticProfileContracts = map (profileContractFromProfile sendContracts) profiles
    , semanticTakeMakeRules = map takeMakeRuleFromFactContract factContracts
    }
  where
    units =
      theoryUnits effects
    factContracts =
      concatMap unitFactContracts units
    sendContracts =
      concatMap unitSendContracts units
    profiles =
      concatMap unitProfiles units

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

profileContractFor :: EffectSemantics -> ProfileName -> Maybe ProfileContract
profileContractFor semantics currentProfile =
  firstJust
    [ Just currentContract
    | currentContract <- semanticProfileContracts semantics
    , profileContractName currentContract == currentProfile
    ]

handlerContractFor :: EffectSemantics -> ProfileName -> SendName -> Maybe HandlerContract
handlerContractFor semantics currentProfile currentSend =
  firstJust
    [ Just currentHandler
    | currentProfileContract <- semanticProfileContracts semantics
    , profileContractName currentProfileContract == currentProfile
    , currentHandler <- profileContractHandlers currentProfileContract
    , handlerContractSend currentHandler == currentSend
    ]

handlerContractsFor :: EffectSemantics -> ProfileName -> [SendName] -> [HandlerContract]
handlerContractsFor semantics currentProfile requiredSends =
  [ currentHandler
  | currentSend <- requiredSends
  , Just currentHandler <- [handlerContractFor semantics currentProfile currentSend]
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

unitProfiles :: EffectUnit -> [EffectProfile]
unitProfiles =
  concatMap sectionProfiles . effectUnitSections

sectionFactContracts :: EffectSection -> [FactContract]
sectionFactContracts (FactClaimSection currentProducer) =
  [factContractFromProducer currentProducer]
sectionFactContracts _ =
  []

sectionSendContracts :: EffectSection -> [SendContract]
sectionSendContracts (SendSection currentSend) =
  [sendContractFromBoundary currentSend]
sectionSendContracts _ =
  []

sectionProfiles :: EffectSection -> [EffectProfile]
sectionProfiles (ProfileSection currentProfile) =
  [currentProfile]
sectionProfiles _ =
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
    }
  where
    steps =
      producerSteps currentProducer

takeMakeRuleFromFactContract :: FactContract -> TakeMakeRule
takeMakeRuleFromFactContract currentContract =
  TakeMakeRule
    { takeMakeRuleFact = factContractFact currentContract
    , takeFacts = concatMap takeFactFromRequirement requirements
    , makeFacts = [factContractFact currentContract]
    , externalMakeNames = map sendUseName (factContractSendUses currentContract)
    , failureMakeFacts = concatMap failureFactFromRequirement requirements
    , takeMakeSource = takeMakeSourceFromFactSource (factContractSource currentContract)
    }
  where
    requirements =
      factContractRequirements currentContract

takeFactFromRequirement :: ProducerRequirement -> [WorkflowFact]
takeFactFromRequirement (NeedsFact currentFact) =
  [currentFact]
takeFactFromRequirement _ =
  []

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
    }

profileContractFromProfile :: [SendContract] -> EffectProfile -> ProfileContract
profileContractFromProfile sendContracts currentProfile =
  ProfileContract
    { profileContractName = profileName currentProfile
    , profileContractHandlers =
        map (handlerContractFromBinding sendContracts) (profileImplementations currentProfile)
    }

handlerContractFromBinding :: [SendContract] -> ImplementationBinding -> HandlerContract
handlerContractFromBinding sendContracts currentBinding =
  HandlerContract
    { handlerContractSend = implementedSend currentBinding
    , handlerContractImplementation = currentBinding
    , handlerContractSignature =
        sendContractSignature <$> sendContractByName sendContracts (implementedSend currentBinding)
    }

sendContractByName :: [SendContract] -> SendName -> Maybe SendContract
sendContractByName sendContracts currentSend =
  firstJust
    [ Just currentContract
    | currentContract <- sendContracts
    , sendContractName currentContract == currentSend
    ]

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest
