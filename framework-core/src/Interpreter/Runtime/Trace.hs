module Interpreter.Runtime.Trace
  ( renderFactExpr
  , runtimeSleep
  , traceRuntime
  ) where

import Control.Concurrent
  ( threadDelay
  )

import Core.Architecture
  ( FactExpr (..)
  , Requirement (..)
  )
import Core.Architecture.Internal
  ( RequirementEffect (..)
  )

runtimeSleep :: IO ()
runtimeSleep =
  threadDelay 100000

traceRuntime :: String -> IO ()
traceRuntime message =
  putStrLn ("[runtime] " ++ message)

renderFactExpr :: Show fact => FactExpr fact -> String
renderFactExpr (FactItems currentFacts) =
  renderFacts currentFacts
renderFactExpr (FactAll currentFacts) =
  "allOf " ++ show (map renderFactExpr currentFacts)
renderFactExpr (FactAny currentFacts) =
  "anyOf " ++ show (map renderFactExpr currentFacts)

renderFacts :: Show fact => Requirement fact -> String
renderFacts currentFacts =
  show (requirementEffectItems (requirementFacts currentFacts))
