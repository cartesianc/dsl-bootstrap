module Main
  ( main
  ) where

import Framework.TrustBase
  ( buildCoreSelfInterpretReport
  , coreSelfInterpretReportPassed
  , renderCoreSelfInterpretReport
  , renderCoreSelfInterpretReportJson
  )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  report <- buildCoreSelfInterpretReport
  case args of
    ["--json"] ->
      putStrLn (renderCoreSelfInterpretReportJson report)
    _ ->
      mapM_ putStrLn (renderCoreSelfInterpretReport report)
  if coreSelfInterpretReportPassed report
    then pure ()
    else ioError (userError "core self-interpret report failed")
