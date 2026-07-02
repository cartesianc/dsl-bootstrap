module Main
  ( main
  ) where

import Domain.Registry
  ( runFrameworkCoreDomain
  )

main :: IO ()
main =
  runFrameworkCoreDomain
