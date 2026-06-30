module Main
  ( main
  ) where

import Core.Bootstrap
  ( checkCoreBoundary
  , defaultCoreBoundary
  , renderCoreBoundaryError
  )
import Core.Language.Constraint
  ( defaultLanguageConstraints
  )
import Core.Language.Elaboration
  ( checkDefaultElaborationContract
  , defaultElaborationConstraints
  , renderElaborationError
  )
import Core.Language.Validation
  ( checkDefaultLanguageSpec
  , renderLanguageError
  )

main :: IO ()
main = do
  case checkCoreBoundary defaultCoreBoundary of
    [] ->
      putStrLn "[smoke] ok core bootstrap boundary"
    errors -> do
      mapM_ (putStrLn . renderCoreBoundaryError) errors
      ioError (userError "[smoke] core bootstrap boundary failed")
  case checkDefaultLanguageSpec of
    [] ->
      putStrLn ("[smoke] ok language spec " ++ show (length defaultLanguageConstraints) ++ " constraints")
    errors -> do
      mapM_ (putStrLn . renderLanguageError) errors
      ioError (userError "[smoke] language spec failed")
  case checkDefaultElaborationContract of
    [] ->
      putStrLn
        ( "[smoke] ok elaboration contract "
            ++ show (length defaultElaborationConstraints)
            ++ " constraints"
        )
    errors -> do
      mapM_ (putStrLn . renderElaborationError) errors
      ioError (userError "[smoke] elaboration contract failed")
