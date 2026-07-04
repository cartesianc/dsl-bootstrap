module Main
  ( main
  ) where

import System.Environment
  ( getArgs )

import Data.List
  ( intercalate )

import Domain.Ast
  ( AstRegistration (..)
  , frameworkCoreAstRegistration
  )
import Domain.Effects
  ( frameworkCoreEffects
  )
import qualified Bootstrap.Runtime as Native
import Framework.Ast
  ( AppBlueprint
  , RecursionContextName (..)
  , WorkflowFact (..)
  , withRecursionContext
  )
import qualified Framework.Ast as Ast
import Framework.Ast.Layout
  ( AstDiagnosisImpactModel
  , AstDagEquivalenceProof (..)
  , AstDagModel (..)
  , AstLayoutModel (..)
  , AstRuntimeCursor (..)
  , astDagDomainAppBlueprintProjection
  , astDiagnosisImpactModel
  , astLiveLayoutContext
  , astRuntimeCursorFromEvent
  , astRuntimeStatusModel
  , layoutAppBlueprint
  , layoutDomainAppBlueprint
  , renderAstDagEquivalenceProof
  , renderAstDagModel
  , renderAstDiagnosisImpactModel
  , renderAstLayoutModel
  , renderAstRuntimeCursorOnLayout
  , renderAstRuntimeStatusModel
  )
import qualified Framework.Effect as Effect
import qualified Framework.Runtime as Runtime
import Framework.Runtime.Diagnosis
  ( RuntimeDiagnosisRootCause (..)
  , RuntimeFailureDiagnosis (..)
  )
import qualified Framework.TrustBase.SelfInterpret as SelfInterpret

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["domain"] ->
      printDomainLayout
    ["layout"] ->
      printDomainLayout
    ["structure"] ->
      printStructureLayout
    ["summary"] ->
      printDomainSummary
    ["cursor"] ->
      printCursor
    ["diagnosis"] ->
      printDiagnosisImpact
    ["live"] ->
      printLive
    ["live-core"] ->
      printLiveCore
    ["self-interpret"] ->
      printSelfInterpretSummary
    ["self-interpret-summary"] ->
      printSelfInterpretSummary
    ["self-interpret-layout"] ->
      printSelfInterpretLayoutSample
    ["self-interpret-dag"] ->
      printSelfInterpretDag
    ["self-interpret-live"] ->
      printSelfInterpretLive
    ["all"] ->
      printAll
    [] ->
      printDomainLayout
    _ ->
      printUsage

printAll :: IO ()
printAll = do
  putStrLn "[ast-layout] domain layout"
  printDomainLayout
  putStrLn ""
  putStrLn "[ast-layout] live cursor sample"
  printCursor
  putStrLn ""
  putStrLn "[ast-layout] diagnosis impact sample"
  printDiagnosisImpact
  putStrLn ""
  putStrLn "[ast-layout] live runtime cursor"
  printLive

printDomainLayout :: IO ()
printDomainLayout =
  mapM_ putStrLn (renderAstLayoutModel frameworkCoreLayout)

printStructureLayout :: IO ()
printStructureLayout =
  mapM_ putStrLn (renderAstLayoutModel frameworkCoreStructureLayout)

printDomainSummary :: IO ()
printDomainSummary = do
  putStrLn ("[ast-layout] domain nodes " ++ show (length (astLayoutNodes frameworkCoreLayout)))
  putStrLn ("[ast-layout] domain edges " ++ show (length (astLayoutEdges frameworkCoreLayout)))
  putStrLn ("[ast-layout] structure nodes " ++ show (length (astLayoutNodes frameworkCoreStructureLayout)))
  putStrLn ("[ast-layout] structure edges " ++ show (length (astLayoutEdges frameworkCoreStructureLayout)))

printCursor :: IO ()
printCursor =
  putStrLn (renderAstRuntimeCursorOnLayout frameworkCoreLayout sampleCursor)

printDiagnosisImpact :: IO ()
printDiagnosisImpact =
  mapM_ putStrLn (renderAstDiagnosisImpactModel impactModel)

printUsage :: IO ()
printUsage =
  putStrLn "usage: ast-layout [all|domain|layout|structure|summary|cursor|diagnosis|live|live-core|self-interpret|self-interpret-summary|self-interpret-layout|self-interpret-dag|self-interpret-live]"

printLive :: IO ()
printLive = do
  result <-
    Runtime.runBlueprintWithEffectEnvironmentRuntimeResult
      (Runtime.runtimeEffectEnvironment Runtime.emptyHandlerRegistry)
      liveSampleEffects
      liveSampleBlueprint
  let runtime =
        runtimeFromResult result
      layout =
        layoutDomainAppBlueprint liveSampleEffects liveSampleBlueprint
      cursors =
        [ cursor
        | event <- Runtime.runtimeContextEvents runtime
        , Just cursor <- [astRuntimeCursorFromEvent event]
        ]
  putStrLn (runtimeResultStatus result)
  mapM_ (putStrLn . renderAstRuntimeCursorOnLayout layout) cursors
  mapM_ putStrLn (renderAstRuntimeStatusModel (astRuntimeStatusModel (RecursionContextName "AstLayoutLiveContext") layout (Runtime.runtimeContextEvents runtime)))
  mapM_
    ( \diagnosis -> do
        putStrLn "[ast-layout] live diagnosis impact"
        mapM_ putStrLn (renderAstDiagnosisImpactModel (astDiagnosisImpactModel layout diagnosis))
    )
    (Runtime.runtimeFailureDiagnoses runtime)

printLiveCore :: IO ()
printLiveCore = do
  putStrLn "[ast-layout] live-core runs the full framework-core self-domain path"
  result <-
    Runtime.runBlueprintWithEffectEnvironmentRuntimeResult
      frameworkRuntimeEnvironment
      frameworkCoreEffects
      liveCoreBlueprint
  let runtime =
        runtimeFromResult result
      layout =
        layoutDomainAppBlueprint frameworkCoreEffects liveCoreBlueprint
      cursors =
        [ cursor
        | event <- Runtime.runtimeContextEvents runtime
        , Just cursor <- [astRuntimeCursorFromEvent event]
        ]
  putStrLn (runtimeResultStatus result)
  mapM_ (putStrLn . renderAstRuntimeCursorOnLayout layout) cursors
  mapM_ putStrLn (renderAstRuntimeStatusModel (astRuntimeStatusModel (RecursionContextName "AstLayoutCoreLiveContext") layout (Runtime.runtimeContextEvents runtime)))
  mapM_
    ( \diagnosis -> do
        putStrLn "[ast-layout] live-core diagnosis impact"
        mapM_ putStrLn (renderAstDiagnosisImpactModel (astDiagnosisImpactModel layout diagnosis))
    )
    (Runtime.runtimeFailureDiagnoses runtime)

printSelfInterpretSummary :: IO ()
printSelfInterpretSummary = do
  putStrLn "[ast-layout] self-interpret line core_0 -> new_core -> empty_business"
  putStrLn ("[ast-layout] boot root " ++ renderLayoutPath (astLayoutRootPath selfInterpretBootLayout))
  putStrLn ("[ast-layout] boot nodes " ++ show (length (astLayoutNodes selfInterpretBootLayout)))
  putStrLn ("[ast-layout] boot edges " ++ show (length (astLayoutEdges selfInterpretBootLayout)))
  putStrLn ("[ast-layout] live context " ++ show SelfInterpret.coreSelfInterpretLiveContextName)
  putStrLn ("[ast-layout] live modes " ++ intercalate "," (map show SelfInterpret.coreSelfInterpretLiveModes))
  putStrLn "[ast-layout] default empty business has no listener context; self-interpret-live installs one explicitly"

printSelfInterpretLayoutSample :: IO ()
printSelfInterpretLayoutSample = do
  printSelfInterpretSummary
  putStrLn "[ast-layout] self-interpret boot layout sample"
  mapM_ putStrLn (take selfInterpretLayoutSampleSize (renderAstLayoutModel selfInterpretBootLayout))
  putStrLn
    ( "[ast-layout] sample rendered "
        ++ show selfInterpretLayoutSampleSize
        ++ " lines from "
        ++ show (1 + length (astLayoutNodes selfInterpretBootLayout) + length (astLayoutEdges selfInterpretBootLayout))
        ++ " total render lines"
    )

printSelfInterpretDag :: IO ()
printSelfInterpretDag = do
  printSelfInterpretSummary
  putStrLn "[ast-layout] self-interpret DAG sample"
  mapM_ putStrLn (renderAstDagModel selfInterpretBootDag)
  putStrLn "[ast-layout] self-interpret DAG equivalence proof"
  mapM_ putStrLn (renderAstDagEquivalenceProof selfInterpretDagProof)

printSelfInterpretLive :: IO ()
printSelfInterpretLive = do
  result <-
    Runtime.runBlueprintWithEffectEnvironmentRuntimeResult
      (Runtime.runtimeEffectEnvironment Runtime.emptyHandlerRegistry)
      SelfInterpret.emptyBusinessEffects
      SelfInterpret.coreSelfInterpretLiveBlueprint
  let runtime =
        runtimeFromResult result
      layout =
        layoutDomainAppBlueprint SelfInterpret.emptyBusinessEffects SelfInterpret.coreSelfInterpretLiveBlueprint
      cursors =
        [ cursor
        | event <- Runtime.runtimeContextEvents runtime
        , Just cursor <- [astRuntimeCursorFromEvent event]
        , astRuntimeCursorContext cursor == SelfInterpret.coreSelfInterpretLiveContextName
        ]
  putStrLn "[ast-layout] self-interpret live cursor projection"
  putStrLn (runtimeResultStatus result)
  putStrLn ("[ast-layout] live cursor count " ++ show (length cursors))
  mapM_ (putStrLn . renderAstRuntimeCursorOnLayout layout) cursors
  putStrLn "[ast-layout] self-interpret live node status"
  mapM_ putStrLn (renderAstRuntimeStatusModel (astRuntimeStatusModel SelfInterpret.coreSelfInterpretLiveContextName layout (Runtime.runtimeContextEvents runtime)))
  mapM_
    ( \diagnosis -> do
        putStrLn "[ast-layout] self-interpret live diagnosis impact"
        mapM_ putStrLn (renderAstDiagnosisImpactModel (astDiagnosisImpactModel layout diagnosis))
    )
    (Runtime.runtimeFailureDiagnoses runtime)

frameworkCoreLayout :: AstLayoutModel
frameworkCoreLayout =
  layoutDomainAppBlueprint frameworkCoreEffects (astRegistrationBlueprint frameworkCoreAstRegistration)

frameworkCoreStructureLayout :: AstLayoutModel
frameworkCoreStructureLayout =
  layoutAppBlueprint (astRegistrationBlueprint frameworkCoreAstRegistration)

selfInterpretBootLayout :: AstLayoutModel
selfInterpretBootLayout =
  layoutDomainAppBlueprint frameworkCoreEffects (astRegistrationBlueprint frameworkCoreAstRegistration)

selfInterpretBootDag :: AstDagModel
selfInterpretBootDag =
  fst selfInterpretBootDagProjection

selfInterpretDagProof :: AstDagEquivalenceProof
selfInterpretDagProof =
  snd selfInterpretBootDagProjection

selfInterpretBootDagProjection :: (AstDagModel, AstDagEquivalenceProof)
selfInterpretBootDagProjection =
  astDagDomainAppBlueprintProjection frameworkCoreEffects (astRegistrationBlueprint frameworkCoreAstRegistration)

selfInterpretLayoutSampleSize :: Int
selfInterpretLayoutSampleSize =
  120

liveSampleBlueprint :: AppBlueprint
liveSampleBlueprint =
  withRecursionContext
    (astLiveLayoutContext (RecursionContextName "AstLayoutLiveContext") [])
    ( Ast.AppBlueprint
        { Ast.blueprintApp =
            Ast.chain
              [ Ast.run (Ast.effectSystem (Ast.EffectSystemName "AstLayoutLiveFirst") (Ast.factItems [liveFirstFact]))
              , Ast.run (Ast.effectSystem (Ast.EffectSystemName "AstLayoutLiveSecond") (Ast.factItems [liveSecondFact]))
              ]
        , Ast.blueprintHanging = Ast.hanging []
        }
    )

liveCoreBlueprint :: AppBlueprint
liveCoreBlueprint =
  withRecursionContext
    (astLiveLayoutContext (RecursionContextName "AstLayoutCoreLiveContext") [])
    (astRegistrationBlueprint frameworkCoreAstRegistration)

liveSampleEffects :: Effect.EffectTheory
liveSampleEffects =
  Effect.theory
    [ Effect.effect
        (Effect.EffectName "AstLayoutLiveSampleEffect")
        [ Effect.fact liveFirstFact ([] :: [Effect.ProducerStep])
        , Effect.fact liveSecondFact [Effect.needs liveFirstFact]
        ]
    ]

liveFirstFact :: WorkflowFact
liveFirstFact =
  WorkflowFact "AstLayoutLiveFirstFact"

liveSecondFact :: WorkflowFact
liveSecondFact =
  WorkflowFact "AstLayoutLiveSecondFact"

impactModel :: AstDiagnosisImpactModel
impactModel =
  astDiagnosisImpactModel frameworkCoreLayout sampleDiagnosis

sampleCursor :: AstRuntimeCursor
sampleCursor =
  AstRuntimeCursor
    (RecursionContextName "AstLayoutCliContext")
    ["blueprint", "app", "root"]
    "run"
    "CoreSurfaceRegistration"
    True

sampleDiagnosis :: RuntimeFailureDiagnosis
sampleDiagnosis =
  RuntimeFailureDiagnosis
    { diagnosisRootSystem = Nothing
    , diagnosisRootFact = astStructureFact
    , diagnosisPipelineStep = Nothing
    , diagnosisRootCause = DiagnosisUnknownRootCause "sample diagnosis impact"
    , diagnosisRootSend = Nothing
    , diagnosisRootError = "sample diagnosis impact"
    , diagnosisNodes = []
    , diagnosisProbes = []
    , diagnosisSuspects = [astStructureFact]
    , diagnosisPollutedFacts = []
    }

astStructureFact :: WorkflowFact
astStructureFact =
  WorkflowFact "AstStructureExpressedFact"

frameworkRuntimeEnvironment :: Runtime.RuntimeEffectEnvironment
frameworkRuntimeEnvironment =
  Runtime.RuntimeEffectEnvironment frameworkHandlerRegistry Runtime.emptyTransformRegistry

frameworkHandlerRegistry :: Runtime.HandlerRegistry
frameworkHandlerRegistry =
  Runtime.HandlerRegistry
    [ Runtime.HandlerBinding
        (Native.handlerBindingSend binding)
        (Native.handlerBindingName binding)
        (adaptNativeHandler (Native.handlerBindingHandler binding))
    | binding <- Native.handlerRegistryBindings Native.bootstrapHandlerRegistry
    ]

adaptNativeHandler :: Native.NativeHandler -> Runtime.RuntimeHandler
adaptNativeHandler nativeHandler =
  Runtime.RuntimeHandler $ \currentSend input runtime -> do
    result <-
      Native.runNativeHandler
        nativeHandler
        currentSend
        (map runtimeValueToArtifact (Runtime.handlerInputValues input))
        (runtimeToNativeRuntime runtime)
    case result of
      Native.HandlerSucceeded artifacts ->
        pure (Runtime.HandlerSucceeded (map artifactToRuntimeValue artifacts))
      Native.HandlerFailed message ->
        pure (Runtime.HandlerFailed message)

runtimeToNativeRuntime :: Runtime.Runtime -> Native.NativeRuntime
runtimeToNativeRuntime runtime =
  Native.NativeRuntime
    { Native.availableFacts = Runtime.availableFacts runtime
    , Native.runtimeArtifacts = map runtimeValueToArtifact (Runtime.runtimeValues runtime)
    , Native.runtimeTrace = Runtime.runtimeTrace runtime
    , Native.runtimeFailures =
        [ show failure
        | claim <- Runtime.runtimeFactClaims runtime
        , Just failure <- [Runtime.runtimeFactClaimFailure claim]
        ]
    }

runtimeValueToArtifact :: Runtime.RuntimeValue -> Native.RuntimeArtifact
runtimeValueToArtifact value =
  Native.RuntimeArtifact
    { Native.artifactType = Runtime.runtimeValueType value
    , Native.artifactText = Runtime.runtimeValueText value
    }

artifactToRuntimeValue :: Native.RuntimeArtifact -> Runtime.RuntimeValue
artifactToRuntimeValue artifact =
  Runtime.RuntimeValue
    { Runtime.runtimeValueType = Native.artifactType artifact
    , Runtime.runtimeValueText = Native.artifactText artifact
    }

runtimeFromResult :: Runtime.RuntimeResult Runtime.Runtime -> Runtime.Runtime
runtimeFromResult result =
  case result of
    Runtime.RuntimeSucceeded runtime _ ->
      runtime
    Runtime.RuntimeFailed _ runtime ->
      runtime

runtimeResultStatus :: Runtime.RuntimeResult Runtime.Runtime -> String
runtimeResultStatus result =
  case result of
    Runtime.RuntimeSucceeded _ _ ->
      "[ast-layout] live status passed"
    Runtime.RuntimeFailed errorReport _ ->
      "[ast-layout] live status failed: " ++ Runtime.renderRuntimeError errorReport

renderLayoutPath :: [String] -> String
renderLayoutPath =
  intercalate "/"
