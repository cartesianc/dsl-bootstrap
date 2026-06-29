module Interpreter.Runtime.Handlers
  ( defaultHandlerRegistry
  , defaultRuntimeEffectEnvironment
  , emptyHandlerRegistry
  , handlerFor
  , runtimeEffectEnvironment
  , runHandler
  , succeedHandler
  ) where

import Effects.Names
  ( ImplementationName (..)
  , ProfileName (..)
  , SendName
  )
import Interpreter.Runtime.Types
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , Runtime
  , RuntimeEffectEnvironment (..)
  , RuntimeHandler (..)
  )

defaultHandlerRegistry :: HandlerRegistry
defaultHandlerRegistry =
  HandlerRegistry
    [ HandlerBinding RuntimeAskUserName succeedHandler
    , HandlerBinding RuntimeRememberUser succeedHandler
    , HandlerBinding RuntimeGenerateReport succeedHandler
    , HandlerBinding ConsoleLogHandler succeedHandler
    , HandlerBinding MockAskUserName succeedHandler
    , HandlerBinding MockRememberUser succeedHandler
    , HandlerBinding MockReportHandler succeedHandler
    , HandlerBinding MockLogHandler succeedHandler
    ]

emptyHandlerRegistry :: HandlerRegistry
emptyHandlerRegistry =
  HandlerRegistry []

defaultRuntimeEffectEnvironment :: RuntimeEffectEnvironment
defaultRuntimeEffectEnvironment =
  runtimeEffectEnvironment Production defaultHandlerRegistry

runtimeEffectEnvironment :: ProfileName -> HandlerRegistry -> RuntimeEffectEnvironment
runtimeEffectEnvironment =
  RuntimeEffectEnvironment

succeedHandler :: RuntimeHandler
succeedHandler =
  RuntimeHandler (\_ _ -> pure HandlerSucceeded)

handlerFor :: HandlerRegistry -> ImplementationName -> Maybe RuntimeHandler
handlerFor registry currentImplementation =
  firstJust
    [ Just (handlerBindingHandler currentBinding)
    | currentBinding <- handlerRegistryBindings registry
    , handlerBindingName currentBinding == currentImplementation
    ]

runHandler ::
  HandlerRegistry ->
  ImplementationName ->
  SendName ->
  Runtime ->
  IO HandlerResult
runHandler registry currentImplementation currentSend runtime =
  case handlerFor registry currentImplementation of
    Just currentHandler ->
      runRuntimeHandler currentHandler currentSend runtime
    Nothing ->
      pure (HandlerFailed ("missing runtime handler " ++ show currentImplementation))

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest
