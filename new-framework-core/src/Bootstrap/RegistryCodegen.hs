module Bootstrap.RegistryCodegen
  ( GeneratedSource (..)
  , diffGeneratedLines
  , frameworkCoreFrontendSources
  , generatedLinesMatch
  , renderFrameworkCoreBaseAppModule
  , renderFrameworkCoreCurrentAppModule
  , renderFrameworkCoreCurrentAstModule
  , renderFrameworkCoreCurrentEffectsModule
  , renderFrameworkCoreCurrentInterpreterModule
  ) where

data GeneratedSource = GeneratedSource
  { generatedSourcePath :: FilePath
  , generatedSourceLines :: [String]
  }
  deriving (Eq, Show)

frameworkCoreFrontendSources :: [GeneratedSource]
frameworkCoreFrontendSources =
  [ GeneratedSource "new-framework-core/src/FrameworkCore/BaseApp.hs" renderFrameworkCoreBaseAppModule
  , GeneratedSource "new-framework-core/src/FrameworkCore/CurrentAst.hs" renderFrameworkCoreCurrentAstModule
  , GeneratedSource "new-framework-core/src/FrameworkCore/CurrentEffects.hs" renderFrameworkCoreCurrentEffectsModule
  , GeneratedSource "new-framework-core/src/FrameworkCore/CurrentInterpreter.hs" renderFrameworkCoreCurrentInterpreterModule
  , GeneratedSource "new-framework-core/src/FrameworkCore/CurrentApp.hs" renderFrameworkCoreCurrentAppModule
  ]

renderFrameworkCoreBaseAppModule :: [String]
renderFrameworkCoreBaseAppModule =
  [ "module FrameworkCore.BaseApp"
  , "  ( FrameworkCoreInterpreter (..)"
  , "  , FrameworkCoreTrustBase (..)"
  , "  , baseApp"
  , "  , currentTrustBase"
  , "  ) where"
  , ""
  , "import Framework.Ast"
  , "  ( AppBlueprint )"
  , "import Framework.Effect"
  , "  ( EffectTheory"
  , "  )"
  , "import Framework.TrustBase"
  , "  ( TrustBaseRuntimeEffectEnvironment"
  , "  , bootstrapRuntimeEffectEnvironment"
  , "  )"
  , ""
  , "data FrameworkCoreTrustBase = FrameworkCoreTrustBase"
  , "  { trustBaseName :: String"
  , "  , trustBaseRuntime :: TrustBaseRuntimeEffectEnvironment"
  , "  }"
  , ""
  , "data FrameworkCoreInterpreter = FrameworkCoreInterpreter"
  , "  { frameworkCoreInterpreterName :: String"
  , "  , runFrameworkCoreInterpreter :: FrameworkCoreTrustBase -> AppBlueprint -> EffectTheory -> IO ()"
  , "  }"
  , ""
  , "currentTrustBase :: FrameworkCoreTrustBase"
  , "currentTrustBase ="
  , "  FrameworkCoreTrustBase"
  , "    { trustBaseName = \"bootstrap-kernel\""
  , "    , trustBaseRuntime = bootstrapRuntimeEffectEnvironment"
  , "    }"
  , ""
  , "baseApp :: FrameworkCoreTrustBase -> FrameworkCoreInterpreter -> AppBlueprint -> EffectTheory -> IO ()"
  , "baseApp trustBase interpreter ast effects ="
  , "  runFrameworkCoreInterpreter interpreter trustBase ast effects"
  ]

renderFrameworkCoreCurrentAstModule :: [String]
renderFrameworkCoreCurrentAstModule =
  [ "module FrameworkCore.CurrentAst"
  , "  ( currentAst"
  , "  ) where"
  , ""
  , "import Domain.AppBlueprint"
  , "  ( frameworkCoreBlueprint"
  , "  )"
  , "import Framework.Ast"
  , "  ( AppBlueprint"
  , "  )"
  , ""
  , "currentAst :: AppBlueprint"
  , "currentAst ="
  , "  frameworkCoreBlueprint"
  ]

renderFrameworkCoreCurrentEffectsModule :: [String]
renderFrameworkCoreCurrentEffectsModule =
  [ "module FrameworkCore.CurrentEffects"
  , "  ( currentEffects"
  , "  ) where"
  , ""
  , "import Domain.Effects"
  , "  ( frameworkCoreEffects"
  , "  )"
  , "import Framework.Effect"
  , "  ( EffectTheory"
  , "  )"
  , ""
  , "currentEffects :: EffectTheory"
  , "currentEffects ="
  , "  frameworkCoreEffects"
  ]

renderFrameworkCoreCurrentInterpreterModule :: [String]
renderFrameworkCoreCurrentInterpreterModule =
  [ "module FrameworkCore.CurrentInterpreter"
  , "  ( currentInterpreter"
  , "  ) where"
  , ""
  , "import Framework.Ast"
  , "  ( AppBlueprint"
  , "  )"
  , "import Framework.Effect"
  , "  ( EffectTheory"
  , "  )"
  , "import Framework.TrustBase"
  , "  ( runNativeBlueprintWithEffectEnvironment"
  , "  )"
  , "import FrameworkCore.BaseApp"
  , "  ( FrameworkCoreInterpreter (..)"
  , "  , FrameworkCoreTrustBase (..)"
  , "  )"
  , ""
  , "currentInterpreter :: FrameworkCoreInterpreter"
  , "currentInterpreter ="
  , "  FrameworkCoreInterpreter"
  , "    { frameworkCoreInterpreterName = \"bootstrap-native-runtime\""
  , "    , runFrameworkCoreInterpreter = runWithTrustBase"
  , "    }"
  , ""
  , "runWithTrustBase :: FrameworkCoreTrustBase -> AppBlueprint -> EffectTheory -> IO ()"
  , "runWithTrustBase trustBase ast effects ="
  , "  runNativeBlueprintWithEffectEnvironment (trustBaseRuntime trustBase) effects ast"
  ]

renderFrameworkCoreCurrentAppModule :: [String]
renderFrameworkCoreCurrentAppModule =
  [ "module FrameworkCore.CurrentApp"
  , "  ( frameworkCoreApp"
  , "  ) where"
  , ""
  , "import FrameworkCore.BaseApp"
  , "  ( baseApp"
  , "  , currentTrustBase"
  , "  )"
  , "import FrameworkCore.CurrentAst"
  , "  ( currentAst"
  , "  )"
  , "import FrameworkCore.CurrentEffects"
  , "  ( currentEffects"
  , "  )"
  , "import FrameworkCore.CurrentInterpreter"
  , "  ( currentInterpreter"
  , "  )"
  , ""
  , "frameworkCoreApp :: IO ()"
  , "frameworkCoreApp ="
  , "  baseApp currentTrustBase currentInterpreter currentAst currentEffects"
  ]

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
