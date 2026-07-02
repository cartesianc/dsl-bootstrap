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
    _ ->
      printRegisteredAstTrees
