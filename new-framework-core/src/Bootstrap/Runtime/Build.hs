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
    , effectSystemScopeConstraints rules contracts systems
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

effectSystemScopeConstraints :: [NativeFactRule] -> [SendContract] -> [Workflow.EffectSystem WorkflowFact] -> [NativeConstraint]
effectSystemScopeConstraints rules contracts systems =
  concat
    [ map systemBoundaryNameConstraint systems
    , concatMap (systemImportExportConstraints systems) systems
    , concatMap (systemPrivateScopeConstraints systems) systems
    , concatMap (systemRuleClosureConstraints rules) systems
    , concatMap (systemRuleContractConstraints rules contracts) systems
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

systemRuleClosureConstraints :: [NativeFactRule] -> Workflow.EffectSystem WorkflowFact -> [NativeConstraint]
systemRuleClosureConstraints rules system
  | not (Workflow.effectSystemBoundaryExplicit system) =
      []
  | otherwise =
      [ NativeConstraint
          ("effect system rule closure " ++ show systemName ++ " " ++ show currentFact)
          (all (`elem` allowedFacts) dependencyFacts)
          ( "effect system rule dependency escapes boundary: "
              ++ show systemName
              ++ " "
              ++ show currentFact
              ++ " depends on "
              ++ show (filter (`notElem` allowedFacts) dependencyFacts)
          )
      | currentFact <- unique (Workflow.effectSystemBoundaryPrivateFacts boundary ++ Workflow.effectSystemBoundaryExports boundary)
      , Just rule <- [ruleByFact rules currentFact]
      , let dependencyFacts = ruleDependencyFacts rules rule
      ]
  where
    boundary =
      Workflow.effectSystemBoundary system
    systemName =
      Workflow.effectSystemName system
    allowedFacts =
      unique
        ( Workflow.effectSystemBoundaryImports boundary
            ++ Workflow.effectSystemBoundaryPrivateFacts boundary
            ++ Workflow.effectSystemBoundaryExports boundary
        )

ruleByFact :: [NativeFactRule] -> WorkflowFact -> Maybe NativeFactRule
ruleByFact rules currentFact =
  firstJust
    [ Just rule
    | rule <- rules
    , nativeRuleFact rule == currentFact
    ]

ruleDependencyFacts :: [NativeFactRule] -> NativeFactRule -> [WorkflowFact]
ruleDependencyFacts rules rule =
  unique
    ( nativeRuleNeeds rule
        ++ sourceFactsForTakenTypes
        ++ sourceFactsForTransformInputs
    )
  where
    sourceFactsForTakenTypes =
      concatMap
        (sourceFactsForTypeFromRules rules)
        (filter isPipeType (nativeRuleTakes rule))
    sourceFactsForTransformInputs =
      concatMap
        (sourceFactsForTypeFromRules rules)
        [ input
        | (input, _, _) <- nativeRuleTransforms rule
        , isPipeType input
        ]

systemRuleContractConstraints :: [NativeFactRule] -> [SendContract] -> Workflow.EffectSystem WorkflowFact -> [NativeConstraint]
systemRuleContractConstraints rules contracts system
  | not (Workflow.effectSystemBoundaryExplicit system) =
      []
  | otherwise =
      systemPolicyDeclarationConstraints contracts system
        ++ concatMap constraintsForRule systemRules
  where
    boundary =
      Workflow.effectSystemBoundary system
    systemName =
      Workflow.effectSystemName system
    allowedSends =
      map show (Workflow.effectSystemBoundarySends boundary)
    allowedTransforms =
      map show (Workflow.effectSystemBoundaryTransforms boundary)
    declaredIdempotentSends =
      boundaryIdempotentSends (Workflow.effectSystemBoundaryPolicies boundary)
    declaredRetrySends =
      boundaryRetrySends (Workflow.effectSystemBoundaryPolicies boundary)
    systemRules =
      [ rule
      | currentFact <- unique (Workflow.effectSystemBoundaryPrivateFacts boundary ++ Workflow.effectSystemBoundaryExports boundary)
      , Just rule <- [ruleByFact rules currentFact]
      ]
    constraintsForRule rule =
      [ NativeConstraint
          ("effect system send contract " ++ show systemName ++ " " ++ show (nativeRuleFact rule))
          (all (`elem` allowedSends) usedSends)
          ( "effect system rule uses undeclared send: "
              ++ show systemName
              ++ " "
              ++ show (nativeRuleFact rule)
              ++ " uses "
              ++ show (filter (`notElem` allowedSends) usedSends)
          )
      , NativeConstraint
          ("effect system transform contract " ++ show systemName ++ " " ++ show (nativeRuleFact rule))
          (all (`elem` allowedTransforms) usedTransforms)
          ( "effect system rule uses undeclared transform: "
              ++ show systemName
              ++ " "
              ++ show (nativeRuleFact rule)
              ++ " uses "
              ++ show (filter (`notElem` allowedTransforms) usedTransforms)
          )
      , NativeConstraint
          ("effect system idempotency policy contract " ++ show systemName ++ " " ++ show (nativeRuleFact rule))
          (all (`elem` declaredIdempotentSends) actualIdempotentSends)
          ( "effect system rule uses undeclared idempotency policy: "
              ++ show systemName
              ++ " "
              ++ show (nativeRuleFact rule)
              ++ " uses "
              ++ show (filter (`notElem` declaredIdempotentSends) actualIdempotentSends)
          )
      , NativeConstraint
          ("effect system retry policy contract " ++ show systemName ++ " " ++ show (nativeRuleFact rule))
          (all (`elem` declaredRetrySends) actualRetrySends)
          ( "effect system rule uses undeclared retry policy: "
              ++ show systemName
              ++ " "
              ++ show (nativeRuleFact rule)
              ++ " uses "
              ++ show (filter (`notElem` declaredRetrySends) actualRetrySends)
          )
      ]
      where
        usedSends =
          unique (map show (nativeRuleUses rule))
        usedTransforms =
          unique
            [ show transformName
            | (_, _, transformName) <- nativeRuleTransforms rule
            ]
        actualIdempotentSends =
          [ currentSend
          | currentSend <- usedSends
          , Just contract <- [sendContractByName contracts currentSend]
          , sendContractIdempotency contract == Idempotent
          ]
        actualRetrySends =
          [ currentSend
          | currentSend <- usedSends
          , Just contract <- [sendContractByName contracts currentSend]
          , sendContractRetry contract == RetryOnce
          ]

systemPolicyDeclarationConstraints :: [SendContract] -> Workflow.EffectSystem WorkflowFact -> [NativeConstraint]
systemPolicyDeclarationConstraints contracts system =
  concat
    [ map policySendDeclaredConstraint policySends
    , map idempotencyPolicyBackedConstraint declaredIdempotentSends
    , map retryPolicyBackedConstraint declaredRetrySends
    ]
  where
    boundary =
      Workflow.effectSystemBoundary system
    systemName =
      Workflow.effectSystemName system
    allowedSends =
      map show (Workflow.effectSystemBoundarySends boundary)
    declaredIdempotentSends =
      boundaryIdempotentSends (Workflow.effectSystemBoundaryPolicies boundary)
    declaredRetrySends =
      boundaryRetrySends (Workflow.effectSystemBoundaryPolicies boundary)
    policySends =
      unique (declaredIdempotentSends ++ declaredRetrySends)
    policySendDeclaredConstraint currentSend =
      NativeConstraint
        ("effect system policy send declared " ++ show systemName ++ " " ++ currentSend)
        (currentSend `elem` allowedSends)
        ("effect system policy references undeclared send: " ++ show systemName ++ " " ++ currentSend)
    idempotencyPolicyBackedConstraint currentSend =
      NativeConstraint
        ("effect system idempotency policy backed " ++ show systemName ++ " " ++ currentSend)
        ( maybe
            False
            ((== Idempotent) . sendContractIdempotency)
            (sendContractByName contracts currentSend)
        )
        ("effect system idempotency policy is not backed by effect theory: " ++ show systemName ++ " " ++ currentSend)
    retryPolicyBackedConstraint currentSend =
      NativeConstraint
        ("effect system retry policy backed " ++ show systemName ++ " " ++ currentSend)
        ( maybe
            False
            ((== RetryOnce) . sendContractRetry)
            (sendContractByName contracts currentSend)
        )
        ("effect system retry policy is not backed by effect theory: " ++ show systemName ++ " " ++ currentSend)

boundaryIdempotentSends :: [Workflow.EffectSystemBoundaryPolicy] -> [String]
boundaryIdempotentSends policies =
  unique
    [ show currentSend
    | Workflow.EffectSystemBoundaryIdempotent currentSend <- policies
    ]

boundaryRetrySends :: [Workflow.EffectSystemBoundaryPolicy] -> [String]
boundaryRetrySends policies =
  unique
    [ show currentSend
    | Workflow.EffectSystemBoundaryRetryOnce currentSend <- policies
    ]

sendContractByName :: [SendContract] -> String -> Maybe SendContract
sendContractByName contracts currentSend =
  firstJust
    [ Just contract
    | contract <- contracts
    , show (sendContractName contract) == currentSend
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
