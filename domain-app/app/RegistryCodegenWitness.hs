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
            ++ show (length expectedEvidence)
            ++ " payload claims"
        )
      failWhenRegistryCodegenEvidenceFailed missing failed missingPayloads failedPayloads

expectedEvidence :: [String]
expectedEvidence =
  [ "registry-codegen-plugins"
  , "registry-codegen-effects"
  ]

registryCodegenEvidence :: DomainReport -> [DomainSemanticEvidence]
registryCodegenEvidence report =
  [ evidence
  | evidence <- domainReportSemanticEvidence report
  , domainSemanticEvidenceName evidence `elem` expectedEvidence
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
  | name <- expectedEvidence
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

renderRegistryCodegenEvidencePayload :: DomainSemanticEvidencePayload -> [String]
renderRegistryCodegenEvidencePayload payload =
  [ "claim: " ++ domainSemanticEvidencePayloadClaim payload
  , "status: " ++ domainSemanticEvidencePayloadStatus payload
  , "expected: " ++ domainSemanticEvidencePayloadExpected payload
  , "observed: " ++ domainSemanticEvidencePayloadObserved payload
  , "artifact: " ++ domainSemanticEvidencePayloadArtifact payload
  ]

renderRegistryCodegenEvidencePayloadsJson :: [DomainSemanticEvidencePayload] -> [String] -> [String] -> [String] -> [String] -> String
renderRegistryCodegenEvidencePayloadsJson payloads missing failed missingPayloads failedPayloads =
  jsonObject
    [ jsonField "schema" (jsonString "registry-codegen-evidence.v1")
    , jsonField "status" (jsonString (jsonStatus missing failed missingPayloads failedPayloads))
    , jsonField "payloads" (jsonArray (map registryCodegenEvidencePayloadJson payloads))
    , jsonField "missing" (jsonStringArray missing)
    , jsonField "failed" (jsonStringArray failed)
    , jsonField "missingPayloads" (jsonStringArray missingPayloads)
    , jsonField "failedPayloads" (jsonStringArray failedPayloads)
    ]

registryCodegenEvidencePayloadJson :: DomainSemanticEvidencePayload -> String
registryCodegenEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (domainSemanticEvidencePayloadClaim payload))
    , jsonField "status" (jsonString (domainSemanticEvidencePayloadStatus payload))
    , jsonField "expected" (jsonString (domainSemanticEvidencePayloadExpected payload))
    , jsonField "observed" (jsonString (domainSemanticEvidencePayloadObserved payload))
    , jsonField "artifact" (jsonString (domainSemanticEvidencePayloadArtifact payload))
    ]

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

jsonStatus :: [String] -> [String] -> [String] -> [String] -> String
jsonStatus [] [] [] [] =
  "passed"
jsonStatus _ _ _ _ =
  "failed"

jsonObject :: [String] -> String
jsonObject fields =
  "{" ++ joinWith "," fields ++ "}"

jsonField :: String -> String -> String
jsonField name value =
  jsonString name ++ ":" ++ value

jsonArray :: [String] -> String
jsonArray values =
  "[" ++ joinWith "," values ++ "]"

jsonStringArray :: [String] -> String
jsonStringArray =
  jsonArray . map jsonString

jsonString :: String -> String
jsonString value =
  "\"" ++ concatMap jsonChar value ++ "\""

jsonChar :: Char -> String
jsonChar currentChar =
  case currentChar of
    '"' ->
      "\\\""
    '\\' ->
      "\\\\"
    '\n' ->
      "\\n"
    '\r' ->
      "\\r"
    '\t' ->
      "\\t"
    _ ->
      [currentChar]

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
