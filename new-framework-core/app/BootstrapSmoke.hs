module Main
  ( main
  ) where

import Bootstrap.Blueprint
  ( coreBootstrapBlueprint
  )
import Bootstrap.CoreSurface
  ( coreSurfaceCapabilityCount
  , coreSurfaceModuleCount
  )
import Bootstrap.Effects
  ( coreBootstrapEffects
  )
import Bootstrap.Runtime
  ( NativeAppPlan (..)
  , NativeConstraint (..)
  , buildNativeApp
  , renderNativeAppError
  )

main :: IO ()
main =
  case buildNativeApp coreBootstrapBlueprint coreBootstrapEffects of
    Left errorReport ->
      ioError (userError ("[smoke] framework-core native expression build failed: " ++ renderNativeAppError errorReport))
    Right plan
      | nativePlanPassed plan -> do
          putStrLn "[smoke] ok framework-core native expression minimal app"
          putStrLn ("[smoke] core surface modules " ++ show coreSurfaceModuleCount)
          putStrLn ("[smoke] core surface capabilities " ++ show coreSurfaceCapabilityCount)
          putStrLn ("[smoke] facts " ++ show (length (nativeAppPlanFacts plan)))
          putStrLn ("[smoke] constraints " ++ show (length (nativeAppPlanConstraints plan)))
      | otherwise ->
          ioError
            ( userError
                ( "[smoke] framework-core native expression constraints failed:\n"
                    ++ renderNativeConstraintErrors plan
                )
            )

nativePlanPassed :: NativeAppPlan -> Bool
nativePlanPassed =
  all nativeConstraintPassed . nativeAppPlanConstraints

renderNativeConstraintErrors :: NativeAppPlan -> String
renderNativeConstraintErrors plan =
  unlines
    [ nativeConstraintMessage constraint
    | constraint <- nativeAppPlanConstraints plan
    , not (nativeConstraintPassed constraint)
    ]
