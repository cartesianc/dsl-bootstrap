module Main
  ( main
  ) where

import Core.Bootstrap
  ( checkCoreBoundary
  , defaultCoreBoundary
  , renderCoreBoundaryError
  )

main :: IO ()
main =
  case checkCoreBoundary defaultCoreBoundary of
    [] ->
      putStrLn "[smoke] ok core bootstrap boundary"
    errors -> do
      mapM_ (putStrLn . renderCoreBoundaryError) errors
      ioError (userError "[smoke] core bootstrap boundary failed")
