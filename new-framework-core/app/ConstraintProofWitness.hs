module Main
  ( main
  ) where

import Bootstrap.Blueprint
  ( coreBootstrapBlueprint )
import Bootstrap.Effects
  ( coreBootstrapEffects )
import Framework.Background.ConstraintProof
  ( SmtResult (..)
  , SmtSolver
  , SmtStatus (..)
  , availableSmtSolver
  , constraintsFromAppPlan
  , proveMinimalCoreWithAvailableSolver
  , renderSmtSolver
  )
import Framework.Domain
  ( DomainReport (..)
  , DomainSemanticEvidence (..)
  , buildDomainReport
  , domainSemanticEvidencePassed
  , frameworkCoreDomain
  )

main :: IO ()
main = do
  report <- buildDomainReport frameworkCoreDomain
  let missing =
        [ name
        | name <- expectedEvidence
        , not (evidencePresent name report)
        ]
      failed =
        [ evidence
        | evidence <- domainReportSemanticEvidence report
        , domainSemanticEvidenceName evidence `elem` expectedEvidence
        , not (domainSemanticEvidencePassed evidence)
        ]
  (maybeSolver, solverResults) <- optionalSolverResults
  let solverFailed =
        [ result
        | result <- solverResults
        , smtResultStatus result == SmtFailed
        ]
      solverSkippedWithAvailableSolver =
        case maybeSolver of
          Just _ ->
            [ result
            | result <- solverResults
            , smtResultStatus result == SmtSkipped
            ]
          Nothing ->
            []
  case (missing, failed, solverFailed, solverSkippedWithAvailableSolver) of
    ([], [], [], []) ->
      putStrLn
        ( "[witness] ok constraint proof evidence "
            ++ show (length expectedEvidence)
            ++ " claims"
            ++ solverSuffix maybeSolver
        )
    _ ->
      ioError
        ( userError
            ( "[witness] constraint proof evidence failed\n"
                ++ "missing: "
                ++ show missing
                ++ "\nfailed: "
                ++ show (map domainSemanticEvidenceName failed)
                ++ "\nsolver failed: "
                ++ show solverFailed
                ++ "\nsolver skipped with available solver: "
                ++ show solverSkippedWithAvailableSolver
            )
        )

expectedEvidence :: [String]
expectedEvidence =
  [ "constraint-ir-built"
  , "constraint-proof-passed"
  , "constraint-negative-check"
  ]

evidencePresent :: String -> DomainReport -> Bool
evidencePresent name report =
  any
    (\evidence -> domainSemanticEvidenceName evidence == name)
    (domainReportSemanticEvidence report)

optionalSolverResults :: IO (Maybe SmtSolver, [SmtResult])
optionalSolverResults = do
  maybeSolver <- availableSmtSolver
  case constraintsFromAppPlan coreBootstrapBlueprint coreBootstrapEffects of
    Left _ ->
      pure (maybeSolver, [])
    Right constraints ->
      (,) maybeSolver <$> proveMinimalCoreWithAvailableSolver constraints

solverSuffix :: Maybe SmtSolver -> String
solverSuffix maybeSolver =
  case maybeSolver of
    Just solver ->
      "; external solver " ++ renderSmtSolver solver
    Nothing ->
      "; external solver not found"
