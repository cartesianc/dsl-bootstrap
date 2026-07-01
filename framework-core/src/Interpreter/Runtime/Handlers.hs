module Interpreter.Runtime.Handlers
  ( defaultHandlerRegistry
  , defaultRuntimeEffectEnvironment
  , defaultTransformRegistry
  , emptyHandlerRegistry
  , emptyTransformRegistry
  , handlerFor
  , runtimeEffectEnvironment
  , runtimeEffectEnvironmentWithTransforms
  , runHandler
  , succeedHandler
  , transformFor
  ) where

import Effects.Names
  ( HandlerName (..)
  , SendName (..)
  , TransformName (..)
  , TypeName (..)
  )
import Interpreter.Runtime.Types
  ( HandlerBinding (..)
  , HandlerInput
  , HandlerRegistry (..)
  , HandlerResult (..)
  , Runtime
  , RuntimeEffectEnvironment (..)
  , RuntimeHandler (..)
  , RuntimeTransform (..)
  , RuntimeValue (..)
  , TransformBinding (..)
  , TransformRegistry (..)
  , ReportInputValue (..)
  , UserNameValue (..)
  , ValueTag (..)
  )

defaultHandlerRegistry :: HandlerRegistry
defaultHandlerRegistry =
  HandlerRegistry
    [ HandlerBinding AskUserName RuntimeAskUserName succeedHandler
    , HandlerBinding HandleUserNameError RuntimeHandleUserNameError succeedHandler
    , HandlerBinding RememberUser RuntimeRememberUser succeedHandler
    , HandlerBinding GenerateReport RuntimeGenerateReport succeedHandler
    , HandlerBinding WriteLog ConsoleLogHandler succeedHandler
    ]

emptyHandlerRegistry :: HandlerRegistry
emptyHandlerRegistry =
  HandlerRegistry []

defaultTransformRegistry :: TransformRegistry
defaultTransformRegistry =
  TransformRegistry
    [ TransformBinding
        UserNameToReportInput
        ( RuntimeTransform
            UserNameTag
            ReportInputTag
            ( \(UserNameValue text) ->
                ReportInputValue ("report-input:" ++ text)
            )
        )
    ]

emptyTransformRegistry :: TransformRegistry
emptyTransformRegistry =
  TransformRegistry []

defaultRuntimeEffectEnvironment :: RuntimeEffectEnvironment
defaultRuntimeEffectEnvironment =
  runtimeEffectEnvironment defaultHandlerRegistry

runtimeEffectEnvironment :: HandlerRegistry -> RuntimeEffectEnvironment
runtimeEffectEnvironment currentHandlers =
  runtimeEffectEnvironmentWithTransforms currentHandlers defaultTransformRegistry

runtimeEffectEnvironmentWithTransforms ::
  HandlerRegistry ->
  TransformRegistry ->
  RuntimeEffectEnvironment
runtimeEffectEnvironmentWithTransforms currentHandlers currentTransforms =
  RuntimeEffectEnvironment
    { runtimeEffectHandlers = currentHandlers
    , runtimeEffectTransforms = currentTransforms
    }

succeedHandler :: RuntimeHandler
succeedHandler =
  RuntimeHandler (\currentSend _ _ -> pure (HandlerSucceeded (defaultHandlerOutputs currentSend)))

defaultHandlerOutputs :: SendName -> [RuntimeValue]
defaultHandlerOutputs AskUserName =
  [RuntimeValue UserName "runtime-user"]
defaultHandlerOutputs GenerateReport =
  [RuntimeValue ReportOutput "runtime-report"]
defaultHandlerOutputs _ =
  []

handlerFor :: HandlerRegistry -> SendName -> Maybe HandlerBinding
handlerFor registry currentSend =
  firstJust
    [ Just currentBinding
    | currentBinding <- handlerRegistryBindings registry
    , handlerBindingSend currentBinding == currentSend
    ]

runHandler ::
  HandlerRegistry ->
  SendName ->
  HandlerInput ->
  Runtime ->
  IO HandlerResult
runHandler registry currentSend input runtime =
  case handlerFor registry currentSend of
    Just currentBinding ->
      runRuntimeHandler (handlerBindingHandler currentBinding) currentSend input runtime
    Nothing ->
      pure (HandlerFailed ("missing runtime handler for " ++ show currentSend))

transformFor :: TransformRegistry -> TransformName -> Maybe RuntimeTransform
transformFor registry currentTransform =
  firstJust
    [ Just (transformBindingTransform currentBinding)
    | currentBinding <- transformRegistryBindings registry
    , transformBindingName currentBinding == currentTransform
    ]

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest
