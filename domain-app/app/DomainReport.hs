module Main
  ( main
  ) where

import Framework.Domain
  ( buildDomainReport
  , DomainReport (..)
  , DomainReportStatus (..)
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
  if domainReportPassed report
    then pure ()
    else ioError (userError "[report] domain report failed")

domainReportPassed :: DomainReport -> Bool
domainReportPassed report =
  case domainReportStatus report of
    DomainReportPassed ->
      True
    DomainReportFailed _ ->
      False
