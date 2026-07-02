module SelfDomainApp
  ( renderSelfDomainAppReport
  , runSelfDomainApp
  , selfDomainAppDomain
  , selfDomainAppName
  ) where

import Bootstrap.Report
  ( FrameworkCoreReport
  , buildFrameworkCoreReport
  , frameworkCoreReportPassed
  , renderFrameworkCoreReport
  )
import Domain.Registry
  ( DomainRegistration (..)
  , frameworkCoreDomain
  )

selfDomainAppName :: String
selfDomainAppName =
  "domain-app:self-framework-core"

selfDomainAppDomain :: DomainRegistration
selfDomainAppDomain =
  frameworkCoreDomain
    { domainRegistrationName = selfDomainAppName
    }

runSelfDomainApp :: IO ()
runSelfDomainApp = do
  report <- buildFrameworkCoreReport
  if frameworkCoreReportPassed report
    then mapM_ putStrLn (renderSelfDomainAppReport report)
    else
      ioError
        ( userError
            ( "[domain-app] self framework-core compile failed:\n"
                ++ unlines (renderSelfDomainAppReport report)
            )
        )

renderSelfDomainAppReport :: FrameworkCoreReport -> [String]
renderSelfDomainAppReport report =
  [ "domain-app self compile"
  , "domain: " ++ domainRegistrationName selfDomainAppDomain
  , "content: " ++ domainRegistrationName frameworkCoreDomain
  , "status: " ++ renderStatus report
  ]
    ++ renderFrameworkCoreReport report

renderStatus :: FrameworkCoreReport -> String
renderStatus report
  | frameworkCoreReportPassed report =
      "passed"
  | otherwise =
      "failed"
