module Main
  ( main
  ) where

import Framework.Domain
  ( buildDomainReport
  , renderDomainReport
  )
import SelfDomainApp
  ( domainAppDomain )

main :: IO ()
main = do
  report <- buildDomainReport domainAppDomain
  mapM_ putStrLn (renderDomainReport report)
