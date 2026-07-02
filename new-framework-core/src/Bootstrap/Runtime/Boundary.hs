module Bootstrap.Runtime.Boundary
  ( checkNativeCoreBoundary
  , checkNativeElaborationContract
  , checkNativeFrontendBoundary
  , checkNativeLanguageSpec
  , frameworkCoreSourceRoots
  , frontendBoundaryRoots
  , packageSourceRoots
  ) where

import Data.List
  ( isPrefixOf
  , isSuffixOf
  , sort
  )
import System.FilePath
  ( normalise )

import qualified Bootstrap.CoreSurface as CoreSurface
import Bootstrap.Runtime.SourceGraph
  ( SourceImportGraph (..)
  , SourceModule (..)
  )

checkNativeCoreBoundary :: SourceImportGraph -> [String]
checkNativeCoreBoundary graph =
  duplicateSliceErrors
    ++ unknownDependencyErrors
    ++ runtimeLeakErrors
    ++ importBoundaryErrors graph

duplicateSliceErrors :: [String]
duplicateSliceErrors =
  [ "duplicate core slice " ++ currentSlice
  | currentSlice <- duplicates (map CoreSurface.coreSurfaceSliceName CoreSurface.coreSurfaceSlices)
  ]

unknownDependencyErrors :: [String]
unknownDependencyErrors =
  [ "unknown core dependency " ++ dependency ++ " required by " ++ CoreSurface.coreSurfaceSliceName currentSlice
  | currentSlice <- CoreSurface.coreSurfaceSlices
  , dependency <- CoreSurface.coreSurfaceSliceDependsOn currentSlice
  , dependency `notElem` sliceNames
  ]
  where
    sliceNames =
      map CoreSurface.coreSurfaceSliceName CoreSurface.coreSurfaceSlices

runtimeLeakErrors :: [String]
runtimeLeakErrors =
  [ "non-runtime slice " ++ CoreSurface.coreSurfaceSliceName currentSlice ++ " depends on runtime slice " ++ dependency
  | currentSlice <- CoreSurface.coreSurfaceSlices
  , CoreSurface.coreSurfaceSliceRole currentSlice /= "runtime-backend"
  , dependency <- CoreSurface.coreSurfaceSliceDependsOn currentSlice
  , dependency `elem` runtimeSliceNames
  ]
  where
    runtimeSliceNames =
      [ CoreSurface.coreSurfaceSliceName currentSlice
      | currentSlice <- CoreSurface.coreSurfaceSlices
      , CoreSurface.coreSurfaceSliceRole currentSlice == "runtime-backend"
      ]

importBoundaryErrors :: SourceImportGraph -> [String]
importBoundaryErrors graph =
  [ "undeclared core import "
      ++ sourceModuleName currentModule
      ++ " -> "
      ++ currentImport
      ++ " ("
      ++ sourceSlice
      ++ " cannot depend on "
      ++ targetSlice
      ++ ")"
  | currentModule <- sourceImportModules graph
  , Just sourceSlice <- [sliceForModule (sourceModuleName currentModule)]
  , currentImport <- sourceModuleImports currentModule
  , Just targetSlice <- [sliceForModule currentImport]
  , sourceSlice /= targetSlice
  , targetSlice `notElem` dependenciesForSlice sourceSlice
  ]

sliceForModule :: String -> Maybe String
sliceForModule currentModule =
  firstJust
    [ Just (CoreSurface.coreSurfaceSliceName currentSlice)
    | currentSlice <- CoreSurface.coreSurfaceSlices
    , currentModule `elem` expandedSliceModules currentSlice
    ]

expandedSliceModules :: CoreSurface.CoreSurfaceSlice -> [String]
expandedSliceModules currentSlice =
  concatMap expandSliceModule (CoreSurface.coreSurfaceSliceModules currentSlice)

expandSliceModule :: String -> [String]
expandSliceModule "Interpreter.Runtime.Workflow.*" =
  [ "Interpreter.Runtime.Workflow.Choice"
  , "Interpreter.Runtime.Workflow.FreeAlternative"
  , "Interpreter.Runtime.Workflow.FreeApplicative"
  , "Interpreter.Runtime.Workflow.FreeMonad"
  , "Interpreter.Runtime.Workflow.Node"
  , "Interpreter.Runtime.Workflow.Wait"
  ]
expandSliceModule currentModule =
  [currentModule]

dependenciesForSlice :: String -> [String]
dependenciesForSlice sliceName =
  transitiveSliceDependencies [] (directDependenciesForSlice sliceName)

transitiveSliceDependencies :: [String] -> [String] -> [String]
transitiveSliceDependencies seen [] =
  seen
transitiveSliceDependencies seen (sliceName : rest)
  | sliceName `elem` seen =
      transitiveSliceDependencies seen rest
  | otherwise =
      transitiveSliceDependencies
        (seen ++ [sliceName])
        (rest ++ directDependenciesForSlice sliceName)

directDependenciesForSlice :: String -> [String]
directDependenciesForSlice sliceName =
  concat
    [ CoreSurface.coreSurfaceSliceDependsOn currentSlice
    | currentSlice <- CoreSurface.coreSurfaceSlices
    , CoreSurface.coreSurfaceSliceName currentSlice == sliceName
    ]

checkNativeFrontendBoundary :: SourceImportGraph -> [String]
checkNativeFrontendBoundary graph =
  [ "forbidden frontend import: "
      ++ sourceModulePath currentModule
      ++ " imports "
      ++ currentImport
  | currentModule <- sourceImportModules graph
  , not (isExcludedFrontendPath (sourceModulePath currentModule))
  , currentImport <- sourceModuleImports currentModule
  , isForbiddenFrontendImportFor (sourceModulePath currentModule) currentImport
      || not (isAllowedFrontendImportFor (sourceModulePath currentModule) currentImport)
  ]

checkNativeLanguageSpec :: [String]
checkNativeLanguageSpec =
  missingCapabilities
    "language spec"
    [ "chain"
    , "parallel"
    , "wait"
    , "fact"
    , "externalMake"
    , "take"
    , "make"
    , "buildApp"
    ]

checkNativeElaborationContract :: [String]
checkNativeElaborationContract =
  missingCapabilities
    "elaboration contract"
    [ "Framework.Workflow"
    , "Framework.Effect"
    , "Framework.Hylo"
    , "Framework.Runtime"
    , "Core.App"
    ]

missingCapabilities :: String -> [String] -> [String]
missingCapabilities label names =
  [ label ++ " missing expressed capability " ++ name
  | name <- names
  , not (any (contains name) expressedNames)
  ]
  where
    expressedNames =
      map (CoreSurface.capabilityName . snd) CoreSurface.coreSurfaceCapabilities
        ++ map CoreSurface.surfaceModuleName CoreSurface.coreSurfaceModules

packageSourceRoots :: [FilePath]
packageSourceRoots =
  [ "new-framework-core/src"
  , "domain-app/src"
  ]

frameworkCoreSourceRoots :: [FilePath]
frameworkCoreSourceRoots =
  [ "new-framework-core/src"
  ]

frontendBoundaryRoots :: [FilePath]
frontendBoundaryRoots =
  [ "new-framework-core/app/Main.hs"
  , "new-framework-core/src/Bootstrap"
  , "new-framework-core/src/Domain"
  ]

isExcludedFrontendPath :: FilePath -> Bool
isExcludedFrontendPath path =
  any (`isSuffixOf` normalise path)
    [ normalise "new-framework-core/src/Bootstrap/Runtime.hs"
    , normalise "new-framework-core/src/Bootstrap/Runtime/Boundary.hs"
    , normalise "new-framework-core/src/Bootstrap/Runtime/SourceGraph.hs"
    , normalise "new-framework-core/src/Bootstrap/Report.hs"
    , normalise "new-framework-core/src/Domain/EffectHandlers.hs"
    , normalise "new-framework-core/src/Domain/Interpreter.hs"
    , normalise "new-framework-core/src/Domain/Registry.hs"
    ]

isAllowedFrontendImport :: String -> Bool
isAllowedFrontendImport currentImport =
  currentImport
    `elem`
      [ "Bootstrap.Blueprint"
      , "Bootstrap.CoreSurface"
      , "Bootstrap.Effect"
      , "Bootstrap.Effects"
      , "Bootstrap.Runtime.Boundary"
      , "Bootstrap.Runtime.SourceGraph"
      , "Bootstrap.Runtime.Types"
      , "Bootstrap.Vocabulary"
      , "Bootstrap.Workflow"
      , "Blueprint"
      , "Domain.Ast"
      , "Domain.AppBlueprint"
      , "Domain.Effects"
      , "Domain.Registry"
      , "Domain.Vocabulary"
      , "Prelude"
      ]
    || "Bootstrap.Effects." `isPrefixOf` currentImport
    || "Bootstrap.Runtime." `isPrefixOf` currentImport

isAllowedFrontendImportFor :: FilePath -> String -> Bool
isAllowedFrontendImportFor path currentImport =
  isAllowedFrontendImport currentImport
    || (isSelfDomainExpressionPath path && currentImport `elem` selfDomainFacadeImports)

isForbiddenFrontendImport :: String -> Bool
isForbiddenFrontendImport currentImport =
  any (`matchesModule` currentImport)
    [ "Core"
    , "Core."
    , "AST"
    , "AST."
    , "Interpreter"
    , "Interpreter."
    , "Framework.Workflow"
    , "Framework.Effect"
    , "Framework.Background"
    , "Framework.Background."
    , "Effects.EffectTheory"
    , "Effects.Names"
    ]

isForbiddenFrontendImportFor :: FilePath -> String -> Bool
isForbiddenFrontendImportFor path currentImport
  | isSelfDomainExpressionPath path && currentImport `elem` selfDomainFacadeImports =
      False
  | otherwise =
      isForbiddenFrontendImport currentImport

selfDomainFacadeImports :: [String]
selfDomainFacadeImports =
  [ "Framework.Workflow"
  , "Framework.Effect"
  , "Domain.Vocabulary"
  ]

isSelfDomainExpressionPath :: FilePath -> Bool
isSelfDomainExpressionPath path =
  normalise "new-framework-core/src/Domain" `isPrefixOf` normalise path

matchesModule :: String -> String -> Bool
matchesModule modulePattern currentImport
  | "." `isSuffixOf` modulePattern =
      modulePattern `isPrefixOf` currentImport
  | otherwise =
      modulePattern == currentImport

duplicates :: Ord item => [item] -> [item]
duplicates =
  map head . filter multiple . groupSorted . sort
  where
    multiple (_ : _ : _) =
      True
    multiple _ =
      False

groupSorted :: Eq item => [item] -> [[item]]
groupSorted [] =
  []
groupSorted (item : rest) =
  let (same, different) =
        span (== item) rest
   in (item : same) : groupSorted different

contains :: String -> String -> Bool
contains needle haystack =
  needle `isPrefixOf` haystack || containsInfix needle haystack

containsInfix :: String -> String -> Bool
containsInfix needle haystack
  | needle == haystack =
      True
  | null haystack =
      False
  | needle `isPrefixOf` haystack =
      True
  | otherwise =
      containsInfix needle (tail haystack)

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (currentItem : rest) =
  case currentItem of
    Just item ->
      Just item
    Nothing ->
      firstJust rest
