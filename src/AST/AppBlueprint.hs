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

foo3 :: Parallel
foo3 =
  parallel Foo3
    [ fact [AddCalculatedFact]
    , fact [FactorialCalculatedFact]
    ]

foo4 :: Wait
foo4 =
  wait
    (allOf [UserKnownFact, RuntimePreparedFact])
    (chain Foo4
      [ fact [CalculationSectionOpenedFact]
      , fact [ReportGeneratedFact]
      ])

foo5 :: Fact
foo5 =
  fact [Foo5Fact]

foo6 :: Fact
foo6 =
  fact [Foo6Fact]

hooks :: AppHanging
hooks =
  hanging
    [ configurationHook
    , bootHook
    , runtimeHook
    , loggingHook
    , userHook
    , reportHook
    , shutdownHook
    , foo3Hook
    , foo4Hook
    , foo7
    , foo9
    , reportLoop
    ]

foo3Hook :: Middleware
foo3Hook =
  middleware ReportMiddleware foo3

foo4Hook :: Middleware
foo4Hook =
  middleware ReportMiddleware foo4

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
