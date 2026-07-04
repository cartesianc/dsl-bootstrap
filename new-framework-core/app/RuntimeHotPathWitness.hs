module Main
  ( main
  ) where

import Framework.Runtime.HotPath
  ( RuntimeHotPathEvidencePayload
  , renderRuntimeHotPathEvidencePayload
  , renderRuntimeHotPathEvidencePayloadsJson
  , runtimeHotPathEvidencePayloadPassed
  , runtimeHotPathEvidencePayloads
  )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  payloads <- runtimeHotPathEvidencePayloads
  let failedPayloads =
        filter (not . runtimeHotPathEvidencePayloadPassed) payloads
  case args of
    ["--json"] ->
      putStrLn (renderRuntimeHotPathEvidencePayloadsJson payloads)
    _ -> do
      putStrLn "[witness] runtime hot-path evidence payloads"
      mapM_ putStrLn (concatMap renderPayloadBlock payloads)
      putStrLn
        ( "[witness] "
            ++ statusText payloads
            ++ " runtime hot-path evidence "
            ++ show (length payloads)
            ++ " payload claims"
        )
  case failedPayloads of
    [] ->
      pure ()
    _ ->
      ioError
        ( userError
            ( "[witness] runtime hot-path evidence failed\n"
                ++ unlines (concatMap renderPayloadBlock failedPayloads)
            )
        )

renderPayloadBlock :: RuntimeHotPathEvidencePayload -> [String]
renderPayloadBlock payload =
  map ("  " ++) (renderRuntimeHotPathEvidencePayload payload)
    ++ [""]

statusText :: [RuntimeHotPathEvidencePayload] -> String
statusText payloads =
  if all runtimeHotPathEvidencePayloadPassed payloads
    then "ok"
    else "failed"
