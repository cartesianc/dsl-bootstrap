module Main
  ( main
  ) where

import Domain.Registry
  ( renderDomainRegistry
  )

main :: IO ()
main =
  mapM_ putStrLn renderDomainRegistry
