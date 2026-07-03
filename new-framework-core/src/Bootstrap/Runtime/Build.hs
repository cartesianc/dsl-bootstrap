{-# LANGUAGE PatternSynonyms #-}

module Bootstrap.Runtime.Build
  ( buildNativeApp
  , isPipeType
  , nativePlanPassed
  , renderNativePlanErrors
  , ruleFor
  , sendContractFor
  , sourceFactsForType
  ) where

import qualified Bootstrap.Effects as BootstrapEffects
import qualified Bootstrap.Effect as Effect
import Bootstrap.Effect
  ( EffectSection (..)
  , EffectTheory (..)
  , ExternalTakeBoundary (..)
  , FactProducer (..)
  , IdempotencyPolicy (..)
  , ProducerStep (..)
  , RetryPolicy (..)
  , SendBoundary (..)
  , SendName
  , SendPolicy (..)
  , SendSignature (..)
  , TypeName
  , pattern ErrorInput
  , pattern NoInput
  , pattern Unit
  )
import Bootstrap.Runtime.Types
import Bootstrap.Workflow
  ( AppBlueprint (..)
  , EffectSystemName
  , FactExpr (..)
  , Workflow (..)
  , WorkflowFact
  , chainItems
  , choiceItems
  , fallbackItems
  , parallelItems
  , raceItems
  , requirementItems
  )
import qualified Bootstrap.Workflow as Workflow

buildNativeApp :: AppBlueprint -> EffectTheory -> Either String NativeAppPlan
buildNativeApp blueprint effects =
  let systems =
        collectWorkflowSystems (blueprintApp blueprint)
      rootFacts =
        collectWorkflowFacts (blueprintApp blueprint)
      factRules =
        nativeFactRules effects
      sendContracts =
        nativeSendContracts effects
      constraints =
        nativeConstraints rootFacts factRules sendContracts systems
   in Right
        NativeAppPlan
          { nativeAppPlanFacts = map nativeRuleFact factRules
          , nativeAppPlanRootFacts = rootFacts
          , nativeAppPlanSendBoundaries = map sendContractName sendContracts
          , nativeAppPlanSendContracts = sendContracts
          , nativeAppPlanFactRules = factRules
          , nativeAppPlanConstraints = constraints
          }

nativePlanPassed :: NativeAppPlan -> Bool
nativePlanPassed =
  all nativeConstraintPassed . nativeAppPlanConstraints

renderNativePlanErrors :: NativeAppPlan -> String
renderNativePlanErrors plan =
  joinLines
    [ nativeConstraintMessage constraint
    | constraint <- nativeAppPlanConstraints plan
    , not (nativeConstraintPassed constraint)
    ]

ruleFor :: NativeAppPlan -> WorkflowFact -> Maybe NativeFactRule
ruleFor plan currentFact =
  firstJust
    [ Just rule
    | rule <- nativeAppPlanFactRules plan
    , nativeRuleFact rule == currentFact
    ]

sendContractFor :: NativeAppPlan -> SendName -> Maybe SendContract
sendContractFor plan currentSend =
  firstJust
    [ Just contract
    | contract <- nativeAppPlanSendContracts plan
    , sendContractName contract == currentSend
    ]

sourceFactsForType :: NativeAppPlan -> TypeName -> [WorkflowFact]
sourceFactsForType plan =
  sourceFactsForTypeFromRules (nativeAppPlanFactRules plan)

nativeFactRules :: EffectTheory -> [NativeFactRule]
nativeFactRules (EffectTheory units) =
  concatMap unitFactRules units

unitFactRules :: Effect.EffectUnit -> [NativeFactRule]
unitFactRules unit =
  concatMap sectionFactRules (Effect.effectUnitSections unit)

sectionFactRules :: EffectSection -> [NativeFactRule]
sectionFactRules (FactClaimSection producer) =
  [factRuleFromProducer producer]
sectionFactRules (ExternalTakeSection boundary) =
  [factRuleFromExternalTake boundary]
sectionFactRules _ =
  []

factRuleFromProducer :: FactProducer -> NativeFactRule
factRuleFromProducer producer =
  NativeFactRule
    { nativeRuleFact = Effect.producerFact producer
    , nativeRuleNeeds =
        [ fact
        | Needs fact <- steps
        ]
    , nativeRuleTakes =
        [ typeName
        | Take typeName <- steps
        ]
    , nativeRuleMakes =
        explicitMakes ++ sendOutputs ++ transformOutputs
    , nativeRuleUses =
        [ send
        | Uses send <- steps
        ]
    , nativeRuleTransforms =
        [ (input, output, name)
        | Transform input output name <- steps
        ]
    , nativeRuleErrors =
        [ send
        | Error send <- steps
        ]
    , nativeRuleExternal = False
    }
  where
    steps =
      Effect.producerSteps producer
    explicitMakes =
      [ typeName
      | Make typeName <- steps
      , isPipeType typeName
      ]
    sendOutputs =
      [ sendOutput signature
      | Uses send <- steps
      , Just signature <- [sendSignatureByName send BootstrapEffects.coreBootstrapEffects]
      , isPipeType (sendOutput signature)
      ]
    transformOutputs =
      [ output
      | Transform _ output _ <- steps
      , isPipeType output
      ]

factRuleFromExternalTake :: ExternalTakeBoundary -> NativeFactRule
factRuleFromExternalTake boundary =
  NativeFactRule
    { nativeRuleFact = externalTakeFact boundary
    , nativeRuleNeeds = []
    , nativeRuleTakes = []
    , nativeRuleMakes =
        [ output
        | Just output <- [externalTakeOutput boundary]
        , isPipeType output
        ]
    , nativeRuleUses = []
    , nativeRuleTransforms = []
    , nativeRuleErrors = []
    , nativeRuleExternal = True
    }

nativeSendContracts :: EffectTheory -> [SendContract]
nativeSendContracts effects =
  [ SendContract
      { sendContractName = sendBoundaryName boundary
      , sendContractSignature = sendBoundarySignature boundary
      , sendContractIdempotency = sendPolicyIdempotencyFor (sendBoundaryName boundary) policies
      , sendContractRetry = sendPolicyRetryFor (sendBoundaryName boundary) policies
      }
  | boundary <- sendBoundaries effects
  ]
  where
    policies =
      sendPolicies effects

sendBoundaries :: EffectTheory -> [SendBoundary]
sendBoundaries (EffectTheory units) =
  [ boundary
  | unit <- units
  , section <- Effect.effectUnitSections unit
  , SendSection boundary <- [section]
  ]

sendPolicies :: EffectTheory -> [SendPolicy]
sendPolicies (EffectTheory units) =
  [ policy
  | unit <- units
  , section <- Effect.effectUnitSections unit
  , SendPolicySection policy <- [section]
  ]

sendSignatureByName :: SendName -> EffectTheory -> Maybe SendSignature
sendSignatureByName currentSend effects =
  firstJust
    [ Just (sendBoundarySignature boundary)
    | boundary <- sendBoundaries effects
    , sendBoundaryName boundary == currentSend
    ]

sendPolicyIdempotencyFor :: SendName -> [SendPolicy] -> IdempotencyPolicy
sendPolicyIdempotencyFor currentSend policies =
  maybe
    NonIdempotent
    id
    ( firstJust
        [ sendPolicyIdempotency policy
        | policy <- policies
        , sendPolicyName policy == currentSend
        ]
    )

sendPolicyRetryFor :: SendName -> [SendPolicy] -> RetryPolicy
sendPolicyRetryFor currentSend policies =
  maybe
    NoRetry
    id
    ( firstJust
        [ sendPolicyRetry policy
        | policy <- policies
        , sendPolicyName policy == currentSend
        ]
    )

nativeConstraints :: [WorkflowFact] -> [NativeFactRule] -> [SendContract] -> [Workflow.EffectSystem WorkflowFact] -> [NativeConstraint]
nativeConstraints rootFacts rules contracts systems =
  concat
    [ map (factDeclaredConstraint rules) rootFacts
    , map (ruleNeedsDeclaredConstraint rules) rules
    , map (ruleSendsDeclaredConstraint contracts) rules
    , duplicatePipeMakerConstraints rules
    , map (ruleTakesHaveMakerConstraint rules) rules
    , effectSystemScopeConstraints systems
    ]

factDeclaredConstraint :: [NativeFactRule] -> WorkflowFact -> NativeConstraint
factDeclaredConstraint rules currentFact =
  NativeConstraint
    ("root fact declared " ++ show currentFact)
    (any ((== currentFact) . nativeRuleFact) rules)
    ("root fact has no effect rule: " ++ show currentFact)

ruleNeedsDeclaredConstraint :: [NativeFactRule] -> NativeFactRule -> NativeConstraint
ruleNeedsDeclaredConstraint rules rule =
  NativeConstraint
    ("needs declared " ++ show (nativeRuleFact rule))
    (all (`elem` ruleFacts) (nativeRuleNeeds rule))
    ("missing needed fact for " ++ show (nativeRuleFact rule))
  where
    ruleFacts =
      map nativeRuleFact rules

ruleSendsDeclaredConstraint :: [SendContract] -> NativeFactRule -> NativeConstraint
ruleSendsDeclaredConstraint contracts rule =
  NativeConstraint
    ("sends declared " ++ show (nativeRuleFact rule))
    (all (`elem` declaredSends) (nativeRuleUses rule))
    ("missing send boundary for " ++ show (nativeRuleFact rule))
  where
    declaredSends =
      map sendContractName contracts

duplicatePipeMakerConstraints :: [NativeFactRule] -> [NativeConstraint]
duplicatePipeMakerConstraints rules =
  [ NativeConstraint
      ("single pipe maker " ++ show currentType)
      (length makers == 1)
      ("duplicate pipe makers for " ++ show currentType ++ ": " ++ show makers)
  | currentType <- unique (concatMap nativeRuleMakes rules)
  , let makers = sourceFactsForTypeFromRules rules currentType
  , isPipeType currentType
  ]

ruleTakesHaveMakerConstraint :: [NativeFactRule] -> NativeFactRule -> NativeConstraint
ruleTakesHaveMakerConstraint rules rule =
  NativeConstraint
    ("takes have makers " ++ show (nativeRuleFact rule))
    (all hasSingleMaker (filter isPipeType (nativeRuleTakes rule)))
    ("missing or duplicate pipe maker for " ++ show (nativeRuleFact rule))
  where
    hasSingleMaker currentType =
      length (sourceFactsForTypeFromRules rules currentType) == 1

effectSystemScopeConstraints :: [Workflow.EffectSystem WorkflowFact] -> [NativeConstraint]
effectSystemScopeConstraints systems =
  concat
    [ map systemBoundaryNameConstraint systems
    , concatMap (systemImportExportConstraints systems) systems
    , concatMap (systemPrivateScopeConstraints systems) systems
    ]

systemBoundaryNameConstraint :: Workflow.EffectSystem WorkflowFact -> NativeConstraint
systemBoundaryNameConstraint system =
  NativeConstraint
    ("effect system boundary name " ++ show (Workflow.effectSystemName system))
    (Workflow.effectSystemBoundaryName boundary == Workflow.effectSystemName system)
    ("effect system boundary name mismatch: " ++ show (Workflow.effectSystemName system) ++ " / " ++ show (Workflow.effectSystemBoundaryName boundary))
  where
    boundary =
      Workflow.effectSystemBoundary system

systemImportExportConstraints :: [Workflow.EffectSystem WorkflowFact] -> Workflow.EffectSystem WorkflowFact -> [NativeConstraint]
systemImportExportConstraints systems system =
  [ NativeConstraint
      ("effect system import exported " ++ show systemName ++ " " ++ show currentFact)
      (currentFact `elem` exportedFacts systems)
      ("effect system import has no exporter: " ++ show systemName ++ " imports " ++ show currentFact)
  | currentFact <- Workflow.effectSystemBoundaryImports boundary
  ]
    ++
  [ NativeConstraint
      ("effect system import public " ++ show systemName ++ " " ++ show currentFact)
      (not (factPrivateInOtherSystem systems systemName currentFact))
      ("effect system import references private fact: " ++ show systemName ++ " imports " ++ show currentFact)
  | currentFact <- Workflow.effectSystemBoundaryImports boundary
  ]
  where
    boundary =
      Workflow.effectSystemBoundary system
    systemName =
      Workflow.effectSystemName system

systemPrivateScopeConstraints :: [Workflow.EffectSystem WorkflowFact] -> Workflow.EffectSystem WorkflowFact -> [NativeConstraint]
systemPrivateScopeConstraints systems system =
  concatMap privateFactConstraints (Workflow.effectSystemBoundaryPrivateFacts boundary)
  where
    boundary =
      Workflow.effectSystemBoundary system
    systemName =
      Workflow.effectSystemName system
    privateFactConstraints currentFact =
      [ NativeConstraint
          ("effect system private not exported " ++ show systemName ++ " " ++ show currentFact)
          (not (currentFact `elem` exportedFacts systems))
          ("effect system private fact exported: " ++ show systemName ++ " " ++ show currentFact)
      , NativeConstraint
          ("effect system private not imported " ++ show systemName ++ " " ++ show currentFact)
          (not (currentFact `elem` importedFacts systems))
          ("effect system private fact imported: " ++ show systemName ++ " " ++ show currentFact)
      , NativeConstraint
          ("effect system private owner unique " ++ show systemName ++ " " ++ show currentFact)
          (privateFactOwnerCount systems currentFact == 1)
          ("effect system private fact has multiple owners: " ++ show currentFact)
      ]

exportedFacts :: [Workflow.EffectSystem WorkflowFact] -> [WorkflowFact]
exportedFacts systems =
  unique
    [ currentFact
    | system <- systems
    , currentFact <- Workflow.effectSystemBoundaryExports (Workflow.effectSystemBoundary system)
    ]

importedFacts :: [Workflow.EffectSystem WorkflowFact] -> [WorkflowFact]
importedFacts systems =
  unique
    [ currentFact
    | system <- systems
    , currentFact <- Workflow.effectSystemBoundaryImports (Workflow.effectSystemBoundary system)
    ]

factPrivateInOtherSystem :: [Workflow.EffectSystem WorkflowFact] -> EffectSystemName -> WorkflowFact -> Bool
factPrivateInOtherSystem systems systemName currentFact =
  any
    ( \(owner, privateFact) ->
        owner /= systemName && privateFact == currentFact
    )
    (privateFactOwners systems)

privateFactOwnerCount :: [Workflow.EffectSystem WorkflowFact] -> WorkflowFact -> Int
privateFactOwnerCount systems currentFact =
  length
    [ ()
    | (_, privateFact) <- privateFactOwners systems
    , privateFact == currentFact
    ]

privateFactOwners :: [Workflow.EffectSystem WorkflowFact] -> [(EffectSystemName, WorkflowFact)]
privateFactOwners systems =
  [ (Workflow.effectSystemName system, currentFact)
  | system <- systems
  , currentFact <- Workflow.effectSystemBoundaryPrivateFacts (Workflow.effectSystemBoundary system)
  ]

sourceFactsForTypeFromRules :: [NativeFactRule] -> TypeName -> [WorkflowFact]
sourceFactsForTypeFromRules rules currentType =
  [ nativeRuleFact rule
  | rule <- rules
  , currentType `elem` nativeRuleMakes rule
  ]

collectWorkflowFacts :: Workflow.Workflow WorkflowFact hook -> [WorkflowFact]
collectWorkflowFacts workflow =
  case workflow of
    RunWorkflow system ->
      collectFactExpr (Workflow.effectSystemRuntimeFacts system)
    ChainWorkflow steps ->
      unique (concatMap collectWorkflowFacts (chainItems steps))
    ParallelWorkflow branches ->
      unique (concatMap collectWorkflowFacts (parallelItems branches))
    FallbackWorkflow branches ->
      unique (concatMap collectWorkflowFacts (fallbackItems branches))
    RaceWorkflow branches ->
      unique (concatMap collectWorkflowFacts (raceItems branches))
    ChoiceWorkflow _ branches ->
      unique (concatMap (collectWorkflowFacts . snd) (choiceItems branches))
    WaitWorkflow wait body ->
      unique (collectFactExpr (Workflow.waitFacts wait) ++ collectWorkflowFacts body)

collectWorkflowSystems :: Workflow.Workflow WorkflowFact hook -> [Workflow.EffectSystem WorkflowFact]
collectWorkflowSystems workflow =
  case workflow of
    RunWorkflow system ->
      [system]
    ChainWorkflow steps ->
      concatMap collectWorkflowSystems (chainItems steps)
    ParallelWorkflow branches ->
      concatMap collectWorkflowSystems (parallelItems branches)
    FallbackWorkflow branches ->
      concatMap collectWorkflowSystems (fallbackItems branches)
    RaceWorkflow branches ->
      concatMap collectWorkflowSystems (raceItems branches)
    ChoiceWorkflow _ branches ->
      concatMap (collectWorkflowSystems . snd) (choiceItems branches)
    WaitWorkflow _ body ->
      collectWorkflowSystems body

collectFactExpr :: FactExpr WorkflowFact -> [WorkflowFact]
collectFactExpr expression =
  case expression of
    FactItems requirements ->
      requirementItems requirements
    FactAll expressions ->
      unique (concatMap collectFactExpr expressions)
    FactAny expressions ->
      unique (concatMap collectFactExpr expressions)

isPipeType :: TypeName -> Bool
isPipeType NoInput =
  False
isPipeType Unit =
  False
isPipeType ErrorInput =
  False
isPipeType _ =
  True

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest

unique :: Eq item => [item] -> [item]
unique =
  foldl appendUnique []

appendUnique :: Eq item => [item] -> item -> [item]
appendUnique items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

joinLines :: [String] -> String
joinLines [] =
  ""
joinLines [line] =
  line
joinLines (line : rest) =
  line ++ "\n" ++ joinLines rest
