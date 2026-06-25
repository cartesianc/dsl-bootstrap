module AppBlueprint
  ( App
  , app
  ) where

import Blueprint
import Plugins

type App = Chain

app :: App
app =
  chain AppFlow
    [ lifecycleStart
    , userModule
    , reportModule
    , lifecycleEnd
    , abc
    , foo1
    , foo2
    , foo3
    , foo4
    , foo5
    , foo6
    ]

abc :: Chain
abc = chain Abc []

foo1 :: Chain
foo1 =
  chain Foo1
    [ effect [AppStartedFact]
    , effect [RuntimePreparedFact]
    ]

foo2 :: Parallel
foo2 =
  parallel Foo2
    [ effect [AddCalculatedFact]
    , effect [FactorialCalculatedFact]
    , effect [SquaresCalculatedFact]
    ]

foo3 :: Middleware
foo3 =
  middleware ReportMiddleware
    (parallel Foo3
      [ effect [AddCalculatedFact]
      , effect [FactorialCalculatedFact]
      ])

foo4 :: Callback
foo4 =
  callback
    [ UserKnownFact ]
    (middleware ReportMiddleware
      (chain Foo4
        [ effect [CalculationSectionOpenedFact]
        , effect [ReportGeneratedFact]
        ]))

foo5 :: Effect
foo5 =
  effect [Foo5Fact]

foo6 :: Effect
foo6 =
  effect [Foo6Fact]
