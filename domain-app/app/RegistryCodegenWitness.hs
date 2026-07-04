module Main
  ( main
  ) where

import Framework.Domain
  ( DomainReport (..)
  , DomainSemanticEvidence (..)
  , DomainSemanticEvidencePayload (..)
  , buildDomainReport
  , domainSemanticEvidencePassed
  )
import Framework.RegistryCodegen
  ( registryCodegenEvidenceClaimNames
  , renderRegistryCodegenEvidencePayload
  , renderRegistryCodegenEvidencePayloadsJson
  )
import SelfDomainApp
  ( domainAppDomain )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  report <- buildDomainReport domainAppDomain
  let evidence =
        registryCodegenEvidence report
      payloads =
        registryCodegenPayloads evidence
      missing =
        missingRegistryCodegenEvidence report
      failed =
        failedRegistryCodegenEvidence evidence
      missingPayloads =
        missingRegistryCodegenPayloads evidence
      failedPayloads =
        failedRegistryCodegenPayloads payloads
  case args of
    ["--json"] -> do
      putStrLn
        ( renderRegistryCodegenEvidencePayloadsJson
            payloads
            missing
            (map domainSemanticEvidenceName failed)
            missingPayloads
            (map domainSemanticEvidencePayloadClaim failedPayloads)
        )
      failWhenRegistryCodegenEvidenceFailed missing failed missingPayloads failedPayloads
    _ -> do
      putStrLn "[witness] registry codegen evidence payloads"
      mapM_ putStrLn (concatMap renderPayloadBlock payloads)
      putStrLn
        ( "[witness] "
            ++ statusText missing failed missingPayloads failedPayloads
            ++ " registry codegen evidence "
            ++ show (length registryCodegenEvidenceClaimNames)
            ++ " payload claims"
        )
      failWhenRegistryCodegenEvidenceFailed missing failed missingPayloads failedPayloads

registryCodegenEvidence :: DomainReport -> [DomainSemanticEvidence]
registryCodegenEvidence report =
  [ evidence
  | evidence <- domainReportSemanticEvidence report
  , domainSemanticEvidenceName evidence `elem` registryCodegenEvidenceClaimNames
  ]

registryCodegenPayloads :: [DomainSemanticEvidence] -> [DomainSemanticEvidencePayload]
registryCodegenPayloads evidence =
  [ payload
  | currentEvidence <- evidence
  , Just payload <- [domainSemanticEvidencePayload currentEvidence]
  ]

missingRegistryCodegenEvidence :: DomainReport -> [String]
missingRegistryCodegenEvidence report =
  [ name
  | name <- registryCodegenEvidenceClaimNames
  , not (evidencePresent name report)
  ]

failedRegistryCodegenEvidence :: [DomainSemanticEvidence] -> [DomainSemanticEvidence]
failedRegistryCodegenEvidence evidence =
  [ currentEvidence
  | currentEvidence <- evidence
  , not (domainSemanticEvidencePassed currentEvidence)
  ]

missingRegistryCodegenPayloads :: [DomainSemanticEvidence] -> [String]
missingRegistryCodegenPayloads evidence =
  [ domainSemanticEvidenceName currentEvidence
  | currentEvidence <- evidence
  , domainSemanticEvidencePayload currentEvidence == Nothing
  ]

failedRegistryCodegenPayloads :: [DomainSemanticEvidencePayload] -> [DomainSemanticEvidencePayload]
failedRegistryCodegenPayloads payloads =
  [ payload
  | payload <- payloads
  , domainSemanticEvidencePayloadStatus payload /= "passed"
  ]

evidencePresent :: String -> DomainReport -> Bool
evidencePresent name report =
  any
    (\evidence -> domainSemanticEvidenceName evidence == name)
    (domainReportSemanticEvidence report)

renderPayloadBlock :: DomainSemanticEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderRegistryCodegenEvidencePayload payload)
    ++ [""]

failWhenRegistryCodegenEvidenceFailed :: [String] -> [DomainSemanticEvidence] -> [String] -> [DomainSemanticEvidencePayload] -> IO ()
failWhenRegistryCodegenEvidenceFailed [] [] [] [] =
  pure ()
failWhenRegistryCodegenEvidenceFailed missing failed missingPayloads failedPayloads =
  ioError
    ( userError
        ( "[witness] registry codegen evidence failed\n"
            ++ "missing: "
            ++ show missing
            ++ "\nfailed: "
            ++ show (map domainSemanticEvidenceName failed)
            ++ "\nmissing payloads: "
            ++ show missingPayloads
            ++ "\nfailed payloads: "
            ++ show (map domainSemanticEvidencePayloadClaim failedPayloads)
        )
    )

statusText :: [String] -> [DomainSemanticEvidence] -> [String] -> [DomainSemanticEvidencePayload] -> String
statusText [] [] [] [] =
  "ok"
statusText _ _ _ _ =
  "failed"
