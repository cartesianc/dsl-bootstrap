module Domain.AppBlueprint
  ( AppBlueprint (..)
  , App
  , AppHanging
  , blueprint
  , app
  , hooks
  ) where

import Framework.Ast
  ( App
  , AppBlueprint (..)
  , AppHanging
  )
import Blueprint
import Plugins

blueprint :: AppBlueprint
blueprint =
  AppBlueprint
    { blueprintApp = app
    , blueprintHanging = hooks
    }

app :: App
app =
  chain
    [ lifecycleStart
    , userModule
    , reportModule
    , lifecycleEnd
    ]

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
    , reportShutdownCallback
    , reportSuspense
    , reportLoop
    ]

reportShutdownCallback :: HangingComponent
reportShutdownCallback =
  callback
    ShutdownFlow
    reportModule

reportSuspense :: HangingComponent
reportSuspense =
  suspense ReportModuleFlow
