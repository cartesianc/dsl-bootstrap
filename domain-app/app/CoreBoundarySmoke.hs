module Main
  ( main
  ) where

import Data.List
  ( isInfixOf
  )

import qualified Domain.AppBlueprint as AppBlueprint
import Framework.Background
  ( checkCoreBoundaryWithImportGraph
  , checkDefaultElaborationContract
  , checkDefaultLanguageSpec
  , checkMinimalCore
  , checkPackageImportGraph
  , defaultCoreBoundary
  , defaultElaborationConstraints
  , defaultLanguageConstraints
  , defaultPackageImportPolicy
  , proveMinimalCoreWithAvailableSolver
  , readPackageImportGraph
  , renderAppError
  , renderCoreBoundaryError
  , renderElaborationError
  , renderLanguageError
  , renderPackageImportError
  , smtLibForProposition
  , SmtProposition (..)
  , SmtResult (..)
  , SmtStatus (..)
  )
import qualified Effects.Theory as EffectsTheory

main :: IO ()
main = do
  importGraph <- readPackageImportGraph defaultPackageImportPolicy
  case checkPackageImportGraph defaultPackageImportPolicy importGraph of
    [] ->
      putStrLn "[smoke] ok package import graph"
    errors -> do
      mapM_ (putStrLn . renderPackageImportError) errors
      ioError (userError "[smoke] package import graph failed")
  case checkCoreBoundaryWithImportGraph defaultCoreBoundary importGraph of
    [] ->
      putStrLn "[smoke] ok core bootstrap boundary with import graph"
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
  case checkMinimalCore AppBlueprint.blueprint EffectsTheory.effectTheory of
    Left errorReport ->
      ioError (userError ("[smoke] minimal core build failed: " ++ renderAppError errorReport))
    Right report -> do
      let smtLib =
            smtLibForProposition ProveFactClosure report
      if "(set-logic" `isInfixOf` smtLib && "(check-sat)" `isInfixOf` smtLib
        then putStrLn "[smoke] ok smt-lib generation"
        else ioError (userError "[smoke] smt-lib generation failed")
      smtResults <- proveMinimalCoreWithAvailableSolver report
      if any ((== SmtFailed) . smtResultStatus) smtResults
        then ioError (userError ("[smoke] real smt backend failed: " ++ renderSmtSmokeStatuses smtResults))
        else putStrLn ("[smoke] ok real smt backend " ++ renderSmtSmokeStatuses smtResults)

renderSmtSmokeStatuses :: [SmtResult] -> String
renderSmtSmokeStatuses results =
  "passed="
    ++ show (countStatus SmtPassed results)
    ++ " failed="
    ++ show (countStatus SmtFailed results)
    ++ " skipped="
    ++ show (countStatus SmtSkipped results)

countStatus :: SmtStatus -> [SmtResult] -> Int
countStatus status =
  length . filter ((== status) . smtResultStatus)
