{-# LANGUAGE FlexibleInstances #-}

module Effects.EffectTheory
  ( EffectProfile (..)
  , EffectSection (..)
  , EffectTheory (..)
  , EffectUnit (..)
  , FactClaim (fact)
  , FactProducer (..)
  , ImplementationBinding (..)
  , ProducerStep (..)
  , SendBoundary (..)
  , SendSignature (..)
  , effect
  , externalMake
  , externalTake
  , implement
  , needs
  , onFailure
  , profile
  , theory
  , uses
  , module AST.Facts
  , module Effects.Names
  ) where

import AST.Facts
  ( WorkflowFact (..)
  )
import Effects.Names

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
  | ProfileSection EffectProfile

data SendBoundary = SendBoundary
  { sendBoundaryName :: SendName
  , sendBoundarySignature :: SendSignature
  }

data SendSignature = SendSignature
  { sendInput :: TypeName
  , sendOutput :: TypeName
  }

data FactProducer = FactProducer
  { producerFact :: WorkflowFact
  , producerSteps :: [ProducerStep]
  }

data ProducerStep
  = Needs WorkflowFact
  | Uses SendName
  | External
  | OnFailure WorkflowFact

data EffectProfile = EffectProfile
  { profileName :: ProfileName
  , profileImplementations :: [ImplementationBinding]
  }

data ImplementationBinding = ImplementationBinding
  { implementedSend :: SendName
  , implementationName :: ImplementationName
  }

theory :: [EffectUnit] -> EffectTheory
theory =
  EffectTheory

effect :: EffectName -> [EffectSection] -> EffectUnit
effect =
  EffectUnit

externalMake :: SendName -> TypeName -> TypeName -> EffectSection
externalMake name input output =
  SendSection (SendBoundary name (SendSignature input output))

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

externalTake :: WorkflowFact -> EffectSection
externalTake currentFact =
  FactClaimSection (FactProducer currentFact [External])

onFailure :: WorkflowFact -> ProducerStep
onFailure =
  OnFailure

profile :: ProfileName -> [ImplementationBinding] -> EffectSection
profile name implementations =
  ProfileSection (EffectProfile name implementations)

implement :: SendName -> ImplementationName -> ImplementationBinding
implement =
  ImplementationBinding
