{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Effect
  ( EffectName (..)
  , EffectExpr (..)
  , EffectPayload (..)
  , EffectSection (..)
  , EffectSystemClause (..)
  , EffectSystemHandler (..)
  , EffectSystemPipeline (..)
  , EffectTheory (..)
  , EffectUnit (..)
  , ExternalTakeBoundary (..)
  , ExternalTakeClaim (externalTake)
  , FactClaim (fact)
  , FactProducer (..)
  , HandlerName (..)
  , IdempotencyPolicy (..)
  , ProducerStep (..)
  , RetryPolicy (..)
  , SendBoundary (..)
  , SendName (..)
  , SendPolicy (..)
  , SendSignature (..)
  , TransformName (..)
  , TypeName (..)
  , WorkflowFact (..)
  , effect
  , effectExprAppend
  , effectExprArtifactFlow
  , effectExprBoundary
  , effectExprEmpty
  , effectExprExport
  , effectExprHandle
  , effectExprHide
  , effectExprPayload
  , effectExprPrimitive
  , effectExprRequire
  , effectExprRow
  , effectExprThen
  , effectExprUnit
  , effectPayloadClauses
  , error
  , effectSystem
  , effectUnitBoundary
  , effectUnitProducedFacts
  , effectUnitSystem
  , exports
  , externalMake
  , handler
  , idempotent
  , imports
  , make
  , needs
  , onFailure
  , pattern ErrorInput
  , pattern NoInput
  , pattern Unit
  , pipeline
  , privateFacts
  , retry
  , take
  , theory
  , transform
  , uses
  ) where

import Prelude hiding
  ( error
  , take
  )

import Bootstrap.Workflow
  ( WorkflowFact (..)
  )
import qualified Bootstrap.Workflow as Workflow

newtype EffectName = EffectName
  { effectNameText :: String
  }
  deriving (Eq)

instance Show EffectName where
  show =
    effectNameText

newtype SendName = SendName
  { sendNameText :: String
  }
  deriving (Eq)

instance Show SendName where
  show =
    sendNameText

newtype HandlerName = HandlerName
  { handlerNameText :: String
  }
  deriving (Eq)

instance Show HandlerName where
  show =
    handlerNameText

newtype TransformName = TransformName
  { transformNameText :: String
  }
  deriving (Eq)

instance Show TransformName where
  show =
    transformNameText

newtype TypeName = TypeName
  { typeNameText :: String
  }
  deriving (Eq)

instance Show TypeName where
  show =
    typeNameText

pattern NoInput :: TypeName
pattern NoInput = TypeName "NoInput"

pattern ErrorInput :: TypeName
pattern ErrorInput = TypeName "ErrorInput"

pattern Unit :: TypeName
pattern Unit = TypeName "Unit"

newtype EffectTheory = EffectTheory
  { theoryUnits :: [EffectUnit]
  }

data EffectUnit = EffectUnit
  { effectUnitName :: EffectName
  , effectUnitImports :: [WorkflowFact]
  , effectUnitPrivateFacts :: [WorkflowFact]
  , effectUnitExports :: [WorkflowFact]
  , effectUnitPipelines :: [EffectSystemPipeline]
  , effectUnitHandlers :: [EffectSystemHandler]
  , effectUnitSections :: [EffectSection]
  }

data EffectSystemClause
  = EffectSystemImports [WorkflowFact]
  | EffectSystemPrivateFacts [WorkflowFact]
  | EffectSystemExports [WorkflowFact]
  | EffectSystemPipelines [EffectSystemPipeline]
  | EffectSystemHandlers [EffectSystemHandler]

data EffectSystemPipeline = EffectSystemPipeline
  { effectSystemPipelineName :: String
  , effectSystemPipelineTypes :: [TypeName]
  }
  deriving (Eq, Show)

data EffectSystemHandler = EffectSystemHandler
  { effectSystemHandlerSend :: SendName
  , effectSystemHandlerName :: HandlerName
  }
  deriving (Eq, Show)

data EffectExpr
  = EffectEmpty
  | EffectPrimitive EffectPayload
  | EffectAppend EffectExpr EffectExpr
  | EffectThen EffectExpr EffectExpr
  | EffectHandle SendName HandlerName EffectExpr
  | EffectHide [WorkflowFact] EffectExpr
  | EffectExport [WorkflowFact] EffectExpr
  | EffectRequire [WorkflowFact] EffectExpr
  | EffectArtifactFlow String [TypeName] EffectExpr

data EffectPayload = EffectPayload
  { payloadImports :: [WorkflowFact]
  , payloadPrivateFacts :: [WorkflowFact]
  , payloadExports :: [WorkflowFact]
  , payloadSends :: [Workflow.EffectSystemBoundarySend]
  , payloadTransforms :: [Workflow.EffectSystemBoundaryTransform]
  , payloadPolicies :: [Workflow.EffectSystemBoundaryPolicy]
  , payloadPipelines :: [EffectSystemPipeline]
  , payloadHandlers :: [EffectSystemHandler]
  , payloadSections :: [EffectSection]
  }

data EffectSection
  = FactClaimSection FactProducer
  | SendSection SendBoundary
  | SendPolicySection SendPolicy
  | ExternalTakeSection ExternalTakeBoundary

data SendBoundary = SendBoundary
  { sendBoundaryName :: SendName
  , sendBoundarySignature :: SendSignature
  }

data ExternalTakeBoundary = ExternalTakeBoundary
  { externalTakeFact :: WorkflowFact
  , externalTakeOutput :: Maybe TypeName
  }

data SendPolicy = SendPolicy
  { sendPolicyName :: SendName
  , sendPolicyIdempotency :: Maybe IdempotencyPolicy
  , sendPolicyRetry :: Maybe RetryPolicy
  }

data SendSignature = SendSignature
  { sendInput :: TypeName
  , sendOutput :: TypeName
  }

data IdempotencyPolicy
  = Idempotent
  | NonIdempotent
  deriving (Eq, Show)

data RetryPolicy
  = NoRetry
  | RetryOnce
  deriving (Eq, Show)

data FactProducer = FactProducer
  { producerFact :: WorkflowFact
  , producerSteps :: [ProducerStep]
  }

data ProducerStep
  = Needs WorkflowFact
  | Uses SendName
  | Take TypeName
  | Make TypeName
  | Transform TypeName TypeName TransformName
  | External
  | OnFailure WorkflowFact
  | Error SendName

theory :: [EffectUnit] -> EffectTheory
theory =
  EffectTheory

effect :: EffectName -> [EffectSection] -> EffectUnit
effect name sections =
  EffectUnit
    { effectUnitName = name
    , effectUnitImports = []
    , effectUnitPrivateFacts = []
    , effectUnitExports = effectUnitProducedFactsFromSections sections
    , effectUnitPipelines = []
    , effectUnitHandlers = []
    , effectUnitSections = sections
    }

effectSystem :: EffectName -> [EffectSystemClause] -> [EffectSection] -> EffectUnit
effectSystem name clauses sections =
  EffectUnit
    { effectUnitName = name
    , effectUnitImports = unique (concatMap clauseImports clauses)
    , effectUnitPrivateFacts = unique (concatMap clausePrivateFacts clauses)
    , effectUnitExports = explicitOrProducedExports
    , effectUnitPipelines = unique (concatMap clausePipelines clauses)
    , effectUnitHandlers = unique (concatMap clauseHandlers clauses)
    , effectUnitSections = sections
    }
  where
    explicitExports =
      unique (concatMap clauseExports clauses)
    explicitOrProducedExports =
      if null explicitExports
        then effectUnitProducedFactsFromSections sections
        else explicitExports

imports :: [WorkflowFact] -> EffectSystemClause
imports =
  EffectSystemImports

privateFacts :: [WorkflowFact] -> EffectSystemClause
privateFacts =
  EffectSystemPrivateFacts

exports :: [WorkflowFact] -> EffectSystemClause
exports =
  EffectSystemExports

pipeline :: String -> [TypeName] -> EffectSystemClause
pipeline name types =
  EffectSystemPipelines [EffectSystemPipeline name types]

handler :: SendName -> HandlerName -> EffectSystemClause
handler send name =
  EffectSystemHandlers [EffectSystemHandler send name]

effectUnitBoundary :: EffectUnit -> Workflow.EffectSystemBoundary WorkflowFact
effectUnitBoundary unit =
  Workflow.systemBoundaryWithHandlers
    (Workflow.EffectSystemName (show (effectUnitName unit)))
    (effectUnitImports unit)
    (effectUnitPrivateFacts unit)
    (effectUnitExports unit)
    (effectUnitBoundarySends unit)
    (effectUnitBoundaryTransforms unit)
    (effectUnitBoundaryPolicies unit)
    (map effectSystemPipelineBoundary (effectUnitPipelines unit))
    (map effectSystemHandlerBoundary (effectUnitHandlers unit))

effectUnitSystem :: EffectUnit -> Workflow.EffectSystem WorkflowFact
effectUnitSystem =
  Workflow.effectSystemFromBoundary . effectUnitBoundary

effectUnitProducedFacts :: EffectUnit -> [WorkflowFact]
effectUnitProducedFacts =
  effectUnitProducedFactsFromSections . effectUnitSections

externalMake :: SendName -> TypeName -> TypeName -> EffectSection
externalMake name input output =
  SendSection (SendBoundary name (SendSignature input output))

idempotent :: SendName -> EffectSection
idempotent name =
  SendPolicySection (SendPolicy name (Just Idempotent) Nothing)

retry :: SendName -> EffectSection
retry name =
  SendPolicySection (SendPolicy name Nothing (Just RetryOnce))

class FactClaim result where
  fact :: WorkflowFact -> result

instance FactClaim EffectSection where
  fact currentFact =
    FactClaimSection (FactProducer currentFact [])

instance FactClaim ([ProducerStep] -> EffectSection) where
  fact currentFact steps =
    FactClaimSection (FactProducer currentFact steps)

needs :: WorkflowFact -> ProducerStep
needs =
  Needs

uses :: SendName -> ProducerStep
uses =
  Uses

take :: TypeName -> ProducerStep
take =
  Take

make :: TypeName -> ProducerStep
make =
  Make

transform :: TypeName -> TypeName -> TransformName -> ProducerStep
transform input output name =
  Transform input output name

class ExternalTakeClaim result where
  externalTake :: WorkflowFact -> result

instance ExternalTakeClaim EffectSection where
  externalTake currentFact =
    ExternalTakeSection (ExternalTakeBoundary currentFact Nothing)

instance ExternalTakeClaim (TypeName -> EffectSection) where
  externalTake currentFact output =
    ExternalTakeSection (ExternalTakeBoundary currentFact (Just output))

onFailure :: WorkflowFact -> ProducerStep
onFailure =
  OnFailure

error :: SendName -> ProducerStep
error =
  Error

effectUnitProducedFactsFromSections :: [EffectSection] -> [WorkflowFact]
effectUnitProducedFactsFromSections sections =
  unique
    [ producerFact producer
    | FactClaimSection producer <- sections
    ]

effectUnitBoundarySends :: EffectUnit -> [Workflow.EffectSystemBoundarySend]
effectUnitBoundarySends unit =
  unique
    [ Workflow.boundarySend (show (sendBoundaryName boundary))
    | SendSection boundary <- effectUnitSections unit
    ]

effectUnitBoundaryTransforms :: EffectUnit -> [Workflow.EffectSystemBoundaryTransform]
effectUnitBoundaryTransforms unit =
  unique
    [ Workflow.boundaryTransform (show name)
    | FactClaimSection producer <- effectUnitSections unit
    , Transform _ _ name <- producerSteps producer
    ]

effectUnitBoundaryPolicies :: EffectUnit -> [Workflow.EffectSystemBoundaryPolicy]
effectUnitBoundaryPolicies unit =
  concatMap sectionBoundaryPolicies (effectUnitSections unit)

effectSystemPipelineBoundary :: EffectSystemPipeline -> Workflow.EffectSystemBoundaryPipeline
effectSystemPipelineBoundary currentPipeline =
  Workflow.boundaryPipeline
    (effectSystemPipelineName currentPipeline)
    (map (Workflow.boundaryArtifact . show) (effectSystemPipelineTypes currentPipeline))

effectSystemHandlerBoundary :: EffectSystemHandler -> Workflow.EffectSystemBoundaryHandler
effectSystemHandlerBoundary currentHandler =
  Workflow.boundaryHandler
    (show (effectSystemHandlerSend currentHandler))
    (show (effectSystemHandlerName currentHandler))

effectExprEmpty :: EffectExpr
effectExprEmpty =
  EffectEmpty

effectExprPrimitive :: EffectPayload -> EffectExpr
effectExprPrimitive =
  EffectPrimitive

effectExprAppend :: EffectExpr -> EffectExpr -> EffectExpr
effectExprAppend =
  EffectAppend

effectExprThen :: EffectExpr -> EffectExpr -> EffectExpr
effectExprThen =
  EffectThen

effectExprHandle :: SendName -> HandlerName -> EffectExpr -> EffectExpr
effectExprHandle =
  EffectHandle

effectExprHide :: [WorkflowFact] -> EffectExpr -> EffectExpr
effectExprHide =
  EffectHide

effectExprExport :: [WorkflowFact] -> EffectExpr -> EffectExpr
effectExprExport =
  EffectExport

effectExprRequire :: [WorkflowFact] -> EffectExpr -> EffectExpr
effectExprRequire =
  EffectRequire

effectExprArtifactFlow :: String -> [TypeName] -> EffectExpr -> EffectExpr
effectExprArtifactFlow =
  EffectArtifactFlow

effectExprPayload :: EffectExpr -> EffectPayload
effectExprPayload expr =
  case expr of
    EffectEmpty ->
      emptyEffectPayload
    EffectPrimitive payload ->
      payload
    EffectAppend left right ->
      combineEffectPayload (effectExprPayload left) (effectExprPayload right)
    EffectThen left right ->
      combineEffectPayload (effectExprPayload left) (effectExprPayload right)
    EffectHandle send name inner ->
      combineEffectPayload
        (effectExprPayload inner)
        emptyEffectPayload {payloadHandlers = [EffectSystemHandler send name]}
    EffectHide facts inner ->
      combineEffectPayload
        (effectExprPayload inner)
        emptyEffectPayload {payloadPrivateFacts = facts}
    EffectExport facts inner ->
      combineEffectPayload
        (effectExprPayload inner)
        emptyEffectPayload {payloadExports = facts}
    EffectRequire facts inner ->
      combineEffectPayload
        (effectExprPayload inner)
        emptyEffectPayload {payloadImports = facts}
    EffectArtifactFlow name types inner ->
      combineEffectPayload
        (effectExprPayload inner)
        emptyEffectPayload {payloadPipelines = [EffectSystemPipeline name types]}

effectExprUnit :: EffectName -> EffectExpr -> EffectUnit
effectExprUnit name expr =
  effectSystem
    name
    (effectPayloadClauses payload)
    (payloadSections payload)
  where
    payload =
      effectExprPayload expr

effectExprBoundary :: Workflow.EffectSystemName -> EffectExpr -> Workflow.EffectSystemBoundary WorkflowFact
effectExprBoundary name expr =
  unitBoundary
    { Workflow.effectSystemBoundaryName = name
    , Workflow.effectSystemBoundarySends =
        unionItems (payloadSends payload) (Workflow.effectSystemBoundarySends unitBoundary)
    , Workflow.effectSystemBoundaryTransforms =
        unionItems (payloadTransforms payload) (Workflow.effectSystemBoundaryTransforms unitBoundary)
    , Workflow.effectSystemBoundaryPolicies =
        unionItems (payloadPolicies payload) (Workflow.effectSystemBoundaryPolicies unitBoundary)
    }
  where
    payload =
      effectExprPayload expr
    unitBoundary =
      effectUnitBoundary (effectExprUnit (EffectName (show name)) expr)

effectExprRow :: Workflow.EffectSystemName -> EffectExpr -> Workflow.EffectRow WorkflowFact
effectExprRow name =
  Workflow.effectRowFromBoundary . effectExprBoundary name

effectPayloadClauses :: EffectPayload -> [EffectSystemClause]
effectPayloadClauses payload =
  importsClause ++ privateFactsClause ++ exportsClause ++ pipelineClauses ++ handlerClauses
  where
    importsClause =
      [EffectSystemImports (payloadImports payload) | not (null (payloadImports payload))]
    privateFactsClause =
      [EffectSystemPrivateFacts (payloadPrivateFacts payload) | not (null (payloadPrivateFacts payload))]
    exportsClause =
      [EffectSystemExports (payloadExports payload) | not (null (payloadExports payload))]
    pipelineClauses =
      [EffectSystemPipelines (payloadPipelines payload) | not (null (payloadPipelines payload))]
    handlerClauses =
      [EffectSystemHandlers (payloadHandlers payload) | not (null (payloadHandlers payload))]

emptyEffectPayload :: EffectPayload
emptyEffectPayload =
  EffectPayload
    { payloadImports = []
    , payloadPrivateFacts = []
    , payloadExports = []
    , payloadSends = []
    , payloadTransforms = []
    , payloadPolicies = []
    , payloadPipelines = []
    , payloadHandlers = []
    , payloadSections = []
    }

combineEffectPayload :: EffectPayload -> EffectPayload -> EffectPayload
combineEffectPayload left right =
  EffectPayload
    { payloadImports = unionItems (payloadImports left) (payloadImports right)
    , payloadPrivateFacts = unionItems (payloadPrivateFacts left) (payloadPrivateFacts right)
    , payloadExports = unionItems (payloadExports left) (payloadExports right)
    , payloadSends = unionItems (payloadSends left) (payloadSends right)
    , payloadTransforms = unionItems (payloadTransforms left) (payloadTransforms right)
    , payloadPolicies = unionItems (payloadPolicies left) (payloadPolicies right)
    , payloadPipelines = unionItems (payloadPipelines left) (payloadPipelines right)
    , payloadHandlers = unionItems (payloadHandlers left) (payloadHandlers right)
    , payloadSections = payloadSections left ++ payloadSections right
    }

sectionBoundaryPolicies :: EffectSection -> [Workflow.EffectSystemBoundaryPolicy]
sectionBoundaryPolicies (SendPolicySection policy) =
  idempotencyPolicy ++ retryPolicy
  where
    send =
      show (sendPolicyName policy)
    idempotencyPolicy =
      case sendPolicyIdempotency policy of
        Just Idempotent ->
          [Workflow.boundaryIdempotent send]
        _ ->
          []
    retryPolicy =
      case sendPolicyRetry policy of
        Just RetryOnce ->
          [Workflow.boundaryRetryOnce send]
        _ ->
          []
sectionBoundaryPolicies _ =
  []

clauseImports :: EffectSystemClause -> [WorkflowFact]
clauseImports clause =
  case clause of
    EffectSystemImports facts ->
      facts
    _ ->
      []

clausePrivateFacts :: EffectSystemClause -> [WorkflowFact]
clausePrivateFacts clause =
  case clause of
    EffectSystemPrivateFacts facts ->
      facts
    _ ->
      []

clauseExports :: EffectSystemClause -> [WorkflowFact]
clauseExports clause =
  case clause of
    EffectSystemExports facts ->
      facts
    _ ->
      []

clausePipelines :: EffectSystemClause -> [EffectSystemPipeline]
clausePipelines clause =
  case clause of
    EffectSystemPipelines currentPipelines ->
      currentPipelines
    _ ->
      []

clauseHandlers :: EffectSystemClause -> [EffectSystemHandler]
clauseHandlers clause =
  case clause of
    EffectSystemHandlers handlers ->
      handlers
    _ ->
      []

unique :: Eq item => [item] -> [item]
unique =
  foldl appendUnique []

appendUnique :: Eq item => [item] -> item -> [item]
appendUnique items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

unionItems :: Eq item => [item] -> [item] -> [item]
unionItems left right =
  foldl appendUnique left right
