module Main
  ( main
  ) where

import Framework.FixedPoint
  ( RuntimeBackendParityEvidencePayload
  , buildFixedPointReport
  , fixedPointPassed
  , renderFixedPointReport
  , renderRuntimeBackendParityEvidencePayload
  , runtimeBackendParityEvidencePayloads
  )

main :: IO ()
main = do
  report <- buildFixedPointReport
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
