module Core.App.Boundary
  ( MinimalCoreReport (..)
  , MinimalCoreStatus (..)
  , buildMinimalCoreReport
  , checkMinimalCore
  , checkMinimalCoreModel
  , minimalCorePassed
  , minimalCoreStatus
  , renderMinimalCoreReport
  ) where

import AST.AppBlueprint
  ( AppBlueprint
  )
import Core.App
  ( AppError
  , AppPlan (..)
  , app
  )
import Core.App.Ana
  ( AppModel
  , hyloAppModel
  )
import Core.Effect.Constraint
  ( ConstraintError
  , ConstraintFact
  , checkConstraintFacts
  , constraintsFromAppPlan
  , renderConstraintError
  )
import Effects.EffectTheory
  ( EffectTheory
  )

data MinimalCoreStatus
  = MinimalCorePassed
  | MinimalCoreFailed
  deriving (Eq, Show)

data MinimalCoreReport = MinimalCoreReport
  { minimalCoreAppPlan :: AppPlan
  , minimalCoreConstraints :: [ConstraintFact]
  , minimalCoreConstraintErrors :: [ConstraintError]
  }

checkMinimalCore ::
  AppBlueprint ->
  EffectTheory ->
  Either AppError MinimalCoreReport
checkMinimalCore blueprint effects =
  buildMinimalCoreReport <$> app blueprint effects

checkMinimalCoreModel ::
  AppModel ->
  Either AppError MinimalCoreReport
checkMinimalCoreModel currentModel =
  hyloAppModel
    checkMinimalCore
    currentModel

buildMinimalCoreReport :: AppPlan -> MinimalCoreReport
buildMinimalCoreReport currentPlan =
  MinimalCoreReport
    { minimalCoreAppPlan = currentPlan
    , minimalCoreConstraints = currentConstraints
    , minimalCoreConstraintErrors = checkConstraintFacts currentConstraints
    }
  where
    currentConstraints =
      constraintsFromAppPlan currentPlan

minimalCoreStatus :: MinimalCoreReport -> MinimalCoreStatus
minimalCoreStatus report
  | minimalCorePassed report =
      MinimalCorePassed
  | otherwise =
      MinimalCoreFailed

minimalCorePassed :: MinimalCoreReport -> Bool
minimalCorePassed =
  null . minimalCoreConstraintErrors

renderMinimalCoreReport :: MinimalCoreReport -> String
renderMinimalCoreReport report =
  joinWith
    "\n"
    ( [ "minimal core status: " ++ renderMinimalCoreStatus (minimalCoreStatus report)
      , "facts: " ++ show (length (appPlanFacts (minimalCoreAppPlan report)))
      , "externalMake boundaries: " ++ show (length (appPlanSendBoundaries (minimalCoreAppPlan report)))
      , "constraints: " ++ show (length (minimalCoreConstraints report))
      , "constraint errors: " ++ show (length (minimalCoreConstraintErrors report))
      ]
        ++ renderErrors (minimalCoreConstraintErrors report)
    )

renderMinimalCoreStatus :: MinimalCoreStatus -> String
renderMinimalCoreStatus MinimalCorePassed =
  "passed"
renderMinimalCoreStatus MinimalCoreFailed =
  "failed"

renderErrors :: [ConstraintError] -> [String]
renderErrors [] =
  []
renderErrors errors =
  "errors:" : map (("  - " ++) . renderConstraintError) errors

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
