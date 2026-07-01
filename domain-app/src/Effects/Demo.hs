module Effects.Demo
  ( demoEffect
  ) where

import Framework.Effect

-- effect: demoEffect
demoEffect :: EffectUnit
demoEffect =
  effect DemoEffect
    [ fact Foo5Fact
    , fact Foo6Fact
    ]
