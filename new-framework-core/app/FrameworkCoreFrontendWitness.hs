module Main
  ( main
  ) where

import Framework.RegistryCodegen
  ( GeneratedSource (..)
  , diffGeneratedLines
  , frameworkCoreFrontendSources
  , generatedLinesMatch
  )

main :: IO ()
main = do
  results <- mapM checkGeneratedSource frameworkCoreFrontendSources
  case concat results of
    [] ->
      putStrLn ("[witness] ok framework-core frontend generated sources " ++ show (length frameworkCoreFrontendSources) ++ " modules")
    failures ->
      ioError
        ( userError
            ( "[witness] framework-core frontend generated sources failed\n"
                ++ unlines failures
            )
        )

checkGeneratedSource :: GeneratedSource -> IO [String]
checkGeneratedSource source = do
  actualText <- readFile (generatedSourcePath source)
  let actualLines =
        lines actualText
  if generatedLinesMatch (generatedSourceLines source) actualLines
    then pure []
    else
      pure
        ( ("generated source differs from " ++ generatedSourcePath source)
            : take 40 (diffGeneratedLines (generatedSourceLines source) actualLines)
        )
