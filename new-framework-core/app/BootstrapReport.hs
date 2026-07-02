module Main
  ( main
  ) where

import Bootstrap.Report
  ( printFrameworkCoreReport )

main :: IO ()
main =
  printFrameworkCoreReport
