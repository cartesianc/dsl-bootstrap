module Effects.Demo
  ( demoEffect
  ) where

import Effects.EffectTheory

-- effect: demoEffect
demoEffect :: EffectUnit
demoEffect =
  effect DemoEffect
    [ fact Foo5Fact
    , fact Foo6Fact
    ]
