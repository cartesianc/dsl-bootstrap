module Domain.RegistryCodegenSpec
  ( expectedEffectsTheoryLines
  , expectedPluginsLines
  , effectRegistryBindings
  , pluginRegistryBindings
  ) where

import Framework.RegistryCodegen
  ( EffectRegistryBinding (..)
  , PluginRegistryBinding (..)
  , renderEffectsTheoryModule
  , renderPluginsModule
  )

pluginRegistryBindings :: [PluginRegistryBinding]
pluginRegistryBindings =
  [ PluginRegistryBinding "bootHook" "Plugins.Boot" "bootHook"
  , PluginRegistryBinding "bootModule" "Plugins.Boot" "bootModule"
  , PluginRegistryBinding "runtimeHook" "Plugins.Boot" "runtimeHook"
  , PluginRegistryBinding "configurationHook" "Plugins.Configuration" "configurationHook"
  , PluginRegistryBinding "configurationModule" "Plugins.Configuration" "configurationModule"
  , PluginRegistryBinding "onboarding" "Plugins.Handle" "onboarding"
  , PluginRegistryBinding "userHook" "Plugins.Handle" "userHook"
  , PluginRegistryBinding "userModule" "Plugins.Handle" "userModule"
  , PluginRegistryBinding "lifecycleEnd" "Plugins.Lifecycle" "lifecycleEnd"
  , PluginRegistryBinding "lifecycleStart" "Plugins.Lifecycle" "lifecycleStart"
  , PluginRegistryBinding "loggingHook" "Plugins.Logging" "loggingHook"
  , PluginRegistryBinding "calculationReport" "Plugins.Report" "calculationReport"
  , PluginRegistryBinding "reportHook" "Plugins.Report" "reportHook"
  , PluginRegistryBinding "reportLoop" "Plugins.Report" "reportLoop"
  , PluginRegistryBinding "reportModule" "Plugins.Report" "reportModule"
  , PluginRegistryBinding "shutdownHook" "Plugins.Shutdown" "shutdownHook"
  , PluginRegistryBinding "shutdownModule" "Plugins.Shutdown" "shutdownModule"
  ]

effectRegistryBindings :: [EffectRegistryBinding]
effectRegistryBindings =
  [ EffectRegistryBinding "Effects.Logging" "loggingEffect"
  , EffectRegistryBinding "Effects.Report" "reportEffect"
  , EffectRegistryBinding "Effects.System" "systemEffect"
  , EffectRegistryBinding "Effects.User" "userEffect"
  ]

expectedPluginsLines :: [String]
expectedPluginsLines =
  renderPluginsModule pluginRegistryBindings

expectedEffectsTheoryLines :: [String]
expectedEffectsTheoryLines =
  renderEffectsTheoryModule effectRegistryBindings
