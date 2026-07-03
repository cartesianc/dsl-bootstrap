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
  , runtimeDiagnosisEvidencePayloadPassed
  )
import Domain.SemanticEvidence
  ( runtimeDiagnosisEvidencePayloads )
import SelfDomainApp
  ( domainAppDomain )

main :: IO ()
main = do
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
  [ "runtime-diagnosis-error-handler"
  , "runtime-diagnosis-retry-probe"
  , "runtime-diagnosis-non-idempotent-blocker"
  ]

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
