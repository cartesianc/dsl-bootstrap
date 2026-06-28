module Interpreter.Runtime.Smoke
  ( runAlternativeWorkflowSmoke
  , runHangingWorkflowSmoke
  , runRaceWorkflowSmoke
  , runSimpleWorkflowSmoke
  ) where

import Control.Exception
  ( SomeException
  , try
  )

import Blueprint
import Core.Architecture.Cata
  ( cataHanging
  , cataWorkflow
  )
import Interpreter.Runtime.Algebra
  ( runtimeAlgebra
  )
import Interpreter.Runtime.Hanging.FreeMonoid
  ( runHanging
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , emptyRuntime
  )

runSimpleWorkflowSmoke :: IO ()
runSimpleWorkflowSmoke = do
  runSmoke "fact" smokeFact
  runSmoke "chain" smokeChain
  runSmoke "wait" smokeWait
  runSmoke "parallel" smokeParallel

runAlternativeWorkflowSmoke :: IO ()
runAlternativeWorkflowSmoke = do
  runSmoke "fallback" smokeFallback
  runSmoke "choice" smokeChoice

runRaceWorkflowSmoke :: IO ()
runRaceWorkflowSmoke =
  runSmoke "race" smokeRace

runHangingWorkflowSmoke :: IO ()
runHangingWorkflowSmoke = do
  putStrLn "[smoke] hanging"
  runtime <- cataWorkflow runtimeAlgebra smokeFact emptyRuntime
  result <- try (runHanging (cataHanging runtimeAlgebra smokeHanging) runtime)
  case result of
    Right nextRuntime ->
      putStrLn ("[smoke] ok " ++ show (availableFacts nextRuntime))
    Left exception ->
      putStrLn ("[smoke] failed " ++ show (exception :: SomeException))

runSmoke :: String -> WorkflowComponent -> IO ()
runSmoke label workflow = do
  putStrLn ("[smoke] " ++ label)
  result <- try (cataWorkflow runtimeAlgebra workflow emptyRuntime)
  case result of
    Right runtime ->
      putStrLn ("[smoke] ok " ++ show (availableFacts runtime))
    Left exception ->
      putStrLn ("[smoke] failed " ++ show (exception :: SomeException))

smokeFact :: Fact
smokeFact =
  fact [Foo5Fact]

smokeChain :: Chain
smokeChain =
  chain Foo1
    [ fact [Foo5Fact]
    , fact [Foo6Fact]
    ]

smokeWait :: Chain
smokeWait =
  chain Foo2
    [ fact [Foo5Fact]
    , wait [Foo5Fact] (fact [Foo6Fact])
    ]

smokeParallel :: Parallel
smokeParallel =
  parallel Foo3
    [ fact [AddCalculatedFact]
    , fact [FactorialCalculatedFact]
    , fact [SquaresCalculatedFact]
    ]

smokeFallback :: Fallback
smokeFallback =
  fallback
    [ wait [RuntimePreparedFact] (fact [Foo5Fact])
    , fact [Foo6Fact]
    ]

smokeChoice :: Choice
smokeChoice =
  choice
    (ChoiceKey "primary")
    [ (ChoiceKey "primary", fact [Foo5Fact])
    , (ChoiceKey "backup", fact [Foo6Fact])
    ]

smokeRace :: Race
smokeRace =
  race
    [ fact [Foo5Fact]
    , fact [Foo6Fact]
    ]

smokeHanging :: Hanging
smokeHanging =
  hanging
    [ callback [Foo5Fact] (fact [Foo6Fact])
    , middleware ReportMiddleware (fact [AddCalculatedFact])
    , loop (fact [SquaresCalculatedFact])
    ]
