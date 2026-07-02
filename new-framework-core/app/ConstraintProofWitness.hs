module Main
  ( main
  ) where

import Bootstrap.Blueprint
  ( coreBootstrapBlueprint )
import Bootstrap.Effects
  ( coreBootstrapEffects )
import Framework.Background.ConstraintProof
  ( SmtResult (..)
  , SmtStatus (..)
  , constraintsFromAppPlan
  , proveMinimalCoreWithAvailableSolver
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
  solverResults <- optionalSolverResults
  let solverFailed =
        [ result
        | result <- solverResults
        , smtResultStatus result == SmtFailed
        ]
  case (missing, failed, solverFailed) of
    ([], [], []) ->
      putStrLn ("[witness] ok constraint proof evidence " ++ show (length expectedEvidence) ++ " claims")
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

optionalSolverResults :: IO [SmtResult]
optionalSolverResults =
  case constraintsFromAppPlan coreBootstrapBlueprint coreBootstrapEffects of
    Left _ ->
      pure []
    Right constraints ->
      proveMinimalCoreWithAvailableSolver constraints
