module Core.Effect.Constraint.SMT
  ( SmtBackend (..)
  , SmtEvidence (..)
  , SmtProposition (..)
  , SmtResult (..)
  , SmtSolver (..)
  , SmtStatus (..)
  , availableSmtSolver
  , cvc5Solver
  , defaultSmtPropositions
  , proveMinimalCore
  , proveMinimalCoreWith
  , proveMinimalCoreWithAvailableSolver
  , proveMinimalCoreWithSolver
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
import Data.Char
  ( isAlphaNum
  )
import Data.List
  ( isPrefixOf
  )
import System.Directory
  ( doesFileExist
  , findExecutable
  , getCurrentDirectory
  , listDirectory
  )
import System.Exit
  ( ExitCode (..)
  )
import System.FilePath
  ( (</>)
  )
import System.Process
  ( readProcessWithExitCode
  )

import AST.Vocabulary
  ( WorkflowFact
  )
import Core.App.Boundary
  ( MinimalCoreReport (..)
  )
import Core.Effect.Constraint
  ( ConstraintError (..)
  , ConstraintFact (..)
  , RuleId (..)
  , WorkflowScope
  , renderConstraintError
  )
import Effects.EffectTheory
  ( SendName
  , TypeName
  )

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
  { proveWithBackend :: SmtProposition -> MinimalCoreReport -> SmtResult
  }

data SmtSolver = SmtSolver
  { smtSolverName :: String
  , smtSolverCommand :: FilePath
  , smtSolverArguments :: [String]
  }
  deriving (Eq, Show)

data SolverExpectedResult
  = ExpectSatForPass
  | ExpectUnsatForPass
  deriving (Eq, Show)

data SolverAnswer
  = SolverSat
  | SolverUnsat
  | SolverUnknown
  | SolverNoAnswer String
  deriving (Eq, Show)

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
    Nothing -> do
      maybeCvc5 <- solverIfAvailable cvc5Solver
      case maybeCvc5 of
        Just currentSolver ->
          pure (Just currentSolver)
        Nothing ->
          localZ3SolverIfAvailable

solverIfAvailable :: SmtSolver -> IO (Maybe SmtSolver)
solverIfAvailable solver = do
  maybeCommand <- findExecutable (smtSolverCommand solver)
  case maybeCommand of
    Just command ->
      pure (Just solver {smtSolverCommand = command})
    Nothing ->
      pure Nothing

localZ3SolverIfAvailable :: IO (Maybe SmtSolver)
localZ3SolverIfAvailable = do
  currentDirectory <- getCurrentDirectory
  let toolsDirectory =
        currentDirectory </> ".tools"
  maybeEntries <- try (listDirectory toolsDirectory) :: IO (Either IOException [FilePath])
  case maybeEntries of
    Left _ ->
      pure Nothing
    Right entries ->
      firstExistingSolver
        [ toolsDirectory </> entry </> "bin" </> "z3.exe"
        | entry <- entries
        , "z3-" `isPrefixOf` entry
        ]

firstExistingSolver :: [FilePath] -> IO (Maybe SmtSolver)
firstExistingSolver [] =
  pure Nothing
firstExistingSolver (candidate : rest) = do
  exists <- doesFileExist candidate
  if exists
    then pure (Just z3Solver {smtSolverCommand = candidate})
    else firstExistingSolver rest

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

proveMinimalCore :: MinimalCoreReport -> [SmtResult]
proveMinimalCore =
  proveMinimalCoreWith haskellConstraintBackend

proveMinimalCoreWith :: SmtBackend -> MinimalCoreReport -> [SmtResult]
proveMinimalCoreWith backend report =
  [ proveWithBackend backend currentProposition report
  | currentProposition <- defaultSmtPropositions
  ]

proveMinimalCoreWithAvailableSolver :: MinimalCoreReport -> IO [SmtResult]
proveMinimalCoreWithAvailableSolver report = do
  maybeSolver <- availableSmtSolver
  case maybeSolver of
    Just solver ->
      proveMinimalCoreWithSolver solver report
    Nothing ->
      pure
        [ skippedResult currentProposition "no external SMT solver found in PATH; tried z3 and cvc5"
        | currentProposition <- defaultSmtPropositions
        ]

proveMinimalCoreWithSolver :: SmtSolver -> MinimalCoreReport -> IO [SmtResult]
proveMinimalCoreWithSolver solver report =
  mapM (provePropositionWithSolver solver report) defaultSmtPropositions

provePropositionWithSolver :: SmtSolver -> MinimalCoreReport -> SmtProposition -> IO SmtResult
provePropositionWithSolver solver report proposition = do
  let problem =
        smtProblemForProposition proposition report
  solverResult <- runSolver solver (smtProblemScript problem)
  pure (resultFromSolver proposition solver problem solverResult)

haskellConstraintBackend :: SmtBackend
haskellConstraintBackend =
  SmtBackend proveWithHaskellConstraints

proveWithHaskellConstraints :: SmtProposition -> MinimalCoreReport -> SmtResult
proveWithHaskellConstraints proposition report =
  resultFromErrors proposition (errorsForProposition proposition (minimalCoreConstraintErrors report))

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
    ProveExternalMakeClosure ->
      case currentError of
        MissingExternalMake _ _ -> True
        _ -> False
    ProvePipeInputClosure ->
      case currentError of
        MissingPipeSource _ _ -> True
        MissingPipeTakeSource _ _ _ -> True
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

data SmtProblem = SmtProblem
  { smtProblemExpectedResult :: SolverExpectedResult
  , smtProblemScript :: String
  }

smtLibForProposition :: SmtProposition -> MinimalCoreReport -> String
smtLibForProposition proposition report =
  smtProblemScript (smtProblemForProposition proposition report)

smtProblemForProposition :: SmtProposition -> MinimalCoreReport -> SmtProblem
smtProblemForProposition proposition report =
  case proposition of
    ProveNoDependencyCycle ->
      SmtProblem ExpectSatForPass (dependencyCycleSmtLib proposition constraints)
    _ ->
      SmtProblem ExpectUnsatForPass (violationSmtLib proposition constraints (violationTerms proposition constraints))
  where
    constraints =
      minimalCoreConstraints report

violationSmtLib :: SmtProposition -> [ConstraintFact] -> [String] -> String
violationSmtLib proposition facts terms =
  joinWith
    "\n"
    ( [ "(set-logic ALL)"
      , "; proposition: " ++ renderSmtProposition proposition
      ]
        ++ factSourceDefinitions facts
        ++ pipeSourceDefinitions facts
        ++ sendDefinitions facts
        ++ countDefinitions facts
        ++ [ "(assert " ++ orMany terms ++ ")"
           , "(check-sat)"
           ]
    )

dependencyCycleSmtLib :: SmtProposition -> [ConstraintFact] -> String
dependencyCycleSmtLib proposition facts =
  joinWith
    "\n"
    ( [ "(set-logic QF_LIA)"
      , "; proposition: " ++ renderSmtProposition proposition
      , "; satisfiable means the dependency graph admits a topological ranking"
      ]
        ++ concatMap rankDeclaration universe
        ++ map dependencyAssertion edges
        ++ ["(check-sat)"]
    )
  where
    edges =
      dependencyEdges facts
    universe =
      unique (concatMap (\(fromFact, toFact) -> [fromFact, toFact]) edges)
    bound =
      show (max 1 (length universe))
    rankDeclaration currentFact =
      [ "(declare-const " ++ rankSymbol currentFact ++ " Int)"
      , "(assert (>= " ++ rankSymbol currentFact ++ " 0))"
      , "(assert (< " ++ rankSymbol currentFact ++ " " ++ bound ++ "))"
      ]
    dependencyAssertion (neededFact, madeFact) =
      "(assert (< " ++ rankSymbol neededFact ++ " " ++ rankSymbol madeFact ++ "))"

violationTerms :: SmtProposition -> [ConstraintFact] -> [String]
violationTerms proposition facts =
  case proposition of
    ProveFactClosure ->
      factClosureViolationTerms facts
    ProvePipeInputClosure ->
      pipeInputClosureViolationTerms facts
    ProveExternalMakeClosure ->
      externalMakeClosureViolationTerms facts
    ProveNoDuplicateMaker ->
      duplicateMakerViolationTerms facts
    ProveNoDuplicatePipeMaker ->
      duplicatePipeMakerViolationTerms facts
    ProveExternalTakeNotAutoMade ->
      externalTakeAutoMakeViolationTerms facts
    ProveWaitHasSource ->
      waitSourceViolationTerms facts
    ProveNoDependencyCycle ->
      []

factClosureViolationTerms :: [ConstraintFact] -> [String]
factClosureViolationTerms facts =
  [ "(and " ++ requiredSymbol currentFact ++ " (not " ++ sourceSymbol currentFact ++ "))"
  | currentFact <- requiredFacts facts
  ]
    ++ [ "(not " ++ sourceSymbol currentFact ++ ")"
       | (_, currentFact) <- takenFacts facts
       ]

pipeInputClosureViolationTerms :: [ConstraintFact] -> [String]
pipeInputClosureViolationTerms facts =
  [ "(not " ++ pipeSourceSymbol currentType ++ ")"
  | (_, currentType) <- pipeNeededTypes facts
  ]
    ++ [ "(not " ++ sourceSymbol currentFact ++ ")"
       | (_, _, currentFact) <- pipeTakenFacts facts
       ]

externalMakeClosureViolationTerms :: [ConstraintFact] -> [String]
externalMakeClosureViolationTerms facts =
  [ "(not " ++ declaredSendSymbol currentSend ++ ")"
  | (_, currentSend) <- usedExternalMakes facts ++ errorHandlers facts
  ]

duplicateMakerViolationTerms :: [ConstraintFact] -> [String]
duplicateMakerViolationTerms facts =
  [ "(> " ++ makerCountSymbol currentFact ++ " 1)"
  | currentFact <- unique (internallyMadeFacts facts)
  ]

duplicatePipeMakerViolationTerms :: [ConstraintFact] -> [String]
duplicatePipeMakerViolationTerms facts =
  [ "(> " ++ pipeMakerCountSymbol currentType ++ " 1)"
  | currentType <- unique (pipeMadeTypes facts)
  ]

externalTakeAutoMakeViolationTerms :: [ConstraintFact] -> [String]
externalTakeAutoMakeViolationTerms facts =
  [ "(and " ++ externalTakeSymbol currentFact ++ " " ++ internallyMadeSymbol currentFact ++ ")"
  | currentFact <- unique (externalTakeFacts facts ++ internallyMadeFacts facts)
  ]

waitSourceViolationTerms :: [ConstraintFact] -> [String]
waitSourceViolationTerms facts =
  [ "(not " ++ sourceSymbol currentFact ++ ")"
  | (_, currentFact) <- waitedFacts facts
  ]

factSourceDefinitions :: [ConstraintFact] -> [String]
factSourceDefinitions facts =
  concatMap defineFact (allFacts facts)
  where
    defineFact currentFact =
      [ defineBool (sourceSymbol currentFact) (hasFactSource facts currentFact)
      , defineBool (requiredSymbol currentFact) (currentFact `elem` requiredFacts facts)
      , defineBool (externalTakeSymbol currentFact) (currentFact `elem` externalTakeFacts facts)
      , defineBool (internallyMadeSymbol currentFact) (currentFact `elem` internallyMadeFacts facts)
      ]

pipeSourceDefinitions :: [ConstraintFact] -> [String]
pipeSourceDefinitions facts =
  [ defineBool (pipeSourceSymbol currentType) (currentType `elem` pipeMadeTypes facts)
  | currentType <- allTypes facts
  ]

sendDefinitions :: [ConstraintFact] -> [String]
sendDefinitions facts =
  [ defineBool (declaredSendSymbol currentSend) (currentSend `elem` declaredExternalMakeNames facts)
  | currentSend <- allSends facts
  ]

countDefinitions :: [ConstraintFact] -> [String]
countDefinitions facts =
  [ defineInt (makerCountSymbol currentFact) (length (makerRulesFor facts currentFact))
  | currentFact <- unique (internallyMadeFacts facts)
  ]
    ++ [ defineInt (pipeMakerCountSymbol currentType) (length (pipeMakerRulesFor facts currentType))
       | currentType <- unique (pipeMadeTypes facts)
       ]

defineBool :: String -> Bool -> String
defineBool name value =
  "(define-fun " ++ name ++ " () Bool " ++ smtBool value ++ ")"

defineInt :: String -> Int -> String
defineInt name value =
  "(define-fun " ++ name ++ " () Int " ++ show value ++ ")"

smtBool :: Bool -> String
smtBool True =
  "true"
smtBool False =
  "false"

orMany :: [String] -> String
orMany [] =
  "false"
orMany [term] =
  term
orMany terms =
  "(or " ++ joinWith " " terms ++ ")"

runSolver :: SmtSolver -> String -> IO (Either String SolverAnswer)
runSolver solver script = do
  result <-
    try
      ( readProcessWithExitCode
          (smtSolverCommand solver)
          (smtSolverArguments solver)
          script
      )
  case result of
    Left errorReport ->
      pure (Left (show (errorReport :: IOException)))
    Right (exitCode, stdoutText, stderrText) ->
      case exitCode of
        ExitSuccess ->
          pure (Right (parseSolverAnswer stdoutText stderrText))
        ExitFailure code ->
          pure
            ( Left
                ( "solver exited with "
                    ++ show code
                    ++ ": "
                    ++ trim (stdoutText ++ "\n" ++ stderrText)
                )
            )

parseSolverAnswer :: String -> String -> SolverAnswer
parseSolverAnswer stdoutText stderrText =
  case words stdoutText of
    "sat" : _ ->
      SolverSat
    "unsat" : _ ->
      SolverUnsat
    "unknown" : _ ->
      SolverUnknown
    _ ->
      SolverNoAnswer (trim (stdoutText ++ "\n" ++ stderrText))

resultFromSolver ::
  SmtProposition ->
  SmtSolver ->
  SmtProblem ->
  Either String SolverAnswer ->
  SmtResult
resultFromSolver proposition solver problem solverResult =
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
        , smtResultStatus = statusFromSolverAnswer (smtProblemExpectedResult problem) answer
        , smtResultEvidence =
            SolverEvidence
              ( renderSmtSolver solver
                  ++ " returned "
                  ++ renderSolverAnswer answer
                  ++ "; expected "
                  ++ renderExpectedResult (smtProblemExpectedResult problem)
                  ++ " for pass"
              )
        }

statusFromSolverAnswer :: SolverExpectedResult -> SolverAnswer -> SmtStatus
statusFromSolverAnswer expected answer =
  case (expected, answer) of
    (ExpectUnsatForPass, SolverUnsat) ->
      SmtPassed
    (ExpectUnsatForPass, SolverSat) ->
      SmtFailed
    (ExpectSatForPass, SolverSat) ->
      SmtPassed
    (ExpectSatForPass, SolverUnsat) ->
      SmtFailed
    (_, SolverUnknown) ->
      SmtSkipped
    (_, SolverNoAnswer _) ->
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
      "haskell constraint evidence: no counterexamples"
    HaskellConstraintEvidence errors ->
      joinWith "\n" ("haskell constraint evidence:" : map (("- " ++) . renderConstraintError) errors)
    SolverEvidence message ->
      "solver evidence: " ++ message
    NoSolverEvidence message ->
      "no solver evidence: " ++ message

renderSmtStatus :: SmtStatus -> String
renderSmtStatus SmtPassed =
  "passed"
renderSmtStatus SmtFailed =
  "failed"
renderSmtStatus SmtSkipped =
  "skipped"

renderSmtProposition :: SmtProposition -> String
renderSmtProposition ProveFactClosure =
  "fact closure"
renderSmtProposition ProvePipeInputClosure =
  "pipe input closure"
renderSmtProposition ProveExternalMakeClosure =
  "externalMake closure"
renderSmtProposition ProveNoDependencyCycle =
  "no dependency cycle"
renderSmtProposition ProveNoDuplicateMaker =
  "no duplicate maker"
renderSmtProposition ProveNoDuplicatePipeMaker =
  "no duplicate pipe maker"
renderSmtProposition ProveExternalTakeNotAutoMade =
  "externalTake not auto-made"
renderSmtProposition ProveWaitHasSource =
  "wait has source"

renderSmtSolver :: SmtSolver -> String
renderSmtSolver solver =
  smtSolverName solver ++ " (" ++ smtSolverCommand solver ++ ")"

renderSolverAnswer :: SolverAnswer -> String
renderSolverAnswer SolverSat =
  "sat"
renderSolverAnswer SolverUnsat =
  "unsat"
renderSolverAnswer SolverUnknown =
  "unknown"
renderSolverAnswer (SolverNoAnswer message) =
  "no answer: " ++ message

renderExpectedResult :: SolverExpectedResult -> String
renderExpectedResult ExpectSatForPass =
  "sat"
renderExpectedResult ExpectUnsatForPass =
  "unsat"

indentLines :: Int -> String -> String
indentLines count =
  joinWith "\n" . map (replicate count ' ' ++) . lines

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

pipeTakenFacts :: [ConstraintFact] -> [(RuleId, TypeName, WorkflowFact)]
pipeTakenFacts facts =
  [ (currentRule, currentType, currentFact)
  | PipeTakes currentRule currentType currentFact <- facts
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

dependencyEdges :: [ConstraintFact] -> [(WorkflowFact, WorkflowFact)]
dependencyEdges facts =
  unique
    ( [ (neededFact, madeFact)
      | (currentRule, neededFact) <- takenFacts facts
      , madeFact <- madeFactsForRule facts currentRule
      ]
        ++ [ (neededFact, madeFact)
           | (currentRule, _, neededFact) <- pipeTakenFacts facts
           , madeFact <- madeFactsForRule facts currentRule
           ]
    )

madeFactsForRule :: [ConstraintFact] -> RuleId -> [WorkflowFact]
madeFactsForRule facts currentRule =
  [ currentFact
  | Makes rule madeFact <- facts
  , rule == currentRule
  , let currentFact = madeFact
  ]

allFacts :: [ConstraintFact] -> [WorkflowFact]
allFacts facts =
  unique
    ( requiredFacts facts
        ++ internallyMadeFacts facts
        ++ externalTakeFacts facts
        ++ map snd (takenFacts facts)
        ++ [ currentFact
           | (_, _, currentFact) <- pipeTakenFacts facts
           ]
        ++ map snd (waitedFacts facts)
    )

allTypes :: [ConstraintFact] -> [TypeName]
allTypes facts =
  unique
    ( map snd (pipeNeededTypes facts)
        ++ pipeMadeTypes facts
        ++ [ currentType
           | (_, currentType, _) <- pipeTakenFacts facts
           ]
    )

allSends :: [ConstraintFact] -> [SendName]
allSends facts =
  unique
    ( declaredExternalMakeNames facts
        ++ map snd (usedExternalMakes facts)
        ++ map snd (errorHandlers facts)
    )

sourceSymbol :: WorkflowFact -> String
sourceSymbol currentFact =
  "source_" ++ atom (show currentFact)

requiredSymbol :: WorkflowFact -> String
requiredSymbol currentFact =
  "required_" ++ atom (show currentFact)

externalTakeSymbol :: WorkflowFact -> String
externalTakeSymbol currentFact =
  "external_take_" ++ atom (show currentFact)

internallyMadeSymbol :: WorkflowFact -> String
internallyMadeSymbol currentFact =
  "internal_make_" ++ atom (show currentFact)

pipeSourceSymbol :: TypeName -> String
pipeSourceSymbol currentType =
  "pipe_source_" ++ atom (show currentType)

declaredSendSymbol :: SendName -> String
declaredSendSymbol currentSend =
  "declared_send_" ++ atom (show currentSend)

makerCountSymbol :: WorkflowFact -> String
makerCountSymbol currentFact =
  "maker_count_" ++ atom (show currentFact)

pipeMakerCountSymbol :: TypeName -> String
pipeMakerCountSymbol currentType =
  "pipe_maker_count_" ++ atom (show currentType)

rankSymbol :: WorkflowFact -> String
rankSymbol currentFact =
  "rank_" ++ atom (show currentFact)

atom :: String -> String
atom =
  map sanitize

sanitize :: Char -> Char
sanitize currentChar
  | isAlphaNum currentChar =
      currentChar
  | otherwise =
      '_'

trim :: String -> String
trim =
  reverse . dropWhile isSpaceLike . reverse . dropWhile isSpaceLike

isSpaceLike :: Char -> Bool
isSpaceLike currentChar =
  currentChar == ' ' || currentChar == '\n' || currentChar == '\r' || currentChar == '\t'

unique :: Eq item => [item] -> [item]
unique =
  foldl addUnique []
  where
    addUnique items item
      | item `elem` items = items
      | otherwise = items ++ [item]

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
