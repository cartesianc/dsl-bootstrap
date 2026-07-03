module Main
  ( main
  ) where

import Framework.FixedPoint
  ( RuntimeBackendParityEvidencePayload
  , buildFixedPointReport
  , fixedPointPassed
  , renderFixedPointReport
  , renderFixedPointReportJson
  , renderRuntimeBackendParityEvidencePayload
  , runtimeBackendParityEvidencePayloads
  )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  report <- buildFixedPointReport
  case args of
    ["--json"] ->
      putStrLn (renderFixedPointReportJson report)
    _ -> do
      putStrLn "[witness] runtime backend parity evidence payloads"
      mapM_ putStrLn (concatMap renderPayloadBlock (runtimeBackendParityEvidencePayloads report))
      mapM_ putStrLn (renderFixedPointReport report)
  if fixedPointPassed report
    then pure ()
    else ioError (userError "fixed-point evidence diff failed")

renderPayloadBlock :: RuntimeBackendParityEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderRuntimeBackendParityEvidencePayload payload)
    ++ [""]
