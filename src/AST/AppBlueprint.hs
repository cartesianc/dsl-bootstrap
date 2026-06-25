module AST.AppBlueprint
  ( AppBlueprint (..)
  , App
  , AppHanging
  , blueprint
  , app
  , hooks
  ) where

import Blueprint
import Plugins

data AppBlueprint = AppBlueprint
  { blueprintApp :: App
  , blueprintHanging :: AppHanging
  }

type App = Chain

type AppHanging = Hanging

blueprint :: AppBlueprint
blueprint =
  AppBlueprint
    { blueprintApp = app
    , blueprintHanging = hooks
    }

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
    , foo8
    ]

abc :: Chain
abc = chain Abc []

foo1 :: Chain
foo1 =
  chain Foo1
    [ fact [AppStartedFact]
    , fact [RuntimePreparedFact]
    ]

foo2 :: Parallel
foo2 =
  parallel Foo2
    [ fact [AddCalculatedFact]
    , fact [FactorialCalculatedFact]
    , fact [SquaresCalculatedFact]
    ]

foo3 :: Middleware
foo3 =
  middleware ReportMiddleware
    (parallel Foo3
      [ fact [AddCalculatedFact]
      , fact [FactorialCalculatedFact]
      ])

foo4 :: Wait
foo4 =
  wait
    (allOf [UserKnownFact, RuntimePreparedFact])
    (middleware ReportMiddleware
      (chain Foo4
        [ fact [CalculationSectionOpenedFact]
        , fact [ReportGeneratedFact]
        ]))

foo5 :: Fact
foo5 =
  fact [Foo5Fact]

foo6 :: Fact
foo6 =
  fact [Foo6Fact]

foo8 :: Wait
foo8 =
  wait [UserKnownFact] reportModule

hooks :: AppHanging
hooks =
  hanging
    [ foo7
    , foo9
    ]

foo7 :: HangingComponent
foo7 =
  callback
    (allOf [UserKnownFact, RuntimePreparedFact])
    reportModule

foo9 :: HangingComponent
foo9 =
  suspense
    (anyOf [UserKnownFact, ReportGeneratedFact])
    reportModule
