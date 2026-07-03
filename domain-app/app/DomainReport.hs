module Main
  ( main
  ) where

import Framework.Domain
  ( buildDomainReport
  , renderDomainReport
  , renderDomainReportJson
  )
import SelfDomainApp
  ( domainAppDomain )
import System.Environment
  ( getArgs )

main :: IO ()
main = do
  args <- getArgs
  report <- buildDomainReport domainAppDomain
  case args of
    ["--json"] ->
      putStrLn (renderDomainReportJson report)
    _ ->
      mapM_ putStrLn (renderDomainReport report)
