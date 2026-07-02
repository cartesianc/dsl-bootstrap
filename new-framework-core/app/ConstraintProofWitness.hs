module Main
  ( main
  ) where

import Bootstrap.Blueprint
  ( coreBootstrapBlueprint )
import Bootstrap.Effects
  ( coreBootstrapEffects )
import Framework.Background.ConstraintProof
  ( SmtResult (..)
  , SmtMode (..)
  , SmtSolver
  , SmtStatus (..)
  , availableSmtSolver
  , constraintsFromAppPlan
  , parseSmtMode
  , proveMinimalCoreWithMode
  , renderSmtMode
  , renderSmtSolver
  , smtModeFromEnvironment
  )
import Framework.Domain
  ( DomainReport (..)
  , DomainSemanticEvidence (..)
  , buildDomainReport
  , domainSemanticEvidencePassed
  , frameworkCoreDomain
  )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  mode <- selectedSmtMode
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
  (maybeSolver, solverResults) <- solverResultsForMode mode
  let solverFailed =
        [ result
        | result <- solverResults
        , smtResultStatus result == SmtFailed
        ]
      solverSkippedInRequiredMode =
        case mode of
          SmtRequired ->
            [ result
            | result <- solverResults
            , smtResultStatus result == SmtSkipped
            ]
          _ ->
            []
  case (missing, failed, solverFailed, solverSkippedInRequiredMode) of
    ([], [], [], []) ->
      putStrLn
        ( "[witness] ok constraint proof evidence "
            ++ show (length expectedEvidence)
            ++ " claims"
            ++ solverSuffix mode maybeSolver
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
                ++ "\nsolver skipped in required mode: "
                ++ show solverSkippedInRequiredMode
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

solverResultsForMode :: SmtMode -> IO (Maybe SmtSolver, [SmtResult])
solverResultsForMode mode = do
  maybeSolver <-
    case mode of
      SmtDisabled ->
        pure Nothing
      _ ->
        availableSmtSolver
  case constraintsFromAppPlan coreBootstrapBlueprint coreBootstrapEffects of
    Left _ ->
      pure (maybeSolver, [])
    Right constraints ->
      (,) maybeSolver <$> proveMinimalCoreWithMode mode constraints

selectedSmtMode :: IO SmtMode
selectedSmtMode = do
  args <- getArgs
  case cliSmtMode args of
    Left message ->
      ioError (userError message)
    Right (Just mode) ->
      pure mode
    Right Nothing -> do
      envMode <- smtModeFromEnvironment
      case envMode of
        Right mode ->
          pure mode
        Left message ->
          ioError (userError message)

cliSmtMode :: [String] -> Either String (Maybe SmtMode)
cliSmtMode [] =
  Right Nothing
cliSmtMode (arg : rest) =
  case smtEqualsValue arg of
    Just modeText ->
      Just <$> parseSmtMode modeText
    Nothing ->
      if arg == "--smt"
        then case rest of
          modeText : _ ->
            Just <$> parseSmtMode modeText
          [] ->
            Left "missing value after --smt; expected off, auto, or required"
        else cliSmtMode rest

smtEqualsValue :: String -> Maybe String
smtEqualsValue arg =
  let prefix =
        "--smt="
   in if take (length prefix) arg == prefix
        then Just (drop (length prefix) arg)
        else Nothing

solverSuffix :: SmtMode -> Maybe SmtSolver -> String
solverSuffix mode maybeSolver =
  "; SMT mode " ++ renderSmtMode mode ++ solverText
  where
    solverText =
      case (mode, maybeSolver) of
        (SmtDisabled, _) ->
          "; external solver disabled"
        (_, Just solver) ->
          "; external solver " ++ renderSmtSolver solver
        (_, Nothing) ->
          "; external solver not found"
