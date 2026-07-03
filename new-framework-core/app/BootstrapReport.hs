module Main
  ( main
  ) where

import Bootstrap.Report
  ( buildFrameworkCoreReport
  , printFrameworkCoreReport
  , renderFrameworkCoreReportJson
  )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["--json"] -> do
      report <- buildFrameworkCoreReport
      putStrLn (renderFrameworkCoreReportJson report)
    _ ->
      printFrameworkCoreReport
