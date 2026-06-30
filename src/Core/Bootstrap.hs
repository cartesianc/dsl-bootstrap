module Core.Bootstrap
  ( BootstrapPhase (..)
  , CoreBoundary (..)
  , CoreBoundaryError (..)
  , CoreSlice (..)
  , CoreSliceName (..)
  , CoreSliceRole (..)
  , checkCoreBoundary
  , coreBoundaryPassed
  , coreSlicesForPhase
  , defaultCoreBoundary
  , renderBootstrapPhase
  , renderCoreBoundary
  , renderCoreBoundaryError
  , renderCoreSlice
  , renderCoreSliceName
  , renderCoreSliceRole
  ) where

data BootstrapPhase
  = MinimalCoreFreeze
  | SmtBackendPhase
  | SelfBootstrapPhase
  deriving (Eq, Show)

data CoreSliceRole
  = PureCore
  | FrontendFacade
  | VerificationBackend
  | RuntimeBackend
  deriving (Eq, Show)

data CoreSliceName
  = CoreSyntax
  | CoreLanguageSpec
  | CoreRecursion
  | CoreHylo
  | CoreEffectTheory
  | CoreAppBuild
  | CoreConstraintIR
  | CoreProofBoundary
  | CoreSmtBackend
  | CoreFrontendFacade
  | CoreFrontendBoundary
  | CoreRuntimeAdapter
  deriving (Eq, Show)

data CoreSlice = CoreSlice
  { coreSliceName :: CoreSliceName
  , coreSliceRole :: CoreSliceRole
  , coreSlicePhase :: BootstrapPhase
  , coreSliceModules :: [String]
  , coreSliceDependsOn :: [CoreSliceName]
  , coreSlicePurpose :: String
  }
  deriving (Eq, Show)

newtype CoreBoundary = CoreBoundary
  { coreBoundarySlices :: [CoreSlice]
  }
  deriving (Eq, Show)

data CoreBoundaryError
  = DuplicateCoreSlice CoreSliceName
  | UnknownCoreDependency CoreSliceName CoreSliceName
  | RuntimeDependencyLeak CoreSliceName CoreSliceName
  | CoreDependencyCycle [CoreSliceName]
  deriving (Eq, Show)

defaultCoreBoundary :: CoreBoundary
defaultCoreBoundary =
  CoreBoundary
    [ CoreSlice
        { coreSliceName = CoreSyntax
        , coreSliceRole = PureCore
        , coreSlicePhase = MinimalCoreFreeze
        , coreSliceModules =
            [ "Core.Architecture"
            , "Core.Architecture.Internal"
            , "Core.Architecture.Cata.Types"
            ]
        , coreSliceDependsOn = []
        , coreSlicePurpose = "workflow and hanging AST vocabulary"
        }
    , CoreSlice
        { coreSliceName = CoreLanguageSpec
        , coreSliceRole = PureCore
        , coreSlicePhase = MinimalCoreFreeze
        , coreSliceModules =
            [ "Core.Language"
            , "Core.Language.Spec"
            , "Core.Language.Validation"
            , "Core.Language.Constraint"
            , "Core.Language.Elaboration"
            ]
        , coreSliceDependsOn = []
        , coreSlicePurpose = "frontend keyword contracts, argument shapes, parent contexts, lowering targets, and elaborator bindings"
        }
    , CoreSlice
        { coreSliceName = CoreRecursion
        , coreSliceRole = PureCore
        , coreSlicePhase = MinimalCoreFreeze
        , coreSliceModules =
            [ "Core.Architecture.Cata"
            , "Core.Architecture.Recursion"
            , "Core.Workflow.Eff"
            , "Core.Workflow.Semantics"
            , "Core.Workflow.Semantics.Render"
            ]
        , coreSliceDependsOn = [CoreSyntax]
        , coreSlicePurpose = "fold/unfold compatible workflow lowering and interpretation algebra surface"
        }
    , CoreSlice
        { coreSliceName = CoreHylo
        , coreSliceRole = PureCore
        , coreSlicePhase = MinimalCoreFreeze
        , coreSliceModules =
            [ "Core.App.Ana"
            ]
        , coreSliceDependsOn = [CoreSyntax, CoreEffectTheory]
        , coreSlicePurpose = "seed and coalgebra entry for restoring or generating app/effect declarations"
        }
    , CoreSlice
        { coreSliceName = CoreEffectTheory
        , coreSliceRole = PureCore
        , coreSlicePhase = MinimalCoreFreeze
        , coreSliceModules =
            [ "Effects.EffectTheory"
            , "Effects.Names"
            , "Core.Effect.Semantics"
            ]
        , coreSliceDependsOn = []
        , coreSlicePurpose = "effect declarations, take/make semantics, profile contracts, and handler contracts"
        }
    , CoreSlice
        { coreSliceName = CoreAppBuild
        , coreSliceRole = PureCore
        , coreSlicePhase = MinimalCoreFreeze
        , coreSliceModules =
            [ "Core.Validation"
            , "Core.App"
            ]
        , coreSliceDependsOn = [CoreSyntax, CoreEffectTheory]
        , coreSlicePurpose = "build AppPlan from blueprint and effect theory, including AST and effect completeness checks"
        }
    , CoreSlice
        { coreSliceName = CoreConstraintIR
        , coreSliceRole = PureCore
        , coreSlicePhase = MinimalCoreFreeze
        , coreSliceModules =
            [ "Core.Effect.Constraint"
            ]
        , coreSliceDependsOn = [CoreSyntax, CoreEffectTheory, CoreAppBuild]
        , coreSlicePurpose = "constraint facts and local validation evidence extracted from AppPlan"
        }
    , CoreSlice
        { coreSliceName = CoreProofBoundary
        , coreSliceRole = VerificationBackend
        , coreSlicePhase = MinimalCoreFreeze
        , coreSliceModules =
            [ "Core.App.Boundary"
            ]
        , coreSliceDependsOn = [CoreAppBuild, CoreConstraintIR, CoreHylo]
        , coreSlicePurpose = "minimal core report that joins AppPlan and Constraint IR for proof and bootstrap"
        }
    , CoreSlice
        { coreSliceName = CoreSmtBackend
        , coreSliceRole = VerificationBackend
        , coreSlicePhase = SmtBackendPhase
        , coreSliceModules =
            [ "Core.Effect.Constraint.SMT"
            ]
        , coreSliceDependsOn = [CoreProofBoundary]
        , coreSlicePurpose = "SMT/proof backend adapter over the minimal core report"
        }
    , CoreSlice
        { coreSliceName = CoreFrontendFacade
        , coreSliceRole = FrontendFacade
        , coreSlicePhase = MinimalCoreFreeze
        , coreSliceModules =
            [ "Blueprint"
            , "Framework.Workflow"
            , "Framework.Effect"
            , "Framework.Hylo"
            ]
        , coreSliceDependsOn = [CoreSyntax, CoreLanguageSpec, CoreEffectTheory, CoreHylo]
        , coreSlicePurpose = "public frontend import surface for workflow, effect, and hylo declarations"
        }
    , CoreSlice
        { coreSliceName = CoreFrontendBoundary
        , coreSliceRole = VerificationBackend
        , coreSlicePhase = MinimalCoreFreeze
        , coreSliceModules =
            [ "Core.Boundary.Frontend"
            ]
        , coreSliceDependsOn = [CoreFrontendFacade]
        , coreSlicePurpose = "frontend import boundary IR and checker for the public facade"
        }
    , CoreSlice
        { coreSliceName = CoreRuntimeAdapter
        , coreSliceRole = RuntimeBackend
        , coreSlicePhase = SelfBootstrapPhase
        , coreSliceModules =
            [ "Interpreter.Runtime.Types"
            , "Interpreter.Runtime.Monad"
            , "Interpreter.Runtime.Contextware"
            , "Interpreter.Runtime.Algebra"
            , "Interpreter.Runtime.Ensure"
            , "Interpreter.Runtime.Handlers"
            , "Interpreter.Runtime.Middleware"
            , "Interpreter.Runtime.Hanging.FreeMonoid"
            , "Interpreter.Runtime.Workflow.*"
            , "Interpreter.Runtime"
            ]
        , coreSliceDependsOn = [CoreRecursion, CoreEffectTheory, CoreAppBuild]
        , coreSlicePurpose = "runtime adapter for executing the frozen core through RuntimeM and handlers"
        }
    ]

checkCoreBoundary :: CoreBoundary -> [CoreBoundaryError]
checkCoreBoundary boundary =
  unique
    ( duplicateSliceErrors slices
        ++ unknownDependencyErrors slices
        ++ runtimeLeakErrors slices
        ++ dependencyCycleErrors slices
    )
  where
    slices =
      coreBoundarySlices boundary

coreBoundaryPassed :: CoreBoundary -> Bool
coreBoundaryPassed =
  null . checkCoreBoundary

coreSlicesForPhase :: BootstrapPhase -> CoreBoundary -> [CoreSlice]
coreSlicesForPhase phase boundary =
  [ currentSlice
  | currentSlice <- coreBoundarySlices boundary
  , coreSlicePhase currentSlice == phase
  ]

duplicateSliceErrors :: [CoreSlice] -> [CoreBoundaryError]
duplicateSliceErrors slices =
  map DuplicateCoreSlice (duplicates (map coreSliceName slices))

unknownDependencyErrors :: [CoreSlice] -> [CoreBoundaryError]
unknownDependencyErrors slices =
  [ UnknownCoreDependency (coreSliceName currentSlice) currentDependency
  | currentSlice <- slices
  , currentDependency <- coreSliceDependsOn currentSlice
  , currentDependency `notElem` names
  ]
  where
    names =
      map coreSliceName slices

runtimeLeakErrors :: [CoreSlice] -> [CoreBoundaryError]
runtimeLeakErrors slices =
  [ RuntimeDependencyLeak (coreSliceName currentSlice) currentDependency
  | currentSlice <- slices
  , coreSliceRole currentSlice /= RuntimeBackend
  , currentDependency <- coreSliceDependsOn currentSlice
  , currentDependency `elem` runtimeSlices
  ]
  where
    runtimeSlices =
      [ coreSliceName currentSlice
      | currentSlice <- slices
      , coreSliceRole currentSlice == RuntimeBackend
      ]

dependencyCycleErrors :: [CoreSlice] -> [CoreBoundaryError]
dependencyCycleErrors slices =
  map CoreDependencyCycle (unique (concatMap (cyclesFrom slices []) (map coreSliceName slices)))

cyclesFrom :: [CoreSlice] -> [CoreSliceName] -> CoreSliceName -> [[CoreSliceName]]
cyclesFrom slices stack currentName
  | currentName `elem` stack =
      [reverse (currentName : takeUntil currentName stack)]
  | otherwise =
      case sliceByName slices currentName of
        Nothing ->
          []
        Just currentSlice ->
          concatMap (cyclesFrom slices (currentName : stack)) (coreSliceDependsOn currentSlice)

sliceByName :: [CoreSlice] -> CoreSliceName -> Maybe CoreSlice
sliceByName [] _ =
  Nothing
sliceByName (currentSlice : rest) currentName
  | coreSliceName currentSlice == currentName =
      Just currentSlice
  | otherwise =
      sliceByName rest currentName

renderCoreBoundary :: CoreBoundary -> String
renderCoreBoundary boundary =
  joinWith "\n\n" (map renderCoreSlice (coreBoundarySlices boundary))

renderCoreSlice :: CoreSlice -> String
renderCoreSlice currentSlice =
  joinWith
    "\n"
    [ renderCoreSliceName (coreSliceName currentSlice)
    , "  role: " ++ renderCoreSliceRole (coreSliceRole currentSlice)
    , "  phase: " ++ renderBootstrapPhase (coreSlicePhase currentSlice)
    , "  dependsOn: " ++ renderDependencies (coreSliceDependsOn currentSlice)
    , "  modules: " ++ joinWith ", " (coreSliceModules currentSlice)
    , "  purpose: " ++ coreSlicePurpose currentSlice
    ]

renderCoreBoundaryError :: CoreBoundaryError -> String
renderCoreBoundaryError currentError =
  case currentError of
    DuplicateCoreSlice currentSlice ->
      "duplicate core slice " ++ renderCoreSliceName currentSlice
    UnknownCoreDependency currentSlice currentDependency ->
      renderCoreSliceName currentSlice
        ++ " depends on unknown slice "
        ++ renderCoreSliceName currentDependency
    RuntimeDependencyLeak currentSlice currentDependency ->
      renderCoreSliceName currentSlice
        ++ " must not depend on runtime slice "
        ++ renderCoreSliceName currentDependency
    CoreDependencyCycle currentCycle ->
      "core dependency cycle: " ++ joinWith " -> " (map renderCoreSliceName currentCycle)

renderCoreSliceName :: CoreSliceName -> String
renderCoreSliceName currentName =
  case currentName of
    CoreSyntax -> "syntax"
    CoreLanguageSpec -> "language-spec"
    CoreRecursion -> "recursion"
    CoreHylo -> "hylo"
    CoreEffectTheory -> "effect-theory"
    CoreAppBuild -> "app-build"
    CoreConstraintIR -> "constraint-ir"
    CoreProofBoundary -> "proof-boundary"
    CoreSmtBackend -> "smt-backend"
    CoreFrontendFacade -> "frontend-facade"
    CoreFrontendBoundary -> "frontend-boundary"
    CoreRuntimeAdapter -> "runtime-adapter"

renderCoreSliceRole :: CoreSliceRole -> String
renderCoreSliceRole currentRole =
  case currentRole of
    PureCore -> "pure-core"
    FrontendFacade -> "frontend-facade"
    VerificationBackend -> "verification-backend"
    RuntimeBackend -> "runtime-backend"

renderBootstrapPhase :: BootstrapPhase -> String
renderBootstrapPhase currentPhase =
  case currentPhase of
    MinimalCoreFreeze -> "minimal-core-freeze"
    SmtBackendPhase -> "smt-backend"
    SelfBootstrapPhase -> "self-bootstrap"

renderDependencies :: [CoreSliceName] -> String
renderDependencies [] =
  "none"
renderDependencies currentDependencies =
  joinWith ", " (map renderCoreSliceName currentDependencies)

duplicates :: Eq item => [item] -> [item]
duplicates =
  duplicatesWithSeen []
  where
    duplicatesWithSeen _ [] =
      []
    duplicatesWithSeen seen (item : rest)
      | item `elem` seen =
          item : duplicatesWithSeen seen rest
      | otherwise =
          duplicatesWithSeen (item : seen) rest

takeUntil :: Eq item => item -> [item] -> [item]
takeUntil _ [] =
  []
takeUntil item (currentItem : rest)
  | item == currentItem =
      [currentItem]
  | otherwise =
      currentItem : takeUntil item rest

unique :: Eq item => [item] -> [item]
unique =
  foldl addUnique []
  where
    addUnique items item
      | item `elem` items = items
      | otherwise = items ++ [item]

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
