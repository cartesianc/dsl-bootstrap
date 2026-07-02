module Main
  ( main
  ) where

import Bootstrap.Report
  ( FactClosureReport (..)
  , FrameworkCoreReport (..)
  , buildFrameworkCoreReport
  , frameworkCoreReportPassed
  , renderFrameworkCoreReport
  )

main :: IO ()
main = do
  report <- buildFrameworkCoreReport
  if frameworkCoreReportPassed report
    then printRuntimeSmoke report
    else
      ioError
        ( userError
            ( "[smoke] framework-core report failed:\n"
                ++ unlines (renderFrameworkCoreReport report)
            )
        )

printRuntimeSmoke :: FrameworkCoreReport -> IO ()
printRuntimeSmoke report = do
  putStrLn "[smoke] ok framework-core native runtime report"
  putStrLn ("[smoke] framework-core facts " ++ show (length (factClosureDeclaredFacts facts)))
  putStrLn ("[smoke] framework-core runtime closure facts " ++ show (length (factClosurePlannedRuntimeFacts facts)))
  putStrLn ("[smoke] framework-core runtime final facts " ++ show (length (factClosureFinalRuntimeFacts facts)))
  putStrLn ("[smoke] framework-core declared outside runtime closure " ++ show (length (factClosureDeclaredOutsideRuntime facts)))
  where
    facts =
      frameworkCoreReportFactClosure report
