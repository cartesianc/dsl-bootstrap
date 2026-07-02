module Main
  ( main
  ) where

import Bootstrap.Blueprint
  ( coreBootstrapBlueprint )
import Bootstrap.Effects
  ( coreBootstrapEffects )
import Framework.Background.ConstraintProof
  ( ConstraintError (..)
  , ConstraintFact (..)
  , SmtResult (..)
  , SmtStatus (..)
  , checkConstraintFacts
  , constraintsFromAppPlan
  , proveMinimalCore
  , proveMinimalCoreWithAvailableSolver
  , smtPassed
  )
import Framework.Workflow
  ( WorkflowFact (..) )

main :: IO ()
main = do
  constraints <-
    case constraintsFromAppPlan coreBootstrapBlueprint coreBootstrapEffects of
      Left message ->
        ioError (userError ("[smoke] failed constraint extraction: " ++ message))
      Right currentConstraints ->
        pure currentConstraints
  let errors =
        checkConstraintFacts constraints
      proofResults =
        proveMinimalCore constraints
      missingFact =
        WorkflowFact "MissingConstraintSmokeFact"
      badErrors =
        checkConstraintFacts [RequiresFact missingFact]
  if not (null errors)
    then ioError (userError ("[smoke] failed constraint check: " ++ show errors))
    else
      if not (smtPassed proofResults)
        then ioError (userError ("[smoke] failed pure SMT proof: " ++ show proofResults))
        else
          if MissingFactSource missingFact `notElem` badErrors
            then ioError (userError ("[smoke] failed negative constraint check: " ++ show badErrors))
            else do
              solverResults <- proveMinimalCoreWithAvailableSolver constraints
              if any ((== SmtFailed) . smtResultStatus) solverResults
                then ioError (userError ("[smoke] failed optional solver proof: " ++ show solverResults))
                else putStrLn ("[smoke] ok constraint proof " ++ show (length proofResults) ++ " propositions")
