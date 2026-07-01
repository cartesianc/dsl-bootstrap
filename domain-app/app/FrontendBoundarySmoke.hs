module Main
  ( main
  ) where

import Core.Boundary.Frontend
  ( checkFrontendImports
  , defaultFrontendBoundaryPolicy
  , extractFrontendImports
  , renderFrontendBoundaryError
  )

main :: IO ()
main = do
  currentImports <- extractFrontendImports defaultFrontendBoundaryPolicy
  let errors =
        checkFrontendImports defaultFrontendBoundaryPolicy currentImports
  case errors of
    [] ->
      putStrLn "[smoke] ok frontend boundary"
    _ -> do
      mapM_ (putStrLn . renderFrontendBoundaryError) errors
      ioError (userError "[smoke] frontend boundary failed")
