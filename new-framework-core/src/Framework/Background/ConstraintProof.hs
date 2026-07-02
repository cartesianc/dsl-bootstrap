module Framework.Background.ConstraintProof
  ( ConstraintError (..)
  , ConstraintFact (..)
  , RuleId (..)
  , SmtBackend (..)
  , SmtEvidence (..)
  , SmtProposition (..)
  , SmtResult (..)
  , SmtSolver (..)
  , SmtStatus (..)
  , WorkflowScope (..)
  , availableSmtSolver
  , checkConstraintFacts
  , constraintsFromAppPlan
  , constraintsFromNativeAppPlan
  , cvc5Solver
  , defaultSmtPropositions
  , proveMinimalCore
  , proveMinimalCoreWith
  , proveMinimalCoreWithAvailableSolver
  , proveMinimalCoreWithSolver
  , renderConstraintError
  , renderConstraintFacts
  , renderSmtEvidence
  , renderSmtResult
  , renderSmtResults
  , renderSmtSolver
  , smtLibForProposition
  , smtPassed
  , z3Solver
  ) where

import Control.Exception
  ( IOException
  , try
  )
import System.Directory
  ( findExecutable )
import System.Exit
  ( ExitCode (..) )
import System.Process
  ( readProcessWithExitCode )

import Bootstrap.Effect
  ( EffectTheory
  , SendName
  , TransformName
  , TypeName
  )
import Bootstrap.Runtime
  ( NativeAppPlan (..)
  , NativeFactRule (..)
  , SendContract (..)
  , buildNativeApp
  )
import Bootstrap.Workflow
  ( AppBlueprint (..)
  , Callback (..)
  , FactExpr (..)
  , Hanging
  , HangingAction (..)
  , Loop (..)
  , Workflow (..)
  , WorkflowFact
  , WorkflowName
  , chainItems
  , choiceItems
  , fallbackItems
  , hangingItems
  , parallelItems
  , raceItems
  , requirementItems
  , waitFacts
  )

newtype RuleId = RuleId WorkflowFact
  deriving (Eq, Show)

data WorkflowScope
  = RootScope
  | NamedScope WorkflowName
  deriving (Eq, Show)

data ConstraintFact
  = RequiresFact WorkflowFact
  | ExternalMakeDeclared SendName
  | Makes RuleId WorkflowFact
  | Takes RuleId WorkflowFact
  | PipeNeeds RuleId TypeName
  | PipeMakes RuleId TypeName
  | UsesExternalMake RuleId SendName
  | UsesTransform RuleId TransformName TypeName TypeName
  | HandlesError RuleId SendName
  | ExternalTakeFact WorkflowFact
  | WaitsFor WorkflowScope WorkflowFact
  deriving (Eq, Show)

data ConstraintError
  = MissingFactSource WorkflowFact
  | MissingTakeSource RuleId WorkflowFact
  | MissingPipeSource RuleId TypeName
  | MissingExternalMake RuleId SendName
  | ExternalTakeAutoMake WorkflowFact
  | DuplicateMaker WorkflowFact [RuleId]
  | DuplicatePipeMaker TypeName [RuleId]
  | DependencyCycle [WorkflowFact]
  | DeadWaitCandidate WorkflowScope WorkflowFact
  deriving (Eq, Show)

data SmtProposition
  = ProveFactClosure
  | ProvePipeInputClosure
  | ProveExternalMakeClosure
  | ProveNoDependencyCycle
  | ProveNoDuplicateMaker
  | ProveNoDuplicatePipeMaker
  | ProveExternalTakeNotAutoMade
  | ProveWaitHasSource
  deriving (Eq, Show)

data SmtStatus
  = SmtPassed
  | SmtFailed
  | SmtSkipped
  deriving (Eq, Show)

data SmtEvidence
  = HaskellConstraintEvidence [ConstraintError]
  | SolverEvidence String
  | NoSolverEvidence String
  deriving (Eq, Show)

data SmtResult = SmtResult
  { smtResultProposition :: SmtProposition
  , smtResultStatus :: SmtStatus
  , smtResultEvidence :: SmtEvidence
  }
  deriving (Eq, Show)

newtype SmtBackend = SmtBackend
  { proveWithBackend :: SmtProposition -> [ConstraintFact] -> SmtResult
  }

data SmtSolver = SmtSolver
  { smtSolverName :: String
  , smtSolverCommand :: FilePath
  , smtSolverArguments :: [String]
  }
  deriving (Eq, Show)

data SolverAnswer
  = SolverSat
  | SolverUnsat
  | SolverUnknown
  | SolverNoAnswer String
  deriving (Eq, Show)

constraintsFromNativeAppPlan :: NativeAppPlan -> [ConstraintFact]
constraintsFromNativeAppPlan plan =
  unique
    ( map RequiresFact (nativeAppPlanRootFacts plan)
        ++ declaredExternalMakes plan
        ++ concatMap ruleConstraints (nativeAppPlanFactRules plan)
    )

constraintsFromAppPlan :: AppBlueprint -> EffectTheory -> Either String [ConstraintFact]
constraintsFromAppPlan blueprint effects =
  case buildNativeApp blueprint effects of
    Left message ->
      Left message
    Right plan ->
      Right
        ( unique
            ( constraintsFromNativeAppPlan plan
                ++ waitConstraintsFromBlueprint blueprint
            )
        )

declaredExternalMakes :: NativeAppPlan -> [ConstraintFact]
declaredExternalMakes plan =
  [ ExternalMakeDeclared (sendContractName currentContract)
  | currentContract <- nativeAppPlanSendContracts plan
  ]

ruleConstraints :: NativeFactRule -> [ConstraintFact]
ruleConstraints currentRule
  | nativeRuleExternal currentRule =
      ExternalTakeFact (nativeRuleFact currentRule)
        : map (PipeMakes ruleId) (nativeRuleMakes currentRule)
  | otherwise =
      [Makes ruleId (nativeRuleFact currentRule)]
        ++ map (Takes ruleId) (nativeRuleNeeds currentRule)
        ++ map (PipeNeeds ruleId) (nativeRuleTakes currentRule)
        ++ map (PipeMakes ruleId) (nativeRuleMakes currentRule)
        ++ map (UsesExternalMake ruleId) (nativeRuleUses currentRule)
        ++ map transformConstraint (nativeRuleTransforms currentRule)
        ++ map (HandlesError ruleId) (nativeRuleErrors currentRule)
  where
    ruleId =
      RuleId (nativeRuleFact currentRule)
    transformConstraint (input, output, name) =
      UsesTransform ruleId name input output

waitConstraintsFromBlueprint :: AppBlueprint -> [ConstraintFact]
waitConstraintsFromBlueprint blueprint =
  collectWorkflowWaits RootScope (blueprintApp blueprint)
    ++ collectHangingWaits (blueprintHanging blueprint)

collectWorkflowWaits :: WorkflowScope -> Workflow WorkflowFact hook -> [ConstraintFact]
collectWorkflowWaits currentScope currentWorkflow =
  case currentWorkflow of
    FactWorkflow _ ->
      []
    ChainWorkflow label steps ->
      concatMap (collectWorkflowWaits (NamedScope label)) (chainItems steps)
    ParallelWorkflow label branches ->
      concatMap (collectWorkflowWaits (NamedScope label)) (parallelItems branches)
    FallbackWorkflow branches ->
      concatMap (collectWorkflowWaits currentScope) (fallbackItems branches)
    RaceWorkflow branches ->
      concatMap (collectWorkflowWaits currentScope) (raceItems branches)
    ChoiceWorkflow _ choices ->
      concatMap (collectWorkflowWaits currentScope . snd) (choiceItems choices)
    WaitWorkflow currentWait body ->
      map (WaitsFor currentScope) (collectFactExpr (waitFacts currentWait))
        ++ collectWorkflowWaits currentScope body

collectHangingWaits ::
  Hanging (HangingAction WorkflowFact hook (Workflow WorkflowFact hook)) ->
  [ConstraintFact]
collectHangingWaits actions =
  concatMap collectHangingActionWaits (hangingItems actions)

collectHangingActionWaits ::
  HangingAction WorkflowFact hook (Workflow WorkflowFact hook) ->
  [ConstraintFact]
collectHangingActionWaits currentAction =
  case currentAction of
    HangingCallback currentCallback ->
      collectWorkflowWaits RootScope (callbackBody currentCallback)
    HangingSuspense _ ->
      []
    HangingLoop currentLoop ->
      collectWorkflowWaits RootScope (loopBody currentLoop)
    HangingMiddleware _ body ->
      collectWorkflowWaits RootScope body

collectFactExpr :: FactExpr WorkflowFact -> [WorkflowFact]
collectFactExpr (FactItems currentFacts) =
  requirementItems currentFacts
collectFactExpr (FactAll currentFacts) =
  concatMap collectFactExpr currentFacts
collectFactExpr (FactAny currentFacts) =
  concatMap collectFactExpr currentFacts

checkConstraintFacts :: [ConstraintFact] -> [ConstraintError]
checkConstraintFacts facts =
  unique
    ( missingFactSources facts
        ++ missingTakeSources facts
        ++ missingPipeSources facts
        ++ missingExternalMakes facts
        ++ externalTakeAutoMakes facts
        ++ duplicateMakers facts
        ++ duplicatePipeMakers facts
        ++ dependencyCycles facts
        ++ deadWaitCandidates facts
    )

missingFactSources :: [ConstraintFact] -> [ConstraintError]
missingFactSources facts =
  [ MissingFactSource currentFact
  | currentFact <- requiredFacts facts
  , not (hasFactSource facts currentFact)
  ]

missingTakeSources :: [ConstraintFact] -> [ConstraintError]
missingTakeSources facts =
  [ MissingTakeSource currentRule currentFact
  | (currentRule, currentFact) <- takenFacts facts
  , not (hasFactSource facts currentFact)
  ]

missingPipeSources :: [ConstraintFact] -> [ConstraintError]
missingPipeSources facts =
  [ MissingPipeSource currentRule currentType
  | (currentRule, currentType) <- pipeNeededTypes facts
  , currentType `notElem` pipeMadeTypes facts
  ]

missingExternalMakes :: [ConstraintFact] -> [ConstraintError]
missingExternalMakes facts =
  [ MissingExternalMake currentRule currentSend
  | (currentRule, currentSend) <- usedExternalMakes facts ++ errorHandlers facts
  , currentSend `notElem` declaredExternalMakeNames facts
  ]

externalTakeAutoMakes :: [ConstraintFact] -> [ConstraintError]
externalTakeAutoMakes facts =
  [ ExternalTakeAutoMake currentFact
  | currentFact <- externalTakeFacts facts
  , currentFact `elem` internallyMadeFacts facts
  ]

duplicateMakers :: [ConstraintFact] -> [ConstraintError]
duplicateMakers facts =
  [ DuplicateMaker currentFact currentRules
  | currentFact <- unique (internallyMadeFacts facts)
  , let currentRules = makerRulesFor facts currentFact
  , length currentRules > 1
  ]

duplicatePipeMakers :: [ConstraintFact] -> [ConstraintError]
duplicatePipeMakers facts =
  [ DuplicatePipeMaker currentType currentRules
  | currentType <- unique (pipeMadeTypes facts)
  , let currentRules = pipeMakerRulesFor facts currentType
  , length currentRules > 1
  ]

dependencyCycles :: [ConstraintFact] -> [ConstraintError]
dependencyCycles facts =
  map DependencyCycle (unique (concatMap (cyclesFrom facts []) (internallyMadeFacts facts)))

deadWaitCandidates :: [ConstraintFact] -> [ConstraintError]
deadWaitCandidates facts =
  [ DeadWaitCandidate currentScope currentFact
  | (currentScope, currentFact) <- waitedFacts facts
  , not (hasFactSource facts currentFact)
  ]

requiredFacts :: [ConstraintFact] -> [WorkflowFact]
requiredFacts facts =
  [ currentFact
  | RequiresFact currentFact <- facts
  ]

internallyMadeFacts :: [ConstraintFact] -> [WorkflowFact]
internallyMadeFacts facts =
  [ currentFact
  | Makes _ currentFact <- facts
  ]

externalTakeFacts :: [ConstraintFact] -> [WorkflowFact]
externalTakeFacts facts =
  [ currentFact
  | ExternalTakeFact currentFact <- facts
  ]

hasFactSource :: [ConstraintFact] -> WorkflowFact -> Bool
hasFactSource facts currentFact =
  currentFact `elem` internallyMadeFacts facts
    || currentFact `elem` externalTakeFacts facts

takenFacts :: [ConstraintFact] -> [(RuleId, WorkflowFact)]
takenFacts facts =
  [ (currentRule, currentFact)
  | Takes currentRule currentFact <- facts
  ]

pipeNeededTypes :: [ConstraintFact] -> [(RuleId, TypeName)]
pipeNeededTypes facts =
  [ (currentRule, currentType)
  | PipeNeeds currentRule currentType <- facts
  ]

pipeMadeTypes :: [ConstraintFact] -> [TypeName]
pipeMadeTypes facts =
  [ currentType
  | PipeMakes _ currentType <- facts
  ]

usedExternalMakes :: [ConstraintFact] -> [(RuleId, SendName)]
usedExternalMakes facts =
  [ (currentRule, currentSend)
  | UsesExternalMake currentRule currentSend <- facts
  ]

errorHandlers :: [ConstraintFact] -> [(RuleId, SendName)]
errorHandlers facts =
  [ (currentRule, currentSend)
  | HandlesError currentRule currentSend <- facts
  ]

declaredExternalMakeNames :: [ConstraintFact] -> [SendName]
declaredExternalMakeNames facts =
  [ currentSend
  | ExternalMakeDeclared currentSend <- facts
  ]

waitedFacts :: [ConstraintFact] -> [(WorkflowScope, WorkflowFact)]
waitedFacts facts =
  [ (currentScope, currentFact)
  | WaitsFor currentScope currentFact <- facts
  ]

makerRulesFor :: [ConstraintFact] -> WorkflowFact -> [RuleId]
makerRulesFor facts currentFact =
  [ currentRule
  | Makes currentRule madeFact <- facts
  , madeFact == currentFact
  ]

pipeMakerRulesFor :: [ConstraintFact] -> TypeName -> [RuleId]
pipeMakerRulesFor facts currentType =
  [ currentRule
  | PipeMakes currentRule madeType <- facts
  , madeType == currentType
  ]

cyclesFrom :: [ConstraintFact] -> [WorkflowFact] -> WorkflowFact -> [[WorkflowFact]]
cyclesFrom facts stack currentFact
  | currentFact `elem` stack =
      [reverse (currentFact : takeUntil currentFact stack)]
  | otherwise =
      concatMap (cyclesFrom facts (currentFact : stack)) (dependenciesForFact facts currentFact)

dependenciesForFact :: [ConstraintFact] -> WorkflowFact -> [WorkflowFact]
dependenciesForFact facts currentFact =
  unique
    [ neededFact
    | currentRule <- makerRulesFor facts currentFact
    , (takenByRule, neededFact) <- takenFacts facts
    , takenByRule == currentRule
    ]

takeUntil :: Eq item => item -> [item] -> [item]
takeUntil _ [] =
  []
takeUntil item (currentItem : rest)
  | item == currentItem =
      [currentItem]
  | otherwise =
      currentItem : takeUntil item rest

z3Solver :: SmtSolver
z3Solver =
  SmtSolver
    { smtSolverName = "z3"
    , smtSolverCommand = "z3"
    , smtSolverArguments = ["-in", "-smt2"]
    }

cvc5Solver :: SmtSolver
cvc5Solver =
  SmtSolver
    { smtSolverName = "cvc5"
    , smtSolverCommand = "cvc5"
    , smtSolverArguments = ["--lang", "smt2"]
    }

availableSmtSolver :: IO (Maybe SmtSolver)
availableSmtSolver = do
  maybeZ3 <- solverIfAvailable z3Solver
  case maybeZ3 of
    Just currentSolver ->
      pure (Just currentSolver)
    Nothing ->
      solverIfAvailable cvc5Solver

solverIfAvailable :: SmtSolver -> IO (Maybe SmtSolver)
solverIfAvailable solver = do
  maybeCommand <- findExecutable (smtSolverCommand solver)
  case maybeCommand of
    Just command ->
      pure (Just solver {smtSolverCommand = command})
    Nothing ->
      pure Nothing

defaultSmtPropositions :: [SmtProposition]
defaultSmtPropositions =
  [ ProveFactClosure
  , ProvePipeInputClosure
  , ProveExternalMakeClosure
  , ProveNoDependencyCycle
  , ProveNoDuplicateMaker
  , ProveNoDuplicatePipeMaker
  , ProveExternalTakeNotAutoMade
  , ProveWaitHasSource
  ]

proveMinimalCore :: [ConstraintFact] -> [SmtResult]
proveMinimalCore =
  proveMinimalCoreWith haskellConstraintBackend

proveMinimalCoreWith :: SmtBackend -> [ConstraintFact] -> [SmtResult]
proveMinimalCoreWith backend facts =
  [ proveWithBackend backend currentProposition facts
  | currentProposition <- defaultSmtPropositions
  ]

proveMinimalCoreWithAvailableSolver :: [ConstraintFact] -> IO [SmtResult]
proveMinimalCoreWithAvailableSolver facts = do
  maybeSolver <- availableSmtSolver
  case maybeSolver of
    Just solver ->
      proveMinimalCoreWithSolver solver facts
    Nothing ->
      pure
        [ skippedResult currentProposition "no external SMT solver found in PATH; tried z3 and cvc5"
        | currentProposition <- defaultSmtPropositions
        ]

proveMinimalCoreWithSolver :: SmtSolver -> [ConstraintFact] -> IO [SmtResult]
proveMinimalCoreWithSolver solver facts =
  mapM (provePropositionWithSolver solver facts) defaultSmtPropositions

provePropositionWithSolver :: SmtSolver -> [ConstraintFact] -> SmtProposition -> IO SmtResult
provePropositionWithSolver solver facts proposition = do
  solverResult <- runSolver solver (smtLibForProposition proposition facts)
  pure (resultFromSolver proposition solver solverResult)

haskellConstraintBackend :: SmtBackend
haskellConstraintBackend =
  SmtBackend proveWithHaskellConstraints

proveWithHaskellConstraints :: SmtProposition -> [ConstraintFact] -> SmtResult
proveWithHaskellConstraints proposition facts =
  resultFromErrors proposition (errorsForProposition proposition (checkConstraintFacts facts))

resultFromErrors :: SmtProposition -> [ConstraintError] -> SmtResult
resultFromErrors proposition errors =
  SmtResult
    { smtResultProposition = proposition
    , smtResultStatus =
        if null errors
          then SmtPassed
          else SmtFailed
    , smtResultEvidence =
        HaskellConstraintEvidence errors
    }

errorsForProposition :: SmtProposition -> [ConstraintError] -> [ConstraintError]
errorsForProposition proposition =
  filter (errorMatchesProposition proposition)

errorMatchesProposition :: SmtProposition -> ConstraintError -> Bool
errorMatchesProposition proposition currentError =
  case proposition of
    ProveFactClosure ->
      case currentError of
        MissingFactSource _ -> True
        MissingTakeSource _ _ -> True
        _ -> False
    ProvePipeInputClosure ->
      case currentError of
        MissingPipeSource _ _ -> True
        _ -> False
    ProveExternalMakeClosure ->
      case currentError of
        MissingExternalMake _ _ -> True
        _ -> False
    ProveNoDependencyCycle ->
      case currentError of
        DependencyCycle _ -> True
        _ -> False
    ProveNoDuplicateMaker ->
      case currentError of
        DuplicateMaker _ _ -> True
        _ -> False
    ProveNoDuplicatePipeMaker ->
      case currentError of
        DuplicatePipeMaker _ _ -> True
        _ -> False
    ProveExternalTakeNotAutoMade ->
      case currentError of
        ExternalTakeAutoMake _ -> True
        _ -> False
    ProveWaitHasSource ->
      case currentError of
        DeadWaitCandidate _ _ -> True
        _ -> False

smtLibForProposition :: SmtProposition -> [ConstraintFact] -> String
smtLibForProposition proposition facts =
  joinWith
    "\n"
    ( [ "; dsl-bootstrap constraint proof"
      , "; proposition: " ++ renderSmtProposition proposition
      ]
        ++ map (("; violation: " ++) . renderConstraintError) errors
        ++ [ "(set-logic QF_UF)"
           , "(assert " ++ assertion ++ ")"
           , "(check-sat)"
           ]
    )
  where
    errors =
      errorsForProposition proposition (checkConstraintFacts facts)
    assertion =
      if null errors
        then "false"
        else "true"

runSolver :: SmtSolver -> String -> IO (Either String SolverAnswer)
runSolver solver script = do
  result <-
    try
      ( readProcessWithExitCode
          (smtSolverCommand solver)
          (smtSolverArguments solver)
          script
      ) ::
      IO (Either IOException (ExitCode, String, String))
  case result of
    Left exception ->
      pure (Left (show exception))
    Right (exitCode, stdoutText, stderrText) ->
      case exitCode of
        ExitSuccess ->
          pure (Right (parseSolverAnswer stdoutText stderrText))
        ExitFailure _ ->
          pure (Left (trim (stdoutText ++ "\n" ++ stderrText)))

parseSolverAnswer :: String -> String -> SolverAnswer
parseSolverAnswer stdoutText stderrText =
  case firstNonEmptyLine (lines stdoutText ++ lines stderrText) of
    Just "sat" ->
      SolverSat
    Just "unsat" ->
      SolverUnsat
    Just "unknown" ->
      SolverUnknown
    Just other ->
      SolverNoAnswer other
    Nothing ->
      SolverNoAnswer ""

resultFromSolver :: SmtProposition -> SmtSolver -> Either String SolverAnswer -> SmtResult
resultFromSolver proposition solver solverResult =
  case solverResult of
    Left errorReport ->
      SmtResult
        { smtResultProposition = proposition
        , smtResultStatus = SmtSkipped
        , smtResultEvidence =
            NoSolverEvidence (renderSmtSolver solver ++ " failed: " ++ errorReport)
        }
    Right answer ->
      SmtResult
        { smtResultProposition = proposition
        , smtResultStatus = statusFromSolverAnswer answer
        , smtResultEvidence =
            SolverEvidence
              (renderSmtSolver solver ++ " returned " ++ renderSolverAnswer answer)
        }

statusFromSolverAnswer :: SolverAnswer -> SmtStatus
statusFromSolverAnswer answer =
  case answer of
    SolverUnsat ->
      SmtPassed
    SolverSat ->
      SmtFailed
    SolverUnknown ->
      SmtSkipped
    SolverNoAnswer _ ->
      SmtSkipped

skippedResult :: SmtProposition -> String -> SmtResult
skippedResult proposition message =
  SmtResult
    { smtResultProposition = proposition
    , smtResultStatus = SmtSkipped
    , smtResultEvidence = NoSolverEvidence message
    }

smtPassed :: [SmtResult] -> Bool
smtPassed =
  all ((== SmtPassed) . smtResultStatus)

renderConstraintFacts :: [ConstraintFact] -> String
renderConstraintFacts =
  joinWith "\n" . map renderConstraintFact

renderConstraintFact :: ConstraintFact -> String
renderConstraintFact (RequiresFact currentFact) =
  "requiresFact " ++ show currentFact
renderConstraintFact (ExternalMakeDeclared currentSend) =
  "externalMakeDeclared " ++ show currentSend
renderConstraintFact (Makes currentRule currentFact) =
  "makes " ++ renderRuleId currentRule ++ " " ++ show currentFact
renderConstraintFact (Takes currentRule currentFact) =
  "takes " ++ renderRuleId currentRule ++ " " ++ show currentFact
renderConstraintFact (PipeNeeds currentRule currentType) =
  "pipeNeeds " ++ renderRuleId currentRule ++ " " ++ show currentType
renderConstraintFact (PipeMakes currentRule currentType) =
  "pipeMakes " ++ renderRuleId currentRule ++ " " ++ show currentType
renderConstraintFact (UsesExternalMake currentRule currentSend) =
  "usesExternalMake " ++ renderRuleId currentRule ++ " " ++ show currentSend
renderConstraintFact (UsesTransform currentRule currentTransform currentInput currentOutput) =
  "usesTransform "
    ++ renderRuleId currentRule
    ++ " "
    ++ show currentTransform
    ++ " "
    ++ show currentInput
    ++ " "
    ++ show currentOutput
renderConstraintFact (HandlesError currentRule currentSend) =
  "handlesError " ++ renderRuleId currentRule ++ " " ++ show currentSend
renderConstraintFact (ExternalTakeFact currentFact) =
  "externalTake " ++ show currentFact
renderConstraintFact (WaitsFor currentScope currentFact) =
  "waitsFor " ++ renderWorkflowScope currentScope ++ " " ++ show currentFact

renderConstraintError :: ConstraintError -> String
renderConstraintError (MissingFactSource currentFact) =
  "missing source for fact " ++ show currentFact
renderConstraintError (MissingTakeSource currentRule currentFact) =
  renderRuleId currentRule ++ " takes fact without source " ++ show currentFact
renderConstraintError (MissingPipeSource currentRule currentType) =
  renderRuleId currentRule ++ " needs pipe input without output source " ++ show currentType
renderConstraintError (MissingExternalMake currentRule currentSend) =
  renderRuleId currentRule ++ " uses undeclared externalMake " ++ show currentSend
renderConstraintError (ExternalTakeAutoMake currentFact) =
  "externalTake fact is also internally made " ++ show currentFact
renderConstraintError (DuplicateMaker currentFact currentRules) =
  "duplicate makers for fact " ++ show currentFact ++ ": " ++ joinWith ", " (map renderRuleId currentRules)
renderConstraintError (DuplicatePipeMaker currentType currentRules) =
  "duplicate pipe makers for " ++ show currentType ++ ": " ++ joinWith ", " (map renderRuleId currentRules)
renderConstraintError (DependencyCycle currentFacts) =
  "take/make dependency cycle: " ++ joinWith " -> " (map show currentFacts)
renderConstraintError (DeadWaitCandidate currentScope currentFact) =
  "wait in " ++ renderWorkflowScope currentScope ++ " has no visible source for " ++ show currentFact

renderSmtResults :: [SmtResult] -> String
renderSmtResults =
  joinWith "\n" . map renderSmtResult

renderSmtResult :: SmtResult -> String
renderSmtResult result =
  renderSmtStatus (smtResultStatus result)
    ++ " "
    ++ renderSmtProposition (smtResultProposition result)
    ++ renderSmtEvidenceSuffix (smtResultEvidence result)

renderSmtEvidenceSuffix :: SmtEvidence -> String
renderSmtEvidenceSuffix evidence =
  case evidence of
    HaskellConstraintEvidence [] ->
      ""
    _ ->
      "\n" ++ indentLines 2 (renderSmtEvidence evidence)

renderSmtEvidence :: SmtEvidence -> String
renderSmtEvidence evidence =
  case evidence of
    HaskellConstraintEvidence [] ->
      "haskell constraint evidence: no violations"
    HaskellConstraintEvidence errors ->
      joinWith "\n" ("haskell constraint evidence:" : map (("- " ++) . renderConstraintError) errors)
    SolverEvidence message ->
      "solver evidence: " ++ message
    NoSolverEvidence message ->
      "solver skipped: " ++ message

renderSmtSolver :: SmtSolver -> String
renderSmtSolver solver =
  smtSolverName solver ++ " (" ++ smtSolverCommand solver ++ ")"

renderSmtStatus :: SmtStatus -> String
renderSmtStatus SmtPassed =
  "passed"
renderSmtStatus SmtFailed =
  "failed"
renderSmtStatus SmtSkipped =
  "skipped"

renderSmtProposition :: SmtProposition -> String
renderSmtProposition ProveFactClosure =
  "fact-closure"
renderSmtProposition ProvePipeInputClosure =
  "pipe-input-closure"
renderSmtProposition ProveExternalMakeClosure =
  "external-make-closure"
renderSmtProposition ProveNoDependencyCycle =
  "no-dependency-cycle"
renderSmtProposition ProveNoDuplicateMaker =
  "no-duplicate-maker"
renderSmtProposition ProveNoDuplicatePipeMaker =
  "no-duplicate-pipe-maker"
renderSmtProposition ProveExternalTakeNotAutoMade =
  "external-take-not-auto-made"
renderSmtProposition ProveWaitHasSource =
  "wait-has-source"

renderSolverAnswer :: SolverAnswer -> String
renderSolverAnswer SolverSat =
  "sat"
renderSolverAnswer SolverUnsat =
  "unsat"
renderSolverAnswer SolverUnknown =
  "unknown"
renderSolverAnswer (SolverNoAnswer message) =
  "no-answer " ++ show message

renderRuleId :: RuleId -> String
renderRuleId (RuleId currentFact) =
  "rule(" ++ show currentFact ++ ")"

renderWorkflowScope :: WorkflowScope -> String
renderWorkflowScope RootScope =
  "root"
renderWorkflowScope (NamedScope currentName) =
  show currentName

unique :: Eq item => [item] -> [item]
unique =
  foldl appendUnique []

appendUnique :: Eq item => [item] -> item -> [item]
appendUnique items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest

indentLines :: Int -> String -> String
indentLines count text =
  joinWith "\n" (map (replicate count ' ' ++) (lines text))

firstNonEmptyLine :: [String] -> Maybe String
firstNonEmptyLine [] =
  Nothing
firstNonEmptyLine (currentLine : rest)
  | trim currentLine == "" =
      firstNonEmptyLine rest
  | otherwise =
      Just (trim currentLine)

trim :: String -> String
trim =
  reverse . dropWhile isSpaceLike . reverse . dropWhile isSpaceLike

isSpaceLike :: Char -> Bool
isSpaceLike currentChar =
  currentChar == ' '
    || currentChar == '\n'
    || currentChar == '\r'
    || currentChar == '\t'
