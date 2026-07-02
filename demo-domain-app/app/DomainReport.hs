module Main
  ( main
  ) where

import CurrentAst
  ( currentAst )
import CurrentEffects
  ( currentEffects )
import Domain.Runtime
  ( domainRuntimeEffectEnvironment )
import Framework.Domain
  ( buildDomainReport
  , domainWithRuntime
  , renderDomainReport
  )

main :: IO ()
main = do
  report <-
    buildDomainReport
      ( domainWithRuntime
          "demo-domain-app"
          currentAst
          currentEffects
          domainRuntimeEffectEnvironment
      )
  mapM_ putStrLn (renderDomainReport report)

