module Main
  ( main
  ) where

import Bootstrap.Blueprint
  ( coreBootstrapBlueprint )
import Bootstrap.Effects
  ( coreBootstrapEffects )
import Framework.Background.ConstraintProof
  ( ConstraintProofEvidencePayload
  , SmtResult (..)
  , SmtMode (..)
  , SmtSolver
  , SmtStatus (..)
  , availableSmtSolver
  , constraintProofClaimManifestPayload
  , constraintProofDomainClaimNames
  , constraintProofEvidence
  , constraintProofEvidenceClaimNames
  , constraintProofEvidencePayloadPassed
  , constraintsFromAppPlan
  , parseSmtMode
  , proveMinimalCoreWithMode
  , renderConstraintProofEvidencePayload
  , renderConstraintProofEvidencePayloadsJson
  , renderSmtMode
  , renderSmtResult
  , renderSmtSolver
  , smtModeFromEnvironment
  )
import Framework.Domain
  ( DomainReport (..)
  , DomainSemanticEvidence (..)
  , DomainSemanticEvidencePayload (..)
  , buildDomainReport
  , domainSemanticEvidencePassed
  , frameworkCoreDomain
  )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  mode <- selectedSmtMode args
  report <- buildDomainReport frameworkCoreDomain
  (maybeSolver, solverResults) <- solverResultsForMode mode
  let domainPayloads =
        map (`domainEvidencePayload` report) constraintProofDomainClaimNames
      smtPayload =
        smtResultsPayload mode maybeSolver solverResults
      corePayloads =
        domainPayloads ++ [smtPayload]
      payloads =
        corePayloads ++ [constraintProofClaimManifestPayload corePayloads]
      failedPayloads =
        filter (not . constraintProofEvidencePayloadPassed) payloads
  case args of
    _ | "--json" `elem` args ->
      putStrLn (renderConstraintProofEvidencePayloadsJson payloads)
    _ | null failedPayloads ->
      putStrLn
        ( "[witness] ok constraint proof evidence "
            ++ show (length constraintProofEvidenceClaimNames)
            ++ " claims"
            ++ solverSuffix mode maybeSolver
        )
    _ ->
      ioError
        ( userError
            ( "[witness] constraint proof evidence failed\n"
                ++ unlines (concatMap renderPayloadBlock failedPayloads)
            )
        )
  failWhenEvidenceFailed failedPayloads

domainEvidencePayload :: String -> DomainReport -> ConstraintProofEvidencePayload
domainEvidencePayload name report =
  case evidenceFor name report of
    Nothing ->
      constraintProofEvidence
        name
        False
        "domain report contains constraint proof semantic evidence"
        "missing domain semantic evidence"
        "ConstraintProofDomainEvidenceArtifact"
    Just evidence ->
      case domainSemanticEvidencePayload evidence of
        Just payload ->
          constraintProofEvidence
            (domainSemanticEvidencePayloadClaim payload)
            (domainSemanticEvidencePayloadStatus payload == "passed")
            (domainSemanticEvidencePayloadExpected payload)
            (domainSemanticEvidencePayloadObserved payload)
            (domainSemanticEvidencePayloadArtifact payload)
        Nothing ->
          constraintProofEvidence
            name
            (domainSemanticEvidencePassed evidence)
            "domain semantic evidence has structured payload"
            ("details: " ++ show (domainSemanticEvidenceDetails evidence))
            "ConstraintProofDomainEvidencePayloadArtifact"

evidenceFor :: String -> DomainReport -> Maybe DomainSemanticEvidence
evidenceFor name report =
  firstMatching (domainReportSemanticEvidence report)
  where
    firstMatching [] =
      Nothing
    firstMatching (evidence : rest)
      | domainSemanticEvidenceName evidence == name =
          Just evidence
      | otherwise =
          firstMatching rest

smtResultsPayload :: SmtMode -> Maybe SmtSolver -> [SmtResult] -> ConstraintProofEvidencePayload
smtResultsPayload mode maybeSolver solverResults =
  constraintProofEvidence
    "constraint-proof-smt-results"
    passed
    "SMT results respect selected constraint proof mode"
    observed
    "ConstraintProofSmtResultsArtifact"
  where
    solverFailed =
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
    passed =
      null solverFailed && null solverSkippedInRequiredMode
    observed =
      "mode "
        ++ renderSmtMode mode
        ++ solverObservedText mode maybeSolver
        ++ "; results "
        ++ show (length solverResults)
        ++ "; failed "
        ++ show (map renderSmtResult solverFailed)
        ++ "; skipped in required mode "
        ++ show (map renderSmtResult solverSkippedInRequiredMode)

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

selectedSmtMode :: [String] -> IO SmtMode
selectedSmtMode args = do
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

solverObservedText :: SmtMode -> Maybe SmtSolver -> String
solverObservedText mode maybeSolver =
  case (mode, maybeSolver) of
    (SmtDisabled, _) ->
      "; external solver disabled"
    (_, Just solver) ->
      "; external solver " ++ renderSmtSolver solver
    (_, Nothing) ->
      "; external solver not found"

renderPayloadBlock :: ConstraintProofEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderConstraintProofEvidencePayload payload)
    ++ [""]

failWhenEvidenceFailed :: [ConstraintProofEvidencePayload] -> IO ()
failWhenEvidenceFailed [] =
  pure ()
failWhenEvidenceFailed failedPayloads =
  ioError
    ( userError
        ( "[witness] constraint proof evidence failed\n"
            ++ unlines (concatMap renderPayloadBlock failedPayloads)
        )
    )
