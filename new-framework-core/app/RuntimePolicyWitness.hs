module Main
  ( main
  ) where

import Bootstrap.Report
  ( buildFrameworkCoreReport )
import Framework.Runtime.Policy
  ( RuntimePolicyEvidencePayload
  , renderRuntimePolicyEvidencePayload
  , renderRuntimePolicyEvidencePayloadsJson
  , runtimePolicyEvidencePayloadPassed
  , runtimePolicyEvidencePayloads
  )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  report <- buildFrameworkCoreReport
  let payloads =
        runtimePolicyEvidencePayloads report
      failedPayloads =
        filter (not . runtimePolicyEvidencePayloadPassed) payloads
  case args of
    ["--json"] ->
      putStrLn (renderRuntimePolicyEvidencePayloadsJson payloads)
    _ -> do
      putStrLn "[witness] runtime policy evidence payloads"
      mapM_ putStrLn (concatMap renderPayloadBlock payloads)
      putStrLn
        ( "[witness] "
            ++ statusText payloads
            ++ " runtime policy evidence "
            ++ show (length payloads)
            ++ " payload claims"
        )
  case failedPayloads of
    [] ->
      pure ()
    _ ->
      ioError
        ( userError
            ( "[witness] runtime policy evidence failed\n"
                ++ unlines (concatMap renderPayloadBlock failedPayloads)
            )
        )

renderPayloadBlock :: RuntimePolicyEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderRuntimePolicyEvidencePayload payload)
    ++ [""]

statusText :: [RuntimePolicyEvidencePayload] -> String
statusText payloads =
  if all runtimePolicyEvidencePayloadPassed payloads
    then "ok"
    else "failed"
