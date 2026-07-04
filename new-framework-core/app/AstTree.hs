module Main
  ( main
  ) where

import Domain.Ast
  ( frameworkCoreAstRegistration
  )
import Domain.Registry
  ( printAstRegistration
  , printRegisteredAstTrees
  , renderDomainRegistry
  , renderDomainRegistryJson
  , renderFrameworkCoreAstTreeJson
  , renderRegisteredAstTreesJson
  )
import System.Environment
  ( getArgs
  )

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["all"] ->
      printRegisteredAstTrees
    ["framework-core"] ->
      printAstRegistration frameworkCoreAstRegistration
    ["registry"] ->
      mapM_ putStrLn renderDomainRegistry
    ["json"] ->
      putStrLn renderRegisteredAstTreesJson
    ["json", "all"] ->
      putStrLn renderRegisteredAstTreesJson
    ["json", "framework-core"] ->
      putStrLn renderFrameworkCoreAstTreeJson
    ["json", "registry"] ->
      putStrLn renderDomainRegistryJson
    _ ->
      printRegisteredAstTrees
