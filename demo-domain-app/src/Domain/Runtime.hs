module Domain.Runtime
  ( domainHandlerRegistry
  , domainRuntimeEffectEnvironment
  , domainTransformRegistry
  ) where

import Domain.EffectVocabulary
import Framework.Background
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , NativeHandler (..)
  , RuntimeArtifact (..)
  , RuntimeEffectEnvironment
  , TransformRegistry
  , emptyTransformRegistry
  , runtimeEffectEnvironmentWithTransforms
  )
import Framework.Effect
  ( SendName )

domainRuntimeEffectEnvironment :: RuntimeEffectEnvironment
domainRuntimeEffectEnvironment =
  runtimeEffectEnvironmentWithTransforms domainHandlerRegistry domainTransformRegistry

domainHandlerRegistry :: HandlerRegistry
domainHandlerRegistry =
  HandlerRegistry
    [ HandlerBinding AskUserName RuntimeAskUserName domainSucceedHandler
    , HandlerBinding HandleUserNameError RuntimeHandleUserNameError domainSucceedHandler
    , HandlerBinding RememberUser RuntimeRememberUser domainSucceedHandler
    , HandlerBinding GenerateReport RuntimeGenerateReport domainSucceedHandler
    , HandlerBinding WriteLog ConsoleLogHandler domainSucceedHandler
    ]

domainTransformRegistry :: TransformRegistry
domainTransformRegistry =
  emptyTransformRegistry

domainSucceedHandler :: NativeHandler
domainSucceedHandler =
  NativeHandler (\currentSend _ _ -> pure (domainDefaultHandlerResult currentSend))

domainDefaultHandlerResult :: SendName -> HandlerResult
domainDefaultHandlerResult AskUserName =
  HandlerSucceeded
    [RuntimeArtifact UserName "runtime-user"]
domainDefaultHandlerResult GenerateReport =
  HandlerSucceeded
    [RuntimeArtifact ReportOutput "runtime-report"]
domainDefaultHandlerResult _ =
  HandlerSucceeded []

