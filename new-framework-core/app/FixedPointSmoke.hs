module Main
  ( main
  ) where

import Framework.FixedPoint
  ( FixedPointDiffEvidencePayload
  , RuntimeBackendParityEvidencePayload
  , buildFixedPointReport
  , fixedPointDiffEvidencePayloadPassed
  , fixedPointPassed
  , fixedPointDiffEvidencePayloads
  , renderFixedPointDiffEvidencePayload
  , renderFixedPointReport
  , renderFixedPointReportJson
  , renderRuntimeBackendParityEvidencePayload
  , runtimeBackendParityEvidencePayloadPassed
  , runtimeBackendParityEvidencePayloads
  )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  report <- buildFixedPointReport
  let diffPayloads =
        fixedPointDiffEvidencePayloads report
      backendPayloads =
        runtimeBackendParityEvidencePayloads report
  case args of
    ["--json"] ->
      putStrLn (renderFixedPointReportJson report)
    _ -> do
      putStrLn "[witness] fixed-point diff evidence payloads"
      mapM_ putStrLn (concatMap renderDiffPayloadBlock diffPayloads)
      putStrLn
        ( renderPayloadSummary
            "fixed-point diff evidence"
            fixedPointDiffEvidencePayloadPassed
            diffPayloads
        )
      putStrLn "[witness] runtime backend parity evidence payloads"
      mapM_ putStrLn (concatMap renderBackendPayloadBlock backendPayloads)
      putStrLn
        ( renderPayloadSummary
            "runtime backend parity evidence"
            runtimeBackendParityEvidencePayloadPassed
            backendPayloads
        )
      mapM_ putStrLn (renderFixedPointReport report)
  if fixedPointPassed report
    then pure ()
    else ioError (userError "fixed-point evidence diff failed")

renderDiffPayloadBlock :: FixedPointDiffEvidencePayload -> [String]
renderDiffPayloadBlock payload =
  map ("  " ++) (renderFixedPointDiffEvidencePayload payload)
    ++ [""]

renderBackendPayloadBlock :: RuntimeBackendParityEvidencePayload -> [String]
renderBackendPayloadBlock payload =
  map ("  " ++) (renderRuntimeBackendParityEvidencePayload payload)
    ++ [""]

renderPayloadSummary :: String -> (payload -> Bool) -> [payload] -> String
renderPayloadSummary label passed payloads =
  "[witness] "
    ++ statusText
    ++ " "
    ++ label
    ++ " "
    ++ show (length payloads)
    ++ " payload claims"
  where
    statusText =
      if all passed payloads
        then "ok"
        else "failed"
