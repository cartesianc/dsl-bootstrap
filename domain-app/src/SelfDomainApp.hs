module SelfDomainApp
  ( domainAppDomain
  , renderSelfDomainAppReport
  , runSelfDomainApp
  , selfDomainAppName
  ) where

import Domain.AppBlueprint
  ( blueprint )
import Domain.Runtime
  ( domainRuntimeEffectEnvironment )
import Effects.Theory
  ( effectTheory )
import Framework.Domain
  ( DomainRegistration
  , DomainReport (..)
  , DomainReportStatus (..)
  , buildDomainReport
  , domainWithRuntime
  , renderDomainReport
  )

selfDomainAppName :: String
selfDomainAppName =
  "domain-app"

domainAppDomain :: DomainRegistration
domainAppDomain =
  domainWithRuntime
    selfDomainAppName
    blueprint
    effectTheory
    domainRuntimeEffectEnvironment

runSelfDomainApp :: IO ()
runSelfDomainApp = do
  report <- buildDomainReport domainAppDomain
  if domainReportPassed report
    then mapM_ putStrLn (renderSelfDomainAppReport report)
    else
      ioError
        ( userError
            ( "[domain-app] framework compile failed:\n"
                ++ unlines (renderSelfDomainAppReport report)
            )
        )

renderSelfDomainAppReport :: DomainReport -> [String]
renderSelfDomainAppReport report =
  [ "domain-app framework compile"
  , "domain: " ++ selfDomainAppName
  , "status: " ++ renderStatus report
  ]
    ++ renderDomainReport report

domainReportPassed :: DomainReport -> Bool
domainReportPassed report =
  case domainReportStatus report of
    DomainReportPassed ->
      True
    DomainReportFailed _ ->
      False

renderStatus :: DomainReport -> String
renderStatus report
  | domainReportPassed report =
      "passed"
  | otherwise =
      "failed"
