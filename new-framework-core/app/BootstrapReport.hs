module Main
  ( main
  ) where

import Bootstrap.Report
  ( buildFrameworkCoreReport
  , frameworkCoreReportPassed
  , renderFrameworkCoreReport
  , renderFrameworkCoreReportJson
  )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  report <- buildFrameworkCoreReport
  case args of
    ["--json"] ->
      putStrLn (renderFrameworkCoreReportJson report)
    _ ->
      mapM_ putStrLn (renderFrameworkCoreReport report)
  if frameworkCoreReportPassed report
    then pure ()
    else ioError (userError "[report] framework-core report failed")
