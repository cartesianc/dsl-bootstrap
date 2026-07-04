module Main
  ( main
  ) where

import Domain.Registry
  ( renderDomainRegistry
  , renderDomainRegistryJson
  )
import System.Environment
  ( getArgs
  )

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["--json"] ->
      putStrLn renderDomainRegistryJson
    ["json"] ->
      putStrLn renderDomainRegistryJson
    _ ->
      mapM_ putStrLn renderDomainRegistry
