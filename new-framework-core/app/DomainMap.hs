module Main
  ( main
  ) where

import Domain.Relations
  ( renderRegisteredDomainMap
  , renderRegisteredDomainMapJson
  , renderSelectedDomainMap
  , renderSelectedDomainMapJson
  )
import System.Environment
  ( getArgs
  )
import System.Exit
  ( die
  )

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] ->
      mapM_ putStrLn renderRegisteredDomainMap
    ["all"] ->
      mapM_ putStrLn renderRegisteredDomainMap
    ["json"] ->
      putStrLn renderRegisteredDomainMapJson
    ["json", "all"] ->
      putStrLn renderRegisteredDomainMapJson
    ["json", name] ->
      either die putStrLn (renderSelectedDomainMapJson name)
    ["text", "all"] ->
      mapM_ putStrLn renderRegisteredDomainMap
    ["text", name] ->
      either die (mapM_ putStrLn) (renderSelectedDomainMap name)
    [name] ->
      either die (mapM_ putStrLn) (renderSelectedDomainMap name)
    _ ->
      die "usage: domain-map [all|framework-core|text DOMAIN|json [DOMAIN]]"
