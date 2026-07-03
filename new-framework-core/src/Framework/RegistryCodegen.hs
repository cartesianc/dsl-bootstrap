module Framework.RegistryCodegen
  ( EffectRegistryBinding (..)
  , GeneratedSource (..)
  , PluginRegistryBinding (..)
  , diffGeneratedLines
  , frameworkCoreFrontendSources
  , generatedLinesMatch
  , renderEffectsTheoryModule
  , renderFrameworkCoreBaseAppModule
  , renderFrameworkCoreCurrentAppModule
  , renderFrameworkCoreCurrentAstModule
  , renderFrameworkCoreCurrentEffectsModule
  , renderFrameworkCoreCurrentInterpreterModule
  , renderPluginsModule
  ) where

import Bootstrap.RegistryCodegen
  ( GeneratedSource (..)
  , frameworkCoreFrontendSources
  , renderFrameworkCoreBaseAppModule
  , renderFrameworkCoreCurrentAppModule
  , renderFrameworkCoreCurrentAstModule
  , renderFrameworkCoreCurrentEffectsModule
  , renderFrameworkCoreCurrentInterpreterModule
  )

data PluginRegistryBinding = PluginRegistryBinding
  { pluginRegistryBindingName :: String
  , pluginRegistryBindingModule :: String
  , pluginRegistryBindingSource :: String
  }
  deriving (Eq, Show)

data EffectRegistryBinding = EffectRegistryBinding
  { effectRegistryBindingModule :: String
  , effectRegistryBindingName :: String
  }
  deriving (Eq, Show)

renderPluginsModule :: [PluginRegistryBinding] -> [String]
renderPluginsModule bindings =
  [ "{-# OPTIONS_GHC -Wno-missing-export-lists #-}"
  , "{-# OPTIONS_GHC -Wno-missing-signatures #-}"
  , ""
  , "module Plugins"
  , "  where"
  , ""
  ]
    ++ map (("import qualified " ++) . pluginRegistryBindingModule) (uniqueOn pluginRegistryBindingModule bindings)
    ++ [""]
    ++
    [ pluginRegistryBindingName binding
        ++ " = "
        ++ pluginRegistryBindingModule binding
        ++ "."
        ++ pluginRegistryBindingSource binding
    | binding <- bindings
    ]

renderEffectsTheoryModule :: [EffectRegistryBinding] -> [String]
renderEffectsTheoryModule bindings =
  [ "{-# OPTIONS_GHC -Wno-missing-export-lists #-}"
  , "{-# OPTIONS_GHC -Wno-missing-signatures #-}"
  , ""
  , "module Effects.Theory"
  , "  ( effectTheory"
  , "  ) where"
  , ""
  , "import Framework.Effect"
  , "  ( EffectTheory"
  , "  , theory"
  , "  )"
  ]
    ++ map (("import qualified " ++) . effectRegistryBindingModule) bindings
    ++ [ ""
       , "effectTheory :: EffectTheory"
       , "effectTheory ="
       , "  theory"
       ]
    ++ renderEffectList bindings

generatedLinesMatch :: [String] -> [String] -> Bool
generatedLinesMatch expected actual =
  normalizeLines expected == normalizeLines actual

diffGeneratedLines :: [String] -> [String] -> [String]
diffGeneratedLines expected actual =
  [ "expected:"
  ]
    ++ numberedLines (normalizeLines expected)
    ++ [ "actual:"
       ]
    ++ numberedLines (normalizeLines actual)

renderEffectList :: [EffectRegistryBinding] -> [String]
renderEffectList [] =
  ["    []"]
renderEffectList (binding : rest) =
  ("    [ " ++ renderEffectBinding binding)
    : map (("    , " ++) . renderEffectBinding) rest
    ++ ["    ]"]

renderEffectBinding :: EffectRegistryBinding -> String
renderEffectBinding binding =
  effectRegistryBindingModule binding ++ "." ++ effectRegistryBindingName binding

normalizeLines :: [String] -> [String]
normalizeLines =
  dropTrailingBlank . map trimLineEnding

trimLineEnding :: String -> String
trimLineEnding line =
  case reverse line of
    '\r' : rest ->
      reverse rest
    _ ->
      line

dropTrailingBlank :: [String] -> [String]
dropTrailingBlank =
  reverse . dropWhile null . reverse

numberedLines :: [String] -> [String]
numberedLines linesToNumber =
  zipWith renderNumberedLine [(1 :: Int) ..] linesToNumber

renderNumberedLine :: Int -> String -> String
renderNumberedLine lineNumber line =
  show lineNumber ++ ": " ++ line

uniqueOn :: Eq key => (item -> key) -> [item] -> [item]
uniqueOn keyFor =
  foldl appendUnique []
  where
    appendUnique items item
      | keyFor item `elem` map keyFor items =
          items
      | otherwise =
          items ++ [item]
