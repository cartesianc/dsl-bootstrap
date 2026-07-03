module Main
  ( main
  ) where

import Framework.Domain
  ( DomainReport (..)
  , DomainSemanticEvidence (..)
  , buildDomainReport
  , domainSemanticEvidencePassed
  )
import Framework.TrustBase
  ( RuntimeDiagnosisEvidencePayload (..)
  , renderRuntimeDiagnosisEvidencePayload
  , renderRuntimeDiagnosisEvidencePayloadsJson
  , runtimeDiagnosisEvidenceClaimNames
  , runtimeDiagnosisEvidencePayloadPassed
  )
import Domain.SemanticEvidence
  ( runtimeDiagnosisEvidencePayloads )
import SelfDomainApp
  ( domainAppDomain )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  report <- buildDomainReport domainAppDomain
  payloads <- runtimeDiagnosisEvidencePayloads
  let missing =
        [ name
        | name <- expectedEvidence
        , not (evidencePresent name report && payloadPresent name payloads)
        ]
      failed =
        [ evidence
        | evidence <- domainReportSemanticEvidence report
        , domainSemanticEvidenceName evidence `elem` expectedEvidence
        , not (domainSemanticEvidencePassed evidence)
        ]
      failedPayloads =
        [ payload
        | payload <- payloads
        , runtimeDiagnosisEvidenceClaim payload `elem` expectedEvidence
        , not (runtimeDiagnosisEvidencePayloadPassed payload)
        ]
  case (missing, failed, failedPayloads) of
    ([], [], []) -> do
      case args of
        ["--json"] ->
          putStrLn (renderRuntimeDiagnosisEvidencePayloadsJson payloads)
        _ -> do
          putStrLn "[witness] runtime diagnosis evidence payloads"
          mapM_ putStrLn (concatMap renderPayloadBlock payloads)
          putStrLn ("[witness] ok runtime diagnosis evidence " ++ show (length expectedEvidence) ++ " payload claims")
    _ ->
      ioError
        ( userError
            ( "[witness] runtime diagnosis evidence failed\n"
                ++ "missing: "
                ++ show missing
                ++ "\nfailed: "
                ++ show (map domainSemanticEvidenceName failed)
                ++ "\nfailed payloads: "
                ++ show (map runtimeDiagnosisEvidenceClaim failedPayloads)
            )
        )

renderPayloadBlock :: RuntimeDiagnosisEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderRuntimeDiagnosisEvidencePayload payload)
    ++ [""]

expectedEvidence :: [String]
expectedEvidence =
  runtimeDiagnosisEvidenceClaimNames

evidencePresent :: String -> DomainReport -> Bool
evidencePresent name report =
  any
    (\evidence -> domainSemanticEvidenceName evidence == name)
    (domainReportSemanticEvidence report)

payloadPresent :: String -> [RuntimeDiagnosisEvidencePayload] -> Bool
payloadPresent name payloads =
  any
    (\payload -> runtimeDiagnosisEvidenceClaim payload == name)
    payloads
