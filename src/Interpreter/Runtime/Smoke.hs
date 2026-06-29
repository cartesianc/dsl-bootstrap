module Interpreter.Runtime.Smoke
  ( runAlternativeWorkflowSmoke
  , runHangingWorkflowSmoke
  , runRaceWorkflowSmoke
  , runRuntimeBoundarySmoke
  , runSimpleWorkflowSmoke
  ) where

import Control.Exception
  ( SomeException
  , try
  )

import Blueprint
import qualified Core.Architecture as Architecture
import Core.Architecture.Recursion
  ( gpreproHanging
  , gpreproWorkflow
  )
import Core.Workflow.Eff
  ( compileHangingEff
  , compileWorkflowEff
  , interpretHangingEff
  , interpretWorkflowEff
  )
import Effects.EffectTheory
  ( EffectTheory
  , theory
  )
import Effects.Names
  ( ProfileName (Production)
  , SendName (AskUserName)
  )
import Effects.User
  ( userEffect
  )
import Interpreter.Runtime.Algebra
  ( runtimeAlgebra
  )
import Interpreter.Runtime.Contextware
  ( contextwareWithEffectEnvironment
  )
import Interpreter.Runtime.Hanging.FreeMonoid
  ( runHanging
  )
import Interpreter.Runtime.Handlers
  ( defaultRuntimeEffectEnvironment
  , emptyHandlerRegistry
  , runtimeEffectEnvironment
  )
import Interpreter.Runtime.Monad
  ( defaultRuntimeEnv
  , getRuntimeState
  , runRuntimeM
  , runRuntimeMOrThrow
  , throwRuntimeError
  )
import Interpreter.Runtime.Types
  ( Runtime (..)
  , RuntimeEffectEnvironment
  , RuntimeError (..)
  , RuntimeMiddlewareEvent (..)
  , RuntimeResult (..)
  , WorkflowProgram
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
  runtime <-
    runRuntimeMOrThrow
      defaultRuntimeEnv
      emptyRuntime
      (gpreproWorkflow compileWorkflowEff interpretWorkflowEff runtimeAlgebra smokeFact)
  result <-
    try
      ( runRuntimeMOrThrow
          defaultRuntimeEnv
          runtime
          (runHanging (gpreproHanging compileHangingEff interpretHangingEff runtimeAlgebra smokeHanging))
      )
  case result of
    Right nextRuntime ->
      putStrLn ("[smoke] ok " ++ show (availableFacts nextRuntime))
    Left exception ->
      putStrLn ("[smoke] failed " ++ show (exception :: SomeException))

runRuntimeBoundarySmoke :: IO ()
runRuntimeBoundarySmoke = do
  runExpectedRuntimeFailure
    "missing take/make rule"
    (RuntimeMissingFactRule Foo5Fact)
    (programWithEffects (theory []) smokeFact)
  runExpectedRuntimeFailureWithTrace
    "wait blocked"
    (RuntimeWaitBlocked "[Foo5Fact]")
    "wait blocked [Foo5Fact]"
    (programPlain smokeBlockedWait)
  runExpectedRuntimeFailureWithTrace
    "missing handler"
    (RuntimeHandlerFailed AskUserName "missing runtime handler RuntimeAskUserName")
    "externalMake AskUserName using RuntimeAskUserName"
    ( programWithEnvironment
        (runtimeEffectEnvironment Production emptyHandlerRegistry)
        (theory [userEffect])
        smokeUserNameAsked
    )
  runExpectedRuntimeTrace
    "trace captured"
    "fact [Foo5Fact]"
    (programPlain smokeFact)
  runMiddlewareRuntimeSmoke
  runMiddlewareFailureSmoke

runMiddlewareRuntimeSmoke :: IO ()
runMiddlewareRuntimeSmoke = do
  putStrLn "[smoke] boundary middleware runtime"
  result <- runRuntimeM defaultRuntimeEnv emptyRuntime (runHanging smokeMiddlewareRuntime)
  case result of
    RuntimeSucceeded _ runtime
      | runtimeMiddlewareStack runtime == []
          && runtimeMiddlewareEvents runtime
            == [ RuntimeMiddlewareEntered ReportMiddleware
               , RuntimeMiddlewareExited ReportMiddleware
               ]
          && AddCalculatedFact `elem` availableFacts runtime
          && "middleware ReportMiddleware begin" `elem` runtimeTrace runtime
          && "middleware ReportMiddleware end" `elem` runtimeTrace runtime ->
          putStrLn "[smoke] ok middleware runtime"
      | otherwise ->
          ioError
            ( userError
                ( "[smoke] failed middleware runtime: "
                    ++ show runtime
                )
            )
    RuntimeFailed actualError _ ->
      ioError
        ( userError
            ( "[smoke] failed middleware runtime: expected success, got "
                ++ show actualError
            )
        )

runMiddlewareFailureSmoke :: IO ()
runMiddlewareFailureSmoke = do
  putStrLn "[smoke] boundary middleware failure cleanup"
  result <- runRuntimeM defaultRuntimeEnv emptyRuntime (runHanging smokeMiddlewareFailureRuntime)
  case result of
    RuntimeFailed (RuntimeIoException "middleware target failed") runtime
      | runtimeMiddlewareStack runtime == []
          && runtimeMiddlewareEvents runtime
            == [ RuntimeMiddlewareEntered ReportMiddleware
               , RuntimeMiddlewareExited ReportMiddleware
               ] ->
          putStrLn "[smoke] ok middleware failure cleanup"
      | otherwise ->
          ioError
            ( userError
                ( "[smoke] failed middleware failure cleanup: "
                    ++ show runtime
                )
            )
    RuntimeFailed actualError _ ->
      ioError
        ( userError
            ( "[smoke] failed middleware failure cleanup: expected middleware target failure, got "
                ++ show actualError
            )
        )
    RuntimeSucceeded _ runtime ->
      ioError
        ( userError
            ( "[smoke] failed middleware failure cleanup: expected failure, got success "
                ++ show runtime
            )
        )

runSmoke :: String -> WorkflowComponent -> IO ()
runSmoke label workflow = do
  putStrLn ("[smoke] " ++ label)
  result <-
    try
      ( runRuntimeMOrThrow
          defaultRuntimeEnv
          emptyRuntime
          (gpreproWorkflow compileWorkflowEff interpretWorkflowEff runtimeAlgebra workflow)
      )
  case result of
    Right runtime ->
      putStrLn ("[smoke] ok " ++ show (availableFacts runtime))
    Left exception ->
      putStrLn ("[smoke] failed " ++ show (exception :: SomeException))

runExpectedRuntimeFailure :: String -> RuntimeError -> WorkflowProgram -> IO ()
runExpectedRuntimeFailure label expectedError program =
  runExpectedRuntimeFailureWith label expectedError (const True) program

runExpectedRuntimeFailureWithTrace ::
  String ->
  RuntimeError ->
  String ->
  WorkflowProgram ->
  IO ()
runExpectedRuntimeFailureWithTrace label expectedError expectedTrace =
  runExpectedRuntimeFailureWith label expectedError (elem expectedTrace . runtimeTrace)

runExpectedRuntimeFailureWith ::
  String ->
  RuntimeError ->
  (Runtime -> Bool) ->
  WorkflowProgram ->
  IO ()
runExpectedRuntimeFailureWith label expectedError statePredicate program = do
  putStrLn ("[smoke] boundary " ++ label)
  result <- runRuntimeM defaultRuntimeEnv emptyRuntime program
  case result of
    RuntimeFailed actualError runtime
      | actualError == expectedError && statePredicate runtime ->
          putStrLn ("[smoke] ok " ++ label)
      | actualError == expectedError ->
          ioError (userError ("[smoke] failed " ++ label ++ ": trace/state predicate failed"))
      | otherwise ->
          ioError
            ( userError
                ( "[smoke] failed "
                    ++ label
                    ++ ": expected "
                    ++ show expectedError
                    ++ ", got "
                    ++ show actualError
                )
            )
    RuntimeSucceeded _ runtime ->
      ioError
        ( userError
            ( "[smoke] failed "
                ++ label
                ++ ": expected runtime error, got success "
                ++ show (availableFacts runtime)
            )
        )

runExpectedRuntimeTrace :: String -> String -> WorkflowProgram -> IO ()
runExpectedRuntimeTrace label expectedTrace program = do
  putStrLn ("[smoke] boundary " ++ label)
  result <- runRuntimeM defaultRuntimeEnv emptyRuntime program
  case result of
    RuntimeSucceeded _ runtime
      | expectedTrace `elem` runtimeTrace runtime ->
          putStrLn ("[smoke] ok " ++ label)
      | otherwise ->
          ioError
            ( userError
                ( "[smoke] failed "
                    ++ label
                    ++ ": missing trace "
                    ++ show expectedTrace
                    ++ " in "
                    ++ show (runtimeTrace runtime)
                )
            )
    RuntimeFailed actualError _ ->
      ioError
        ( userError
            ( "[smoke] failed "
                ++ label
                ++ ": expected success, got "
                ++ show actualError
            )
        )

programPlain :: WorkflowComponent -> WorkflowProgram
programPlain =
  gpreproWorkflow compileWorkflowEff interpretWorkflowEff runtimeAlgebra

programWithEffects :: EffectTheory -> WorkflowComponent -> WorkflowProgram
programWithEffects =
  programWithEnvironment defaultRuntimeEffectEnvironment

programWithEnvironment ::
  RuntimeEffectEnvironment ->
  EffectTheory ->
  WorkflowComponent ->
  WorkflowProgram
programWithEnvironment environment effects =
  gpreproWorkflow
    compileWorkflowEff
    interpretWorkflowEff
    (contextwareWithEffectEnvironment environment effects runtimeAlgebra)

smokeFact :: Fact
smokeFact =
  fact [Foo5Fact]

smokeUserNameAsked :: Fact
smokeUserNameAsked =
  fact [UserNameAskedFact]

smokeBlockedWait :: Wait
smokeBlockedWait =
  wait [Foo5Fact] (fact [Foo6Fact])

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

smokeMiddlewareRuntime ::
  Architecture.Hanging (Architecture.HangingAction WorkflowFact Interceptor WorkflowProgram)
smokeMiddlewareRuntime =
  Architecture.hanging
    [ Architecture.middleware ReportMiddleware smokeMiddlewareBody
    ]

smokeMiddlewareFailureRuntime ::
  Architecture.Hanging (Architecture.HangingAction WorkflowFact Interceptor WorkflowProgram)
smokeMiddlewareFailureRuntime =
  Architecture.hanging
    [ Architecture.middleware ReportMiddleware smokeMiddlewareFailureBody
    ]

smokeMiddlewareBody :: WorkflowProgram
smokeMiddlewareBody = do
  runtime <- getRuntimeState
  if runtimeMiddlewareStack runtime == [ReportMiddleware]
    then programPlain (fact [AddCalculatedFact])
    else
      throwRuntimeError
        ( RuntimeIoException
            ( "middleware stack inactive: "
                ++ show (runtimeMiddlewareStack runtime)
            )
        )

smokeMiddlewareFailureBody :: WorkflowProgram
smokeMiddlewareFailureBody = do
  runtime <- getRuntimeState
  if runtimeMiddlewareStack runtime == [ReportMiddleware]
    then
      throwRuntimeError (RuntimeIoException "middleware target failed")
    else
      throwRuntimeError
        ( RuntimeIoException
            ( "middleware stack inactive before failure: "
                ++ show (runtimeMiddlewareStack runtime)
            )
        )
