module Main
  ( main
  ) where

import Framework.FixedPoint
  ( buildFixedPointReport
  , fixedPointPassed
  , renderFixedPointReport
  )

main :: IO ()
main = do
  report <- buildFixedPointReport
  mapM_ putStrLn (renderFixedPointReport report)
  if fixedPointPassed report
    then pure ()
    else ioError (userError "fixed-point evidence diff failed")

