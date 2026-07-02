{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Effect
  ( EffectName (..)
  , EffectSection (..)
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
  , error
  , externalMake
  , idempotent
  , make
  , needs
  , onFailure
  , pattern ErrorInput
  , pattern NoInput
  , pattern Unit
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
  , effectUnitSections :: [EffectSection]
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
effect =
  EffectUnit

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
