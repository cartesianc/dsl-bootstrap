{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Business
  ( BusinessShapeIssue (..)
  , Capability (..)
  , CapabilityClause
  , CapabilityPolicy (..)
  , CapabilityUse (..)
  , EffectName (..)
  , HandlerBindingSpec (..)
  , HandlerName (..)
  , Pipeline (..)
  , SendName (..)
  , TransformBindingSpec (..)
  , TransformName (..)
  , TypeName (..)
  , WorkflowFact (..)
  , pattern ErrorInput
  , pattern NoInput
  , pattern Unit
  , businessShapePassed
  , capabilitiesEffect
  , capability
  , capabilityEffectSections
  , checkFactArtifactInternalShape
  , checkBusinessShape
  , handler
  , handlerBinding
  , idempotentPolicy
  , input
  , onError
  , output
  , pipeline
  , pipelineTransformCandidates
  , policy
  , produces
  , renderBusinessShapeIssue
  , requires
  , retryOnce
  , transformBinding
  , transform
  , uses
  ) where

import qualified Bootstrap.Effect as Effect
import Bootstrap.Effect
  ( EffectName
  , EffectSection (..)
  , EffectUnit
  , FactProducer (..)
  , HandlerName
  , ProducerStep (..)
  , SendName
  , TransformName
  , TypeName
  , WorkflowFact
  , pattern ErrorInput
  , pattern NoInput
  , pattern Unit
  )

data Capability = Capability
  { capabilityName :: String
  , capabilityRequires :: [WorkflowFact]
  , capabilityInput :: [TypeName]
  , capabilityOutput :: [TypeName]
  , capabilityUses :: [CapabilityUse]
  , capabilityErrors :: [CapabilityUse]
  , capabilityProduces :: [WorkflowFact]
  , capabilityPolicy :: [CapabilityPolicy]
  , capabilityPipelines :: [Pipeline]
  , capabilityHandlers :: [HandlerBindingSpec]
  , capabilityTransforms :: [TransformBindingSpec]
  }
  deriving (Eq, Show)

data CapabilityUse = CapabilityUse
  { capabilityUseSend :: SendName
  , capabilityUseInput :: TypeName
  , capabilityUseOutput :: TypeName
  }
  deriving (Eq, Show)

data CapabilityPolicy
  = CapabilityRetryOnce SendName
  | CapabilityIdempotent SendName
  deriving (Eq, Show)

data Pipeline = Pipeline
  { pipelineName :: String
  , pipelineTypes :: [TypeName]
  }
  deriving (Eq, Show)

data HandlerBindingSpec = HandlerBindingSpec
  { handlerBindingSpecName :: HandlerName
  , handlerBindingSpecImplements :: String
  , handlerBindingSpecConsumes :: [TypeName]
  , handlerBindingSpecEmits :: [TypeName]
  , handlerBindingSpecClaims :: [WorkflowFact]
  }
  deriving (Eq, Show)

data TransformBindingSpec = TransformBindingSpec
  { transformBindingSpecName :: TransformName
  , transformBindingSpecInput :: TypeName
  , transformBindingSpecOutput :: TypeName
  }
  deriving (Eq, Show)

data CapabilityClause
  = CapabilityRequires WorkflowFact
  | CapabilityInput TypeName
  | CapabilityOutput TypeName
  | CapabilityUses CapabilityUse
  | CapabilityError CapabilityUse
  | CapabilityProduces WorkflowFact
  | CapabilityPolicyClause CapabilityPolicy
  | CapabilityPipeline Pipeline
  | CapabilityHandler HandlerBindingSpec
  | CapabilityTransform TransformBindingSpec

data BusinessShapeIssue
  = CapabilityHasNoProducer String
  | HandlerImplementsUnknownCapability HandlerName String
  | HandlerConsumesMismatch HandlerName String [TypeName] [TypeName]
  | HandlerEmitsMismatch HandlerName String [TypeName] [TypeName]
  | HandlerClaimsMismatch HandlerName String [WorkflowFact] [WorkflowFact]
  | TransformBindingOutsidePipeline TransformName TypeName TypeName
  | FactNameMissingSuffix WorkflowFact
  | ArtifactNameLooksLikeFact TypeName
  | FactArtifactNameCollision WorkflowFact TypeName
  deriving (Eq, Show)

capability :: String -> [CapabilityClause] -> Capability
capability name =
  foldl applyCapabilityClause emptyCapability
  where
    emptyCapability =
      Capability
        { capabilityName = name
        , capabilityRequires = []
        , capabilityInput = []
        , capabilityOutput = []
        , capabilityUses = []
        , capabilityErrors = []
        , capabilityProduces = []
        , capabilityPolicy = []
        , capabilityPipelines = []
        , capabilityHandlers = []
        , capabilityTransforms = []
        }

applyCapabilityClause :: Capability -> CapabilityClause -> Capability
applyCapabilityClause current clause =
  case clause of
    CapabilityRequires fact ->
      current {capabilityRequires = appendUnique (capabilityRequires current) fact}
    CapabilityInput typeName ->
      current {capabilityInput = appendUnique (capabilityInput current) typeName}
    CapabilityOutput typeName ->
      current {capabilityOutput = appendUnique (capabilityOutput current) typeName}
    CapabilityUses currentUse ->
      current {capabilityUses = appendUnique (capabilityUses current) currentUse}
    CapabilityError currentUse ->
      current {capabilityErrors = appendUnique (capabilityErrors current) currentUse}
    CapabilityProduces fact ->
      current {capabilityProduces = appendUnique (capabilityProduces current) fact}
    CapabilityPolicyClause currentPolicy ->
      current {capabilityPolicy = appendUnique (capabilityPolicy current) currentPolicy}
    CapabilityPipeline currentPipeline ->
      current {capabilityPipelines = appendUnique (capabilityPipelines current) currentPipeline}
    CapabilityHandler binding ->
      current {capabilityHandlers = appendUnique (capabilityHandlers current) binding}
    CapabilityTransform binding ->
      current {capabilityTransforms = appendUnique (capabilityTransforms current) binding}

requires :: WorkflowFact -> CapabilityClause
requires =
  CapabilityRequires

input :: TypeName -> CapabilityClause
input =
  CapabilityInput

output :: TypeName -> CapabilityClause
output =
  CapabilityOutput

uses :: SendName -> TypeName -> TypeName -> CapabilityClause
uses send inputType outputType =
  CapabilityUses (CapabilityUse send inputType outputType)

onError :: SendName -> TypeName -> TypeName -> CapabilityClause
onError send inputType outputType =
  CapabilityError (CapabilityUse send inputType outputType)

produces :: WorkflowFact -> CapabilityClause
produces =
  CapabilityProduces

policy :: CapabilityPolicy -> CapabilityClause
policy =
  CapabilityPolicyClause

retryOnce :: SendName -> CapabilityPolicy
retryOnce =
  CapabilityRetryOnce

idempotentPolicy :: SendName -> CapabilityPolicy
idempotentPolicy =
  CapabilityIdempotent

pipeline :: String -> [TypeName] -> CapabilityClause
pipeline name types =
  CapabilityPipeline (Pipeline name types)

handler :: HandlerBindingSpec -> CapabilityClause
handler =
  CapabilityHandler

handlerBinding :: HandlerName -> String -> [TypeName] -> [TypeName] -> [WorkflowFact] -> HandlerBindingSpec
handlerBinding name implements consumes emits claims =
  HandlerBindingSpec
    { handlerBindingSpecName = name
    , handlerBindingSpecImplements = implements
    , handlerBindingSpecConsumes = consumes
    , handlerBindingSpecEmits = emits
    , handlerBindingSpecClaims = claims
    }

transformBinding :: TransformName -> TypeName -> TypeName -> TransformBindingSpec
transformBinding name inputType outputType =
  TransformBindingSpec
    { transformBindingSpecName = name
    , transformBindingSpecInput = inputType
    , transformBindingSpecOutput = outputType
    }

transform :: TransformBindingSpec -> CapabilityClause
transform =
  CapabilityTransform

capabilitiesEffect :: EffectName -> [Capability] -> EffectUnit
capabilitiesEffect name capabilities =
  Effect.effect name (concatMap capabilityEffectSections capabilities)

capabilityEffectSections :: Capability -> [EffectSection]
capabilityEffectSections current =
  producerSections current
    ++ useBoundarySections current
    ++ errorBoundarySections current
    ++ policySections current

producerSections :: Capability -> [EffectSection]
producerSections current =
  [ FactClaimSection
      ( FactProducer
          currentFact
          (capabilityProducerSteps current)
      )
  | currentFact <- capabilityProduces current
  ]

capabilityProducerSteps :: Capability -> [ProducerStep]
capabilityProducerSteps current =
  map Effect.needs (capabilityRequires current)
    ++ map Effect.take (capabilityInput current)
    ++ map transformStep (activeTransformBindings current)
    ++ map (Effect.uses . capabilityUseSend) (capabilityUses current)
    ++ map (Error . capabilityUseSend) (capabilityErrors current)
    ++ map Effect.make (capabilityOutput current)

transformStep :: TransformBindingSpec -> ProducerStep
transformStep binding =
  Effect.transform
    (transformBindingSpecInput binding)
    (transformBindingSpecOutput binding)
    (transformBindingSpecName binding)

useBoundarySections :: Capability -> [EffectSection]
useBoundarySections current =
  [ Effect.externalMake
      (capabilityUseSend currentUse)
      (capabilityUseInput currentUse)
      (capabilityUseOutput currentUse)
  | currentUse <- capabilityUses current
  ]

errorBoundarySections :: Capability -> [EffectSection]
errorBoundarySections current =
  [ Effect.externalMake
      (capabilityUseSend currentUse)
      (capabilityUseInput currentUse)
      (capabilityUseOutput currentUse)
  | currentUse <- capabilityErrors current
  ]

policySections :: Capability -> [EffectSection]
policySections current =
  map policySection (capabilityPolicy current)

policySection :: CapabilityPolicy -> EffectSection
policySection currentPolicy =
  case currentPolicy of
    CapabilityRetryOnce send ->
      Effect.retry send
    CapabilityIdempotent send ->
      Effect.idempotent send

activeTransformBindings :: Capability -> [TransformBindingSpec]
activeTransformBindings current =
  [ binding
  | binding <- capabilityTransforms current
  , transformBindingInPipeline current binding
  ]

pipelineTransformCandidates :: Capability -> [(TypeName, TypeName)]
pipelineTransformCandidates current =
  unique
    [ (left, right)
    | currentPipeline <- capabilityPipelines current
    , (left, right) <- adjacentPairs (pipelineTypes currentPipeline)
    ]

checkBusinessShape :: [Capability] -> [BusinessShapeIssue]
checkBusinessShape capabilities =
  concatMap checkCapability capabilities
    ++ concatMap (checkHandlers capabilities) capabilities
    ++ concatMap checkTransforms capabilities
    ++ checkFactArtifactInternalShape capabilities

businessShapePassed :: [Capability] -> Bool
businessShapePassed =
  null . checkBusinessShape

checkCapability :: Capability -> [BusinessShapeIssue]
checkCapability current
  | null (capabilityProduces current)
      && null (capabilityUses current)
      && null (capabilityErrors current) =
      [CapabilityHasNoProducer (capabilityName current)]
  | otherwise =
      []

checkHandlers :: [Capability] -> Capability -> [BusinessShapeIssue]
checkHandlers capabilities current =
  concatMap checkHandler (capabilityHandlers current)
  where
    checkHandler binding =
      case capabilityByName capabilities (handlerBindingSpecImplements binding) of
        Nothing ->
          [HandlerImplementsUnknownCapability (handlerBindingSpecName binding) (handlerBindingSpecImplements binding)]
        Just target ->
          handlerConsumeIssues target binding
            ++ handlerEmitIssues target binding
            ++ handlerClaimIssues target binding

handlerConsumeIssues :: Capability -> HandlerBindingSpec -> [BusinessShapeIssue]
handlerConsumeIssues target binding
  | expectedHandlerConsumes target == handlerBindingSpecConsumes binding =
      []
  | otherwise =
      [ HandlerConsumesMismatch
          (handlerBindingSpecName binding)
          (capabilityName target)
          (expectedHandlerConsumes target)
          (handlerBindingSpecConsumes binding)
      ]

handlerEmitIssues :: Capability -> HandlerBindingSpec -> [BusinessShapeIssue]
handlerEmitIssues target binding
  | expectedHandlerEmits target == handlerBindingSpecEmits binding =
      []
  | otherwise =
      [ HandlerEmitsMismatch
          (handlerBindingSpecName binding)
          (capabilityName target)
          (expectedHandlerEmits target)
          (handlerBindingSpecEmits binding)
      ]

handlerClaimIssues :: Capability -> HandlerBindingSpec -> [BusinessShapeIssue]
handlerClaimIssues target binding
  | all (`elem` capabilityProduces target) (handlerBindingSpecClaims binding) =
      []
  | otherwise =
      [ HandlerClaimsMismatch
          (handlerBindingSpecName binding)
          (capabilityName target)
          (capabilityProduces target)
          (handlerBindingSpecClaims binding)
      ]

expectedHandlerConsumes :: Capability -> [TypeName]
expectedHandlerConsumes current =
  [ capabilityUseInput currentUse
  | currentUse <- capabilityUses current
  , capabilityUseInput currentUse /= NoInput
  ]

expectedHandlerEmits :: Capability -> [TypeName]
expectedHandlerEmits current =
  [ capabilityUseOutput currentUse
  | currentUse <- capabilityUses current
  , capabilityUseOutput currentUse /= Unit
  ]

checkTransforms :: Capability -> [BusinessShapeIssue]
checkTransforms current =
  [ TransformBindingOutsidePipeline
      (transformBindingSpecName binding)
      (transformBindingSpecInput binding)
      (transformBindingSpecOutput binding)
  | binding <- capabilityTransforms current
  , not (transformBindingInPipeline current binding)
  ]

checkFactArtifactInternalShape :: [Capability] -> [BusinessShapeIssue]
checkFactArtifactInternalShape capabilities =
  [ FactNameMissingSuffix currentFact
  | currentFact <- facts
  , not ("Fact" `endsWith` show currentFact)
  ]
    ++ [ ArtifactNameLooksLikeFact currentArtifact
       | currentArtifact <- artifacts
       , "Fact" `endsWith` show currentArtifact
       ]
    ++ [ FactArtifactNameCollision currentFact currentArtifact
       | currentFact <- facts
       , currentArtifact <- artifacts
       , factArtifactNameCollides currentFact currentArtifact
       ]
  where
    facts =
      unique (concatMap capabilityFacts capabilities)
    artifacts =
      unique (filter isBusinessArtifact (concatMap capabilityArtifacts capabilities))

capabilityFacts :: Capability -> [WorkflowFact]
capabilityFacts current =
  capabilityRequires current
    ++ capabilityProduces current
    ++ concatMap handlerBindingSpecClaims (capabilityHandlers current)

capabilityArtifacts :: Capability -> [TypeName]
capabilityArtifacts current =
  capabilityInput current
    ++ capabilityOutput current
    ++ concatMap capabilityUseArtifacts (capabilityUses current)
    ++ concatMap capabilityUseArtifacts (capabilityErrors current)
    ++ concatMap pipelineTypes (capabilityPipelines current)
    ++ concatMap transformBindingArtifacts (capabilityTransforms current)
    ++ concatMap handlerBindingArtifacts (capabilityHandlers current)

capabilityUseArtifacts :: CapabilityUse -> [TypeName]
capabilityUseArtifacts currentUse =
  [capabilityUseInput currentUse, capabilityUseOutput currentUse]

transformBindingArtifacts :: TransformBindingSpec -> [TypeName]
transformBindingArtifacts binding =
  [transformBindingSpecInput binding, transformBindingSpecOutput binding]

handlerBindingArtifacts :: HandlerBindingSpec -> [TypeName]
handlerBindingArtifacts binding =
  handlerBindingSpecConsumes binding ++ handlerBindingSpecEmits binding

isBusinessArtifact :: TypeName -> Bool
isBusinessArtifact typeName =
  typeName /= NoInput
    && typeName /= Unit
    && typeName /= ErrorInput

factArtifactNameCollides :: WorkflowFact -> TypeName -> Bool
factArtifactNameCollides currentFact currentArtifact =
  factText == artifactText
    || dropFactSuffix factText == artifactText
  where
    factText =
      show currentFact
    artifactText =
      show currentArtifact

dropFactSuffix :: String -> String
dropFactSuffix text
  | "Fact" `endsWith` text =
      take (length text - length ("Fact" :: String)) text
  | otherwise =
      text

endsWith :: String -> String -> Bool
endsWith suffix text =
  length suffix <= length text
    && drop (length text - length suffix) text == suffix

transformBindingInPipeline :: Capability -> TransformBindingSpec -> Bool
transformBindingInPipeline current binding =
  (transformBindingSpecInput binding, transformBindingSpecOutput binding)
    `elem` pipelineTransformCandidates current

capabilityByName :: [Capability] -> String -> Maybe Capability
capabilityByName [] _ =
  Nothing
capabilityByName (current : rest) name
  | capabilityName current == name =
      Just current
  | otherwise =
      capabilityByName rest name

renderBusinessShapeIssue :: BusinessShapeIssue -> String
renderBusinessShapeIssue issue =
  case issue of
    CapabilityHasNoProducer name ->
      "capability has no producer or external boundary: " ++ name
    HandlerImplementsUnknownCapability handlerName name ->
      "handler " ++ show handlerName ++ " implements unknown capability " ++ name
    HandlerConsumesMismatch handlerName name expected actual ->
      "handler " ++ show handlerName ++ " consumes mismatch for " ++ name ++ ": expected " ++ show expected ++ ", actual " ++ show actual
    HandlerEmitsMismatch handlerName name expected actual ->
      "handler " ++ show handlerName ++ " emits mismatch for " ++ name ++ ": expected " ++ show expected ++ ", actual " ++ show actual
    HandlerClaimsMismatch handlerName name expected actual ->
      "handler " ++ show handlerName ++ " claims mismatch for " ++ name ++ ": expected subset " ++ show expected ++ ", actual " ++ show actual
    TransformBindingOutsidePipeline transformName inputType outputType ->
      "transform " ++ show transformName ++ " is not an adjacent pipeline edge: " ++ show inputType ++ " -> " ++ show outputType
    FactNameMissingSuffix currentFact ->
      "fact name should end with Fact: " ++ show currentFact
    ArtifactNameLooksLikeFact typeName ->
      "artifact type should not look like a business fact: " ++ show typeName
    FactArtifactNameCollision currentFact typeName ->
      "fact and artifact names collide; keep business state and runtime data separate: " ++ show currentFact ++ " / " ++ show typeName

adjacentPairs :: [item] -> [(item, item)]
adjacentPairs [] =
  []
adjacentPairs [_] =
  []
adjacentPairs (left : right : rest) =
  (left, right) : adjacentPairs (right : rest)

appendUnique :: Eq item => [item] -> item -> [item]
appendUnique items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

unique :: Eq item => [item] -> [item]
unique =
  foldl appendUnique []
