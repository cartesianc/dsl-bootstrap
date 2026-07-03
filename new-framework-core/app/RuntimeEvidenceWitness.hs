module Main
  ( main
  ) where

import Bootstrap.Report
  ( buildFrameworkCoreReport )
import Framework.Runtime.Evidence
  ( RuntimeEvidencePayload
  , renderRuntimeEvidencePayload
  , renderRuntimeEvidencePayloadsJson
  , runtimeEvidencePayloadPassed
  , runtimeEvidencePayloads
  )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  report <- buildFrameworkCoreReport
  let payloads =
        runtimeEvidencePayloads report
      failedPayloads =
        filter (not . runtimeEvidencePayloadPassed) payloads
  case args of
    ["--json"] ->
      putStrLn (renderRuntimeEvidencePayloadsJson payloads)
    _ -> do
      putStrLn "[witness] runtime evidence payloads"
      mapM_ putStrLn (concatMap renderPayloadBlock payloads)
      putStrLn
        ( "[witness] "
            ++ statusText payloads
            ++ " runtime evidence "
            ++ show (length payloads)
            ++ " payload claims"
        )
  case failedPayloads of
    [] ->
      pure ()
    _ ->
      ioError
        ( userError
            ( "[witness] runtime evidence failed\n"
                ++ unlines (concatMap renderPayloadBlock failedPayloads)
            )
        )

renderPayloadBlock :: RuntimeEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderRuntimeEvidencePayload payload)
    ++ [""]

statusText :: [RuntimeEvidencePayload] -> String
statusText payloads =
  if all runtimeEvidencePayloadPassed payloads
    then "ok"
    else "failed"
