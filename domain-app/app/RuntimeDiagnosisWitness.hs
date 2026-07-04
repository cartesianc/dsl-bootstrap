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
  , RuntimeDiagnosisEvidenceStatus (..)
  , renderRuntimeDiagnosisEvidencePayload
  , renderRuntimeDiagnosisEvidencePayloadsJson
  , runtimeDiagnosisCoreClaimNames
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
  corePayloads <- runtimeDiagnosisEvidencePayloads
  let payloads =
        corePayloads ++ [runtimeDiagnosisClaimManifestPayload corePayloads]
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
  runtimeDiagnosisCoreClaimNames

runtimeDiagnosisClaimManifestPayload :: [RuntimeDiagnosisEvidencePayload] -> RuntimeDiagnosisEvidencePayload
runtimeDiagnosisClaimManifestPayload payloads =
  RuntimeDiagnosisEvidencePayload
    { runtimeDiagnosisEvidenceClaim = "runtime-diagnosis-claim-manifest"
    , runtimeDiagnosisEvidenceStatus =
        if manifestSynced
          then RuntimeDiagnosisEvidencePassed
          else RuntimeDiagnosisEvidenceFailed
    , runtimeDiagnosisEvidenceExpected =
        "runtime diagnosis witness claims match exported claim manifest"
    , runtimeDiagnosisEvidenceObserved =
        if manifestSynced
          then "claim manifest synced: " ++ show (length actualCoreClaimNames) ++ " core claims"
          else "expected " ++ show runtimeDiagnosisEvidenceClaimNames ++ "; actual " ++ show actualEvidenceClaimNames
    , runtimeDiagnosisEvidenceArtifact = "RuntimeDiagnosisClaimManifestArtifact"
    }
  where
    actualCoreClaimNames =
      map runtimeDiagnosisEvidenceClaim payloads
    actualEvidenceClaimNames =
      actualCoreClaimNames ++ ["runtime-diagnosis-claim-manifest"]
    manifestSynced =
      actualCoreClaimNames == runtimeDiagnosisCoreClaimNames
        && actualEvidenceClaimNames == runtimeDiagnosisEvidenceClaimNames

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
