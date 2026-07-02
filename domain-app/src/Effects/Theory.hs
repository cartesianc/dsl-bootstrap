{-# OPTIONS_GHC -Wno-missing-export-lists #-}
{-# OPTIONS_GHC -Wno-missing-signatures #-}

module Effects.Theory
  ( effectTheory
  ) where

import Framework.Effect
  ( EffectTheory
  , theory
  )
import qualified Effects.Demo
import qualified Effects.Logging
import qualified Effects.Report
import qualified Effects.System
import qualified Effects.User

effectTheory :: EffectTheory
effectTheory =
  theory
    [ Effects.Demo.demoEffect
    , Effects.Logging.loggingEffect
    , Effects.Report.reportEffect
    , Effects.System.systemEffect
    , Effects.User.userEffect
    ]
