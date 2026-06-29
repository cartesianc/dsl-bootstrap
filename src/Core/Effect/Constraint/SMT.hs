module Core.Effect.Constraint.SMT
  ( SmtBackend (..)
  , SmtEvidence (..)
  , SmtProposition (..)
  , SmtResult (..)
  , SmtStatus (..)
  , defaultSmtPropositions
  , proveMinimalCore
  , proveMinimalCoreWith
  , renderSmtEvidence
  , renderSmtResult
  , renderSmtResults
  , smtPassed
  ) where

import Core.App.Boundary
  ( MinimalCoreReport (..)
  )
import Core.Effect.Constraint
  ( ConstraintError (..)
  , renderConstraintError
  )

data SmtProposition
  = ProveFactClosure
  | ProveExternalMakeClosure
  | ProveImplementationClosure
  | ProveNoDependencyCycle
  | ProveNoDuplicateMaker
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

defaultSmtPropositions :: [SmtProposition]
defaultSmtPropositions =
  [ ProveFactClosure
  , ProveExternalMakeClosure
  , ProveImplementationClosure
  , ProveNoDependencyCycle
  , ProveNoDuplicateMaker
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
    ProveImplementationClosure ->
      case currentError of
        MissingImplementation _ _ -> True
        _ -> False
    ProveNoDependencyCycle ->
      case currentError of
        DependencyCycle _ -> True
        _ -> False
    ProveNoDuplicateMaker ->
      case currentError of
        DuplicateMaker _ _ -> True
        _ -> False
    ProveExternalTakeNotAutoMade ->
      case currentError of
        ExternalTakeAutoMake _ -> True
        _ -> False
    ProveWaitHasSource ->
      case currentError of
        DeadWaitCandidate _ _ -> True
        _ -> False

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
renderSmtProposition ProveExternalMakeClosure =
  "externalMake closure"
renderSmtProposition ProveImplementationClosure =
  "implementation closure"
renderSmtProposition ProveNoDependencyCycle =
  "no dependency cycle"
renderSmtProposition ProveNoDuplicateMaker =
  "no duplicate maker"
renderSmtProposition ProveExternalTakeNotAutoMade =
  "externalTake not auto-made"
renderSmtProposition ProveWaitHasSource =
  "wait has source"

indentLines :: Int -> String -> String
indentLines count =
  joinWith "\n" . map (replicate count ' ' ++) . lines

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
