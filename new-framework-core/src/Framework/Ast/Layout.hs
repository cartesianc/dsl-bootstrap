module Framework.Ast.Layout
  ( AstDagContextIndex (..)
  , AstDagEquivalenceProof (..)
  , AstDagModel (..)
  , AstDagMultiplicity (..)
  , AstDagNode (..)
  , AstDagOccurrence (..)
  , AstDagProofConstraint (..)
  , AstDiagnosisImpactKind (..)
  , AstDiagnosisImpactModel (..)
  , AstDiagnosisImpactNode (..)
  , AstLayoutAxis (..)
  , AstLayoutEdge (..)
  , AstLayoutModel (..)
  , AstLayoutNode (..)
  , AstRuntimeCursor (..)
  , AstRuntimeNodeStatus (..)
  , AstRuntimeStatus (..)
  , AstRuntimeStatusModel (..)
  , astDiagnosisImpactModel
  , astLayoutContext
  , astLiveLayoutContext
  , astDagEquivalenceProof
  , astDagEquivalenceProofPassed
  , astDagAppBlueprintProjection
  , astDagDomainAppBlueprintProjection
  , astDagModelFromAstTree
  , astLayoutNodeByPath
  , astRuntimeCursorFromEvent
  , astRuntimeStatusModel
  , astTreeDagProjection
  , layoutAppBlueprintWithDag
  , layoutAppBlueprint
  , layoutAstTreeWithDag
  , layoutAstTree
  , layoutDomainAppBlueprintWithDag
  , layoutDomainAppBlueprint
  , renderAstDagEquivalenceProof
  , renderAstDagModel
  , renderAstDiagnosisImpactModel
  , renderAstLayoutModel
  , renderAstRuntimeCursor
  , renderAstRuntimeCursorOnLayout
  , renderAstRuntimeStatus
  , renderAstRuntimeStatusModel
  ) where

import Data.List
  ( foldl'
  , intercalate
  , isInfixOf
  )
import Data.Bits
  ( xor )
import Data.Char
  ( ord )
import qualified Data.Map.Strict as Map
import Numeric
  ( showHex )

import Domain.Interpreter
  ( AstTreeNode (..)
  , astTreeStructure
  )
import qualified Framework.Effect as Effect
import Framework.Ast
  ( AppBlueprint
  , EffectSystem
  , RecursionContext
  , RecursionContextName
  , WorkflowFact
  , listenDuringRunMode
  , recursionContext
  , recursionContextAlgebra
  , recursionModel
  , renderBeforeRunMode
  , zygoMode
  )
import Framework.Runtime.Types
  ( RuntimeContextEvent (..)
  , RuntimeFailureDiagnosis (..)
  )

data AstLayoutAxis
  = AstLayoutX
  | AstLayoutY
  deriving (Eq, Show)

data AstLayoutNode = AstLayoutNode
  { astLayoutNodePath :: [String]
  , astLayoutNodeKind :: String
  , astLayoutNodeName :: String
  , astLayoutNodeX :: Int
  , astLayoutNodeY :: Int
  , astLayoutNodeAxis :: AstLayoutAxis
  , astLayoutNodeImposed :: Bool
  , astLayoutNodeMetadata :: [(String, [String])]
  }
  deriving (Eq, Show)

data AstLayoutEdge = AstLayoutEdge
  { astLayoutEdgeFrom :: [String]
  , astLayoutEdgeTo :: [String]
  }
  deriving (Eq, Show)

data AstLayoutModel = AstLayoutModel
  { astLayoutRootPath :: [String]
  , astLayoutNodes :: [AstLayoutNode]
  , astLayoutEdges :: [AstLayoutEdge]
  }
  deriving (Eq, Show)

data AstDagNode = AstDagNode
  { astDagNodeId :: String
  , astDagNodeKind :: String
  , astDagNodeName :: String
  , astDagNodeMetadata :: [(String, [String])]
  , astDagNodeChildIds :: [String]
  }
  deriving (Eq, Show)

data AstDagOccurrence = AstDagOccurrence
  { astDagOccurrencePath :: [String]
  , astDagOccurrenceNodeId :: String
  , astDagOccurrenceContext :: [String]
  }
  deriving (Eq, Show)

data AstDagMultiplicity = AstDagMultiplicity
  { astDagMultiplicityNodeId :: String
  , astDagMultiplicityCount :: Int
  }
  deriving (Eq, Show)

data AstDagContextIndex = AstDagContextIndex
  { astDagContextPath :: [String]
  , astDagContextNodeId :: String
  , astDagContextMultiplicity :: Int
  }
  deriving (Eq, Show)

data AstDagModel = AstDagModel
  { astDagRootPath :: [String]
  , astDagRootNodeId :: String
  , astDagNodes :: [AstDagNode]
  , astDagOccurrences :: [AstDagOccurrence]
  , astDagMultiplicities :: [AstDagMultiplicity]
  , astDagContextIndex :: [AstDagContextIndex]
  }
  deriving (Eq, Show)

data AstDagProofConstraint = AstDagProofConstraint
  { astDagProofConstraintName :: String
  , astDagProofConstraintPassed :: Bool
  , astDagProofConstraintExpected :: String
  , astDagProofConstraintObserved :: String
  }
  deriving (Eq, Show)

data AstDagEquivalenceProof = AstDagEquivalenceProof
  { astDagProofLayoutNodeCount :: Int
  , astDagProofLayoutEdgeCount :: Int
  , astDagProofDagNodeCount :: Int
  , astDagProofOccurrenceCount :: Int
  , astDagProofSharedNodeCount :: Int
  , astDagProofMaxMultiplicity :: Int
  , astDagProofConstraints :: [AstDagProofConstraint]
  }
  deriving (Eq, Show)

data AstDagAccumulator = AstDagAccumulator
  { astDagAccumulatorNodes :: Map.Map String AstDagNode
  , astDagAccumulatorOccurrences :: [AstDagOccurrence]
  , astDagAccumulatorMultiplicities :: Map.Map String Int
  , astDagAccumulatorContextIndex :: [AstDagContextIndex]
  }

data AstRuntimeCursor = AstRuntimeCursor
  { astRuntimeCursorContext :: RecursionContextName
  , astRuntimeCursorPath :: [String]
  , astRuntimeCursorKind :: String
  , astRuntimeCursorName :: String
  , astRuntimeCursorEntering :: Bool
  }
  deriving (Eq, Show)

data AstRuntimeStatus
  = AstRuntimeRunning
  | AstRuntimeCompleted
  | AstRuntimeUnresolved
  deriving (Eq, Show)

data AstRuntimeNodeStatus = AstRuntimeNodeStatus
  { astRuntimeNodeStatusContext :: RecursionContextName
  , astRuntimeNodeStatusPath :: [String]
  , astRuntimeNodeStatusKind :: String
  , astRuntimeNodeStatusName :: String
  , astRuntimeNodeStatus :: AstRuntimeStatus
  , astRuntimeNodeStatusEnterCount :: Int
  , astRuntimeNodeStatusExitCount :: Int
  , astRuntimeNodeStatusPosition :: Maybe (Int, Int)
  }
  deriving (Eq, Show)

data AstRuntimeStatusModel = AstRuntimeStatusModel
  { astRuntimeStatusModelContext :: RecursionContextName
  , astRuntimeStatusModelNodes :: [AstRuntimeNodeStatus]
  }
  deriving (Eq, Show)

data AstDiagnosisImpactKind
  = AstDiagnosisRootFact
  | AstDiagnosisSuspectFact
  | AstDiagnosisPollutedFact
  deriving (Eq, Show)

data AstDiagnosisImpactNode = AstDiagnosisImpactNode
  { astDiagnosisImpactKind :: AstDiagnosisImpactKind
  , astDiagnosisImpactFact :: WorkflowFact
  , astDiagnosisImpactPath :: [String]
  , astDiagnosisImpactNodeKind :: String
  , astDiagnosisImpactNodeName :: String
  , astDiagnosisImpactX :: Int
  , astDiagnosisImpactY :: Int
  }
  deriving (Eq, Show)

data AstDiagnosisImpactModel = AstDiagnosisImpactModel
  { astDiagnosisImpactRootFact :: WorkflowFact
  , astDiagnosisImpactRootError :: String
  , astDiagnosisImpactNodes :: [AstDiagnosisImpactNode]
  }
  deriving (Eq, Show)

astLayoutContext ::
  RecursionContextName ->
  [EffectSystem WorkflowFact] ->
  RecursionContext WorkflowFact
astLayoutContext contextName algebraEffects =
  recursionContext
    contextName
    ( recursionModel
        "ast-layout-zygo"
        [zygoMode, renderBeforeRunMode]
        (recursionContextAlgebra "ast-layout-algebra" algebraEffects)
    )

astLiveLayoutContext ::
  RecursionContextName ->
  [EffectSystem WorkflowFact] ->
  RecursionContext WorkflowFact
astLiveLayoutContext contextName algebraEffects =
  recursionContext
    contextName
    ( recursionModel
        "ast-layout-live-zygo"
        [zygoMode, renderBeforeRunMode, listenDuringRunMode]
        (recursionContextAlgebra "ast-layout-live-algebra" algebraEffects)
    )

layoutAppBlueprint :: AppBlueprint -> AstLayoutModel
layoutAppBlueprint =
  layoutAstTree . astTreeStructure

layoutAppBlueprintWithDag :: AppBlueprint -> (AstLayoutModel, AstDagModel)
layoutAppBlueprintWithDag =
  layoutAstTreeWithDag . astTreeStructure

layoutDomainAppBlueprint :: Effect.EffectTheory -> AppBlueprint -> AstLayoutModel
layoutDomainAppBlueprint theory =
  layoutAstTree . expandAstTreeWithEffectTheory theory . astTreeStructure

layoutDomainAppBlueprintWithDag :: Effect.EffectTheory -> AppBlueprint -> (AstLayoutModel, AstDagModel)
layoutDomainAppBlueprintWithDag theory =
  layoutAstTreeWithDag . expandAstTreeWithEffectTheory theory . astTreeStructure

astDagAppBlueprintProjection :: AppBlueprint -> (AstDagModel, AstDagEquivalenceProof)
astDagAppBlueprintProjection =
  astTreeDagProjection . astTreeStructure

astDagDomainAppBlueprintProjection :: Effect.EffectTheory -> AppBlueprint -> (AstDagModel, AstDagEquivalenceProof)
astDagDomainAppBlueprintProjection theory =
  astTreeDagProjection . expandAstTreeWithEffectTheory theory . astTreeStructure

astDagModelFromAstTree :: AstTreeNode -> AstDagModel
astDagModelFromAstTree rootNode =
  dag
  where
    (dag, _, _) =
      astDagModelFromAstTreeWithStats rootNode

astTreeDagProjection :: AstTreeNode -> (AstDagModel, AstDagEquivalenceProof)
astTreeDagProjection rootNode =
  (dag, astTreeDagEquivalenceProofFromStats (astTreeNodePath rootNode) nodeCount edgeCount dag)
  where
    (dag, nodeCount, edgeCount) =
      astDagModelFromAstTreeWithStats rootNode

layoutAstTree :: AstTreeNode -> AstLayoutModel
layoutAstTree rootNode =
  AstLayoutModel
    { astLayoutRootPath = astTreeNodePath rootNode
    , astLayoutNodes = reverse nodes
    , astLayoutEdges = reverse edges
    }
  where
    (nodes, edges, _) =
      layoutNode AstLayoutY (0, 0) [] [] rootNode

layoutAstTreeWithDag :: AstTreeNode -> (AstLayoutModel, AstDagModel)
layoutAstTreeWithDag rootNode =
  ( layout
  , astDagModelFromAccumulator layout rootId accumulator
  )
  where
    layout =
      AstLayoutModel
        { astLayoutRootPath = astTreeNodePath rootNode
        , astLayoutNodes = reverse nodes
        , astLayoutEdges = reverse edges
        }
    (nodes, edges, _, accumulator, rootId) =
      layoutNodeWithDag AstLayoutY (0, 0) [] [] emptyAstDagAccumulator rootNode

astDagEquivalenceProof :: AstLayoutModel -> AstDagModel -> AstDagEquivalenceProof
astDagEquivalenceProof layout dag =
  AstDagEquivalenceProof
    { astDagProofLayoutNodeCount = layoutNodeCount
    , astDagProofLayoutEdgeCount = layoutEdgeCount
    , astDagProofDagNodeCount = dagNodeCount
    , astDagProofOccurrenceCount = occurrenceCount
    , astDagProofSharedNodeCount = sharedNodeCount
    , astDagProofMaxMultiplicity = maxMultiplicity
    , astDagProofConstraints = constraints
    }
  where
    layoutNodeCount =
      length (astLayoutNodes layout)
    layoutEdgeCount =
      length (astLayoutEdges layout)
    dagNodeCount =
      length (astDagNodes dag)
    occurrenceCount =
      length (astDagOccurrences dag)
    sharedNodeCount =
      length [item | item <- astDagMultiplicities dag, astDagMultiplicityCount item > 1]
    maxMultiplicity =
      maximumOrZero (map astDagMultiplicityCount (astDagMultiplicities dag))
    constraints =
      [ proofConstraint
          "ast-dag-root-path"
          (astLayoutRootPath layout == astDagRootPath dag)
          "DAG root path equals layout root path"
          ("layout=" ++ renderPath (astLayoutRootPath layout) ++ "; dag=" ++ renderPath (astDagRootPath dag))
      , proofConstraint
          "ast-dag-root-occurrence"
          rootOccurrencePresent
          "root occurrence points at DAG root node"
          ("root node id=" ++ astDagRootNodeId dag)
      , proofConstraint
          "ast-dag-occurrence-count"
          (occurrenceCount == layoutNodeCount)
          "one occurrence for every full layout node"
          ("layout nodes=" ++ show layoutNodeCount ++ "; occurrences=" ++ show occurrenceCount)
      , proofConstraint
          "ast-dag-edge-tree-count"
          (layoutNodeCount == 0 || layoutEdgeCount + 1 == layoutNodeCount)
          "full layout remains a tree-shaped human-readable projection"
          ("layout nodes=" ++ show layoutNodeCount ++ "; edges=" ++ show layoutEdgeCount)
      , proofConstraint
          "ast-dag-path-index-complete"
          layoutPathsMatchOccurrences
          "occurrence index path set equals full layout path set"
          ("layout paths=" ++ show layoutNodeCount ++ "; occurrence paths=" ++ show occurrenceCount)
      , proofConstraint
          "ast-dag-layout-edge-endpoints"
          layoutEdgeEndpointsKnown
          "every full layout edge endpoint resolves to a layout node path"
          ("missing endpoints=" ++ show (length missingLayoutEdgeEndpoints))
      , proofConstraint
          "ast-dag-occurrence-structure"
          occurrenceStructureMatches
          "each occurrence node id is recomputed from the full layout node and child ids"
          ("mismatched occurrences=" ++ show (length mismatchedOccurrenceStructures))
      , proofConstraint
          "ast-dag-occurrence-targets-known"
          occurrenceTargetsKnown
          "every occurrence references a content-addressed DAG node"
          ("unknown targets=" ++ show (length unknownOccurrenceTargets))
      , proofConstraint
          "ast-dag-node-coverage"
          dagNodesCoveredByOccurrences
          "every content-addressed DAG node is reached by at least one occurrence"
          ("uncovered dag nodes=" ++ show (length uncoveredDagNodes))
      , proofConstraint
          "ast-dag-structural-hashes"
          structuralHashesMatch
          "every DAG node id equals its structural content hash"
          ("mismatched ids=" ++ show (length mismatchedNodeIds))
      , proofConstraint
          "ast-dag-child-targets-known"
          childTargetsKnown
          "every DAG child id references a known content-addressed node"
          ("unknown children=" ++ show (length unknownChildTargets))
      , proofConstraint
          "ast-dag-multiplicity-index"
          multiplicityIndexMatches
          "multiplicity index counts match occurrence index counts"
          ("multiplicity entries=" ++ show (length (astDagMultiplicities dag)))
      , proofConstraint
          "ast-dag-context-index"
          contextIndexMatches
          "context -> node id index counts match occurrence contexts"
          ("context entries=" ++ show (length (astDagContextIndex dag)))
      ]
    nodeIndex =
      Map.fromList [(astDagNodeId node, ()) | node <- astDagNodes dag]
    layoutNodeIndex =
      Map.fromList [(astLayoutNodePath node, node) | node <- astLayoutNodes layout]
    layoutExpectedNodeIds =
      layoutExpectedDagNodeIds layout
    occurrenceTargetIndex =
      Map.fromList [(astDagOccurrenceNodeId occurrence, ()) | occurrence <- astDagOccurrences dag]
    rootOccurrencePresent =
      any
        ( \occurrence ->
            astDagOccurrencePath occurrence == astDagRootPath dag
              && astDagOccurrenceNodeId occurrence == astDagRootNodeId dag
        )
        (astDagOccurrences dag)
    layoutPathsMatchOccurrences =
      pathCounts (map astLayoutNodePath (astLayoutNodes layout))
        == pathCounts (map astDagOccurrencePath (astDagOccurrences dag))
    missingLayoutEdgeEndpoints =
      [ endpoint
      | edge <- astLayoutEdges layout
      , endpoint <- [astLayoutEdgeFrom edge, astLayoutEdgeTo edge]
      , Map.notMember endpoint layoutNodeIndex
      ]
    layoutEdgeEndpointsKnown =
      null missingLayoutEdgeEndpoints
    mismatchedOccurrenceStructures =
      [ occurrence
      | occurrence <- astDagOccurrences dag
      , Map.lookup (astDagOccurrencePath occurrence) layoutExpectedNodeIds /= Just (astDagOccurrenceNodeId occurrence)
      ]
    occurrenceStructureMatches =
      null mismatchedOccurrenceStructures
    unknownOccurrenceTargets =
      [ target
      | occurrence <- astDagOccurrences dag
      , let target = astDagOccurrenceNodeId occurrence
      , not (Map.member target nodeIndex)
      ]
    occurrenceTargetsKnown =
      null unknownOccurrenceTargets
    uncoveredDagNodes =
      [ astDagNodeId node
      | node <- astDagNodes dag
      , Map.notMember (astDagNodeId node) occurrenceTargetIndex
      ]
    dagNodesCoveredByOccurrences =
      null uncoveredDagNodes
    mismatchedNodeIds =
      [ node
      | node <- astDagNodes dag
      , astDagNodeId node /= astDagStructuralNodeId node
      ]
    structuralHashesMatch =
      null mismatchedNodeIds
    unknownChildTargets =
      [ childId
      | childId <- concatMap astDagNodeChildIds (astDagNodes dag)
      , not (Map.member childId nodeIndex)
      ]
    childTargetsKnown =
      null unknownChildTargets
    multiplicityIndexMatches =
      astDagMultiplicities dag == multiplicitiesFromOccurrences (astDagOccurrences dag)
    contextIndexMatches =
      astDagContextIndex dag == layoutExpectedDagContextIndex layout layoutExpectedNodeIds

astTreeDagEquivalenceProofFromStats :: [String] -> Int -> Int -> AstDagModel -> AstDagEquivalenceProof
astTreeDagEquivalenceProofFromStats rootPath treeNodeCount treeEdgeCount dag =
  AstDagEquivalenceProof
    { astDagProofLayoutNodeCount = treeNodeCount
    , astDagProofLayoutEdgeCount = treeEdgeCount
    , astDagProofDagNodeCount = dagNodeCount
    , astDagProofOccurrenceCount = occurrenceCount
    , astDagProofSharedNodeCount = sharedNodeCount
    , astDagProofMaxMultiplicity = maxMultiplicity
    , astDagProofConstraints = constraints
    }
  where
    dagNodeCount =
      length (astDagNodes dag)
    occurrenceCount =
      length (astDagOccurrences dag)
    sharedNodeCount =
      length [item | item <- astDagMultiplicities dag, astDagMultiplicityCount item > 1]
    maxMultiplicity =
      maximumOrZero (map astDagMultiplicityCount (astDagMultiplicities dag))
    constraints =
      [ proofConstraint
          "ast-dag-root-path"
          (rootPath == astDagRootPath dag)
          "DAG root path equals expanded AST root path"
          ("tree=" ++ renderPath rootPath ++ "; dag=" ++ renderPath (astDagRootPath dag))
      , proofConstraint
          "ast-dag-root-occurrence"
          rootOccurrencePresent
          "root occurrence points at DAG root node"
          ("root node id=" ++ astDagRootNodeId dag)
      , proofConstraint
          "ast-dag-occurrence-count"
          (occurrenceCount == treeNodeCount)
          "one occurrence for every expanded AST tree node"
          ("tree nodes=" ++ show treeNodeCount ++ "; occurrences=" ++ show occurrenceCount)
      , proofConstraint
          "ast-dag-edge-tree-count"
          (treeNodeCount == 0 || treeEdgeCount + 1 == treeNodeCount)
          "expanded AST remains tree-shaped before DAG sharing"
          ("tree nodes=" ++ show treeNodeCount ++ "; edges=" ++ show treeEdgeCount)
      , proofConstraint
          "ast-dag-path-index-complete"
          (occurrenceCount == treeNodeCount)
          "occurrence path index covers the full expanded tree"
          ("tree nodes=" ++ show treeNodeCount ++ "; occurrence paths=" ++ show occurrenceCount)
      , proofConstraint
          "ast-dag-occurrence-targets-known"
          occurrenceTargetsKnown
          "every occurrence references a content-addressed DAG node"
          ("unknown targets=" ++ show (length unknownOccurrenceTargets))
      , proofConstraint
          "ast-dag-node-coverage"
          dagNodesCoveredByOccurrences
          "every content-addressed DAG node is reached by at least one occurrence"
          ("uncovered dag nodes=" ++ show (length uncoveredDagNodes))
      , proofConstraint
          "ast-dag-structural-hashes"
          structuralHashesMatch
          "every DAG node id equals its structural content hash"
          ("mismatched ids=" ++ show (length mismatchedNodeIds))
      , proofConstraint
          "ast-dag-child-targets-known"
          childTargetsKnown
          "every DAG child id references a known content-addressed node"
          ("unknown children=" ++ show (length unknownChildTargets))
      , proofConstraint
          "ast-dag-multiplicity-index"
          multiplicityIndexMatches
          "multiplicity index counts match occurrence index counts"
          ("multiplicity entries=" ++ show (length (astDagMultiplicities dag)))
      , proofConstraint
          "ast-dag-context-index"
          (contextIndexCoversOccurrences && contextTargetsKnown)
          "context -> node id multiplicities cover every occurrence and target known DAG nodes"
          ( "context entries="
              ++ show (length (astDagContextIndex dag))
              ++ "; context multiplicity total="
              ++ show contextMultiplicityTotal
              ++ "; unknown context targets="
              ++ show (length unknownContextTargets)
          )
      ]
    nodeIndex =
      Map.fromList [(astDagNodeId node, ()) | node <- astDagNodes dag]
    occurrenceTargetIndex =
      Map.fromList [(astDagOccurrenceNodeId occurrence, ()) | occurrence <- astDagOccurrences dag]
    rootOccurrencePresent =
      any
        ( \occurrence ->
            astDagOccurrencePath occurrence == astDagRootPath dag
              && astDagOccurrenceNodeId occurrence == astDagRootNodeId dag
        )
        (astDagOccurrences dag)
    unknownOccurrenceTargets =
      [ target
      | occurrence <- astDagOccurrences dag
      , let target = astDagOccurrenceNodeId occurrence
      , not (Map.member target nodeIndex)
      ]
    occurrenceTargetsKnown =
      null unknownOccurrenceTargets
    uncoveredDagNodes =
      [ astDagNodeId node
      | node <- astDagNodes dag
      , Map.notMember (astDagNodeId node) occurrenceTargetIndex
      ]
    dagNodesCoveredByOccurrences =
      null uncoveredDagNodes
    mismatchedNodeIds =
      [ node
      | node <- astDagNodes dag
      , astDagNodeId node /= astDagStructuralNodeId node
      ]
    structuralHashesMatch =
      null mismatchedNodeIds
    unknownChildTargets =
      [ childId
      | childId <- concatMap astDagNodeChildIds (astDagNodes dag)
      , not (Map.member childId nodeIndex)
      ]
    childTargetsKnown =
      null unknownChildTargets
    multiplicityIndexMatches =
      astDagMultiplicities dag == multiplicitiesFromOccurrences (astDagOccurrences dag)
    contextMultiplicityTotal =
      sum (map astDagContextMultiplicity (astDagContextIndex dag))
    contextIndexCoversOccurrences =
      contextMultiplicityTotal == occurrenceCount
    unknownContextTargets =
      [ astDagContextNodeId entry
      | entry <- astDagContextIndex dag
      , Map.notMember (astDagContextNodeId entry) nodeIndex
      ]
    contextTargetsKnown =
      null unknownContextTargets

astDagEquivalenceProofPassed :: AstDagEquivalenceProof -> Bool
astDagEquivalenceProofPassed proof =
  all astDagProofConstraintPassed (astDagProofConstraints proof)

astLayoutNodeByPath :: [String] -> AstLayoutModel -> Maybe AstLayoutNode
astLayoutNodeByPath path model =
  firstJust
    [ Just node
    | node <- astLayoutNodes model
    , astLayoutNodePath node == path
    ]

astRuntimeCursorFromEvent :: RuntimeContextEvent -> Maybe AstRuntimeCursor
astRuntimeCursorFromEvent event =
  case event of
    RuntimeContextNodeEntered contextName path kind name ->
      Just (AstRuntimeCursor contextName path kind name True)
    RuntimeContextNodeExited contextName path kind name ->
      Just (AstRuntimeCursor contextName path kind name False)
    _ ->
      Nothing

astRuntimeStatusModel ::
  RecursionContextName ->
  AstLayoutModel ->
  [RuntimeContextEvent] ->
  AstRuntimeStatusModel
astRuntimeStatusModel contextName layout events =
  AstRuntimeStatusModel
    { astRuntimeStatusModelContext = contextName
    , astRuntimeStatusModelNodes =
        [ runtimeNodeStatus contextName layout path relatedCursors
        | path <- observedPaths
        , let relatedCursors =
                [ cursor
                | cursor <- cursors
                , astRuntimeCursorPath cursor == path
                ]
        ]
    }
  where
    cursors =
      [ cursor
      | event <- events
      , Just cursor <- [astRuntimeCursorFromEvent event]
      , astRuntimeCursorContext cursor == contextName
      ]
    observedPaths =
      uniqueItems (map astRuntimeCursorPath cursors)

runtimeNodeStatus ::
  RecursionContextName ->
  AstLayoutModel ->
  [String] ->
  [AstRuntimeCursor] ->
  AstRuntimeNodeStatus
runtimeNodeStatus contextName layout path cursors =
  AstRuntimeNodeStatus
    { astRuntimeNodeStatusContext = contextName
    , astRuntimeNodeStatusPath = path
    , astRuntimeNodeStatusKind = nodeText astLayoutNodeKind cursorKind
    , astRuntimeNodeStatusName = nodeText astLayoutNodeName cursorName
    , astRuntimeNodeStatus = status
    , astRuntimeNodeStatusEnterCount = enterCount
    , astRuntimeNodeStatusExitCount = exitCount
    , astRuntimeNodeStatusPosition =
        fmap (\node -> (astLayoutNodeX node, astLayoutNodeY node)) maybeNode
    }
  where
    maybeNode =
      astLayoutNodeByPath path layout
    enterCount =
      length [cursor | cursor <- cursors, astRuntimeCursorEntering cursor]
    exitCount =
      length [cursor | cursor <- cursors, not (astRuntimeCursorEntering cursor)]
    status
      | maybeNode == Nothing =
          AstRuntimeUnresolved
      | enterCount > exitCount =
          AstRuntimeRunning
      | exitCount > 0 =
          AstRuntimeCompleted
      | otherwise =
          AstRuntimeUnresolved
    cursorKind =
      firstCursorText astRuntimeCursorKind cursors
    cursorName =
      firstCursorText astRuntimeCursorName cursors
    nodeText select fallback =
      case maybeNode of
        Just node ->
          select node
        Nothing ->
          fallback

expandAstTreeWithEffectTheory :: Effect.EffectTheory -> AstTreeNode -> AstTreeNode
expandAstTreeWithEffectTheory theory node =
  node
    { astTreeNodeChildren =
        map (expandAstTreeWithEffectTheory theory) (astTreeNodeChildren node)
          ++ semanticChildrenForNode theory node
    }

semanticChildrenForNode :: Effect.EffectTheory -> AstTreeNode -> [AstTreeNode]
semanticChildrenForNode theory node
  | astTreeNodeKind node == "run" =
      concatMap (effectFactTrees theory [] (astTreeNodePath node)) (runNodeFacts theory node)
  | otherwise =
      []

runNodeFacts :: Effect.EffectTheory -> AstTreeNode -> [WorkflowFact]
runNodeFacts theory node =
  uniqueItems
    [ currentFact
    | currentFact <- allEffectFacts theory
    , runNodeMentionsFact currentFact node
    ]

runNodeMentionsFact :: WorkflowFact -> AstTreeNode -> Bool
runNodeMentionsFact currentFact node =
  factText == astTreeNodeName node
    || any (factText `isInfixOf`) metadataValues
  where
    factText =
      show currentFact
    metadataValues =
      concatMap snd (astTreeNodeMetadata node)

effectFactTrees :: Effect.EffectTheory -> [WorkflowFact] -> [String] -> WorkflowFact -> [AstTreeNode]
effectFactTrees theory seen parentPath currentFact
  | currentFact `elem` seen =
      [effectFactReferenceTree parentPath currentFact]
  | not (null producerTrees) =
      producerTrees
  | otherwise =
      externalTakeTrees ++ [missingEffectFactTree parentPath currentFact | null externalTakeTrees]
  where
    producerTrees =
      [ effectFactTree theory (currentFact : seen) parentPath index unit producer
      | (index, (unit, producer)) <- indexedItems (factProducersFor theory currentFact)
      ]
    externalTakeTrees =
      [ externalTakeTree parentPath index unit boundary
      | (index, (unit, boundary)) <- indexedItems (externalTakesFor theory currentFact)
      ]

effectFactTree ::
  Effect.EffectTheory ->
  [WorkflowFact] ->
  [String] ->
  Int ->
  Effect.EffectUnit ->
  Effect.FactProducer ->
  AstTreeNode
effectFactTree theory seen parentPath index unit producer =
  AstTreeNode
    { astTreeNodeKind = "effect-fact"
    , astTreeNodeName = show currentFact
    , astTreeNodePath = nodePath
    , astTreeNodeMetadata =
        [ ("effect", [show (Effect.effectUnitName unit)])
        , ("steps", [show (length (Effect.producerSteps producer))])
        ]
    , astTreeNodeChildren =
        [ producerStepTree theory seen nodePath stepIndex step
        | (stepIndex, step) <- indexedItems (Effect.producerSteps producer)
        ]
    }
  where
    currentFact =
      Effect.producerFact producer
    nodePath =
      parentPath ++ ["fact:" ++ show index ++ ":" ++ show currentFact]

producerStepTree ::
  Effect.EffectTheory ->
  [WorkflowFact] ->
  [String] ->
  Int ->
  Effect.ProducerStep ->
  AstTreeNode
producerStepTree theory seen parentPath index step =
  AstTreeNode
    { astTreeNodeKind = producerStepKind step
    , astTreeNodeName = producerStepName step
    , astTreeNodePath = nodePath
    , astTreeNodeMetadata = producerStepMetadata step
    , astTreeNodeChildren = producerStepChildren theory seen nodePath step
    }
  where
    nodePath =
      parentPath ++ ["step:" ++ show index ++ ":" ++ producerStepKind step]

producerStepChildren ::
  Effect.EffectTheory ->
  [WorkflowFact] ->
  [String] ->
  Effect.ProducerStep ->
  [AstTreeNode]
producerStepChildren theory seen parentPath step =
  case step of
    Effect.Needs currentFact ->
      effectFactTrees theory seen parentPath currentFact
    Effect.OnFailure currentFact ->
      effectFactTrees theory seen parentPath currentFact
    Effect.Uses send ->
      sendBoundaryTrees theory parentPath send
    Effect.Error send ->
      sendBoundaryTrees theory parentPath send
    _ ->
      []

sendBoundaryTrees :: Effect.EffectTheory -> [String] -> Effect.SendName -> [AstTreeNode]
sendBoundaryTrees theory parentPath send =
  [ sendBoundaryTree parentPath index unit boundary
  | (index, (unit, boundary)) <- indexedItems (sendBoundariesFor theory send)
  ]
    ++ [ sendPolicyTree parentPath index unit policy
       | (index, (unit, policy)) <- indexedItems (sendPoliciesFor theory send)
       ]

sendBoundaryTree ::
  [String] ->
  Int ->
  Effect.EffectUnit ->
  Effect.SendBoundary ->
  AstTreeNode
sendBoundaryTree parentPath index unit boundary =
  AstTreeNode
    { astTreeNodeKind = "externalMake"
    , astTreeNodeName = show (Effect.sendBoundaryName boundary)
    , astTreeNodePath = parentPath ++ ["externalMake:" ++ show index ++ ":" ++ show (Effect.sendBoundaryName boundary)]
    , astTreeNodeMetadata =
        [ ("effect", [show (Effect.effectUnitName unit)])
        , ("input", [show (Effect.sendInput signature)])
        , ("output", [show (Effect.sendOutput signature)])
        ]
    , astTreeNodeChildren = []
    }
  where
    signature =
      Effect.sendBoundarySignature boundary

sendPolicyTree ::
  [String] ->
  Int ->
  Effect.EffectUnit ->
  Effect.SendPolicy ->
  AstTreeNode
sendPolicyTree parentPath index unit policy =
  AstTreeNode
    { astTreeNodeKind = "policy"
    , astTreeNodeName = show (Effect.sendPolicyName policy)
    , astTreeNodePath = parentPath ++ ["policy:" ++ show index ++ ":" ++ show (Effect.sendPolicyName policy)]
    , astTreeNodeMetadata =
        [ ("effect", [show (Effect.effectUnitName unit)])
        , ("idempotency", maybe [] ((: []) . show) (Effect.sendPolicyIdempotency policy))
        , ("retry", maybe [] ((: []) . show) (Effect.sendPolicyRetry policy))
        ]
    , astTreeNodeChildren = []
    }

externalTakeTree ::
  [String] ->
  Int ->
  Effect.EffectUnit ->
  Effect.ExternalTakeBoundary ->
  AstTreeNode
externalTakeTree parentPath index unit boundary =
  AstTreeNode
    { astTreeNodeKind = "externalTake"
    , astTreeNodeName = show (Effect.externalTakeFact boundary)
    , astTreeNodePath = parentPath ++ ["externalTake:" ++ show index ++ ":" ++ show (Effect.externalTakeFact boundary)]
    , astTreeNodeMetadata =
        [ ("effect", [show (Effect.effectUnitName unit)])
        , ("output", maybe [] ((: []) . show) (Effect.externalTakeOutput boundary))
        ]
    , astTreeNodeChildren = []
    }

effectFactReferenceTree :: [String] -> WorkflowFact -> AstTreeNode
effectFactReferenceTree parentPath currentFact =
  AstTreeNode
    { astTreeNodeKind = "effect-fact-ref"
    , astTreeNodeName = show currentFact
    , astTreeNodePath = parentPath ++ ["fact-ref:" ++ show currentFact]
    , astTreeNodeMetadata = [("fact", [show currentFact])]
    , astTreeNodeChildren = []
    }

missingEffectFactTree :: [String] -> WorkflowFact -> AstTreeNode
missingEffectFactTree parentPath currentFact =
  AstTreeNode
    { astTreeNodeKind = "effect-fact-missing"
    , astTreeNodeName = show currentFact
    , astTreeNodePath = parentPath ++ ["fact-missing:" ++ show currentFact]
    , astTreeNodeMetadata = [("fact", [show currentFact])]
    , astTreeNodeChildren = []
    }

renderAstLayoutModel :: AstLayoutModel -> [String]
renderAstLayoutModel model =
  ("root " ++ renderPath (astLayoutRootPath model))
    : map renderLayoutNode (astLayoutNodes model)
    ++ map renderLayoutEdge (astLayoutEdges model)

renderAstDagModel :: AstDagModel -> [String]
renderAstDagModel dag =
  [ "dag root "
      ++ renderPath (astDagRootPath dag)
      ++ " "
      ++ astDagRootNodeId dag
  , "dag nodes " ++ show (length (astDagNodes dag))
  , "dag occurrences " ++ show (length (astDagOccurrences dag))
  , "dag shared nodes " ++ show (length [item | item <- astDagMultiplicities dag, astDagMultiplicityCount item > 1])
  ]
    ++ map renderAstDagNode (take renderDagNodeLimit (astDagNodes dag))
    ++ map renderAstDagOccurrence (take renderDagOccurrenceLimit (astDagOccurrences dag))
    ++ map renderAstDagMultiplicity (take renderDagMultiplicityLimit (astDagMultiplicities dag))
    ++ map renderAstDagContextIndex (take renderDagContextLimit (astDagContextIndex dag))

renderAstDagEquivalenceProof :: AstDagEquivalenceProof -> [String]
renderAstDagEquivalenceProof proof =
  [ "dag-proof layout-nodes " ++ show (astDagProofLayoutNodeCount proof)
  , "dag-proof layout-edges " ++ show (astDagProofLayoutEdgeCount proof)
  , "dag-proof dag-nodes " ++ show (astDagProofDagNodeCount proof)
  , "dag-proof occurrences " ++ show (astDagProofOccurrenceCount proof)
  , "dag-proof shared-nodes " ++ show (astDagProofSharedNodeCount proof)
  , "dag-proof max-multiplicity " ++ show (astDagProofMaxMultiplicity proof)
  , "dag-proof constraints " ++ show (length (astDagProofConstraints proof))
  ]
    ++ map renderAstDagProofConstraint (astDagProofConstraints proof)

astDiagnosisImpactModel :: AstLayoutModel -> RuntimeFailureDiagnosis -> AstDiagnosisImpactModel
astDiagnosisImpactModel layout diagnosis =
  AstDiagnosisImpactModel
    { astDiagnosisImpactRootFact = diagnosisRootFact diagnosis
    , astDiagnosisImpactRootError = diagnosisRootError diagnosis
    , astDiagnosisImpactNodes =
        concatMap impactNodesFor (diagnosisImpactFacts diagnosis)
    }
  where
    impactNodesFor (impactKind, currentFact) =
      [ diagnosisImpactNode impactKind currentFact currentNode
      | currentNode <- astLayoutNodes layout
      , layoutNodeMentionsFact currentFact currentNode
      ]

renderAstDiagnosisImpactModel :: AstDiagnosisImpactModel -> [String]
renderAstDiagnosisImpactModel model =
  [ "diagnosis-impact root "
      ++ show (astDiagnosisImpactRootFact model)
      ++ " error "
      ++ show (astDiagnosisImpactRootError model)
  ]
    ++ map renderDiagnosisImpactNode (astDiagnosisImpactNodes model)

renderAstRuntimeCursor :: AstRuntimeCursor -> String
renderAstRuntimeCursor cursor =
  "cursor "
    ++ show (astRuntimeCursorContext cursor)
    ++ " "
    ++ cursorDirection cursor
    ++ " "
    ++ renderPath (astRuntimeCursorPath cursor)
    ++ " "
    ++ astRuntimeCursorKind cursor
    ++ " "
    ++ astRuntimeCursorName cursor

renderAstRuntimeCursorOnLayout :: AstLayoutModel -> AstRuntimeCursor -> String
renderAstRuntimeCursorOnLayout layout cursor =
  case astLayoutNodeByPath (astRuntimeCursorPath cursor) layout of
    Just node ->
      renderAstRuntimeCursor cursor
        ++ " at "
        ++ show (astLayoutNodeX node, astLayoutNodeY node)
    Nothing ->
      renderAstRuntimeCursor cursor ++ " at unresolved"

renderAstRuntimeStatus :: AstRuntimeStatus -> String
renderAstRuntimeStatus status =
  case status of
    AstRuntimeRunning ->
      "running"
    AstRuntimeCompleted ->
      "completed"
    AstRuntimeUnresolved ->
      "unresolved"

renderAstRuntimeStatusModel :: AstRuntimeStatusModel -> [String]
renderAstRuntimeStatusModel model =
  [ "runtime-status context "
      ++ show (astRuntimeStatusModelContext model)
      ++ " nodes "
      ++ show (length (astRuntimeStatusModelNodes model))
  ]
    ++ map renderAstRuntimeNodeStatus (astRuntimeStatusModelNodes model)

renderAstRuntimeNodeStatus :: AstRuntimeNodeStatus -> String
renderAstRuntimeNodeStatus node =
  "status "
    ++ show (astRuntimeNodeStatusContext node)
    ++ " "
    ++ renderAstRuntimeStatus (astRuntimeNodeStatus node)
    ++ " "
    ++ renderPath (astRuntimeNodeStatusPath node)
    ++ " "
    ++ astRuntimeNodeStatusKind node
    ++ " "
    ++ astRuntimeNodeStatusName node
    ++ " enters="
    ++ show (astRuntimeNodeStatusEnterCount node)
    ++ " exits="
    ++ show (astRuntimeNodeStatusExitCount node)
    ++ " at "
    ++ renderMaybePosition (astRuntimeNodeStatusPosition node)

layoutNode ::
  AstLayoutAxis ->
  (Int, Int) ->
  [AstLayoutNode] ->
  [AstLayoutEdge] ->
  AstTreeNode ->
  ([AstLayoutNode], [AstLayoutEdge], [(Int, Int)])
layoutNode axis coordinate nodes edges treeNode =
  foldl
    (layoutChild placedNode childAxis (length children))
    (placedNode : nodes, edges, [placedCoordinate])
    (indexedItems children)
  where
    children =
      astTreeNodeChildren treeNode
    (placedCoordinate, imposed) =
      placeCoordinate axis coordinate (map nodeCoordinate nodes) (imposedNodeKind (astTreeNodeKind treeNode))
    childAxis =
      flipAxis axis
    placedNode =
      AstLayoutNode
        { astLayoutNodePath = astTreeNodePath treeNode
        , astLayoutNodeKind = astTreeNodeKind treeNode
        , astLayoutNodeName = astTreeNodeName treeNode
        , astLayoutNodeX = fst placedCoordinate
        , astLayoutNodeY = snd placedCoordinate
        , astLayoutNodeAxis = axis
        , astLayoutNodeImposed = imposed
        , astLayoutNodeMetadata = astTreeNodeMetadata treeNode
        }

layoutChild ::
  AstLayoutNode ->
  AstLayoutAxis ->
  Int ->
  ([AstLayoutNode], [AstLayoutEdge], [(Int, Int)]) ->
  (Int, AstTreeNode) ->
  ([AstLayoutNode], [AstLayoutEdge], [(Int, Int)])
layoutChild parent childAxis childCount (nodes, edges, occupied) (index, child) =
  (childNodes, childEdges, uniqueCoordinates (childOccupied ++ occupied))
  where
    childCoordinate =
      childBaseCoordinate parent childAxis childCount index child
    (childNodes, childEdges, childOccupied) =
      layoutNode
        childAxis
        childCoordinate
        nodes
        (AstLayoutEdge (astLayoutNodePath parent) (astTreeNodePath child) : edges)
        child

layoutNodeWithDag ::
  AstLayoutAxis ->
  (Int, Int) ->
  [AstLayoutNode] ->
  [AstLayoutEdge] ->
  AstDagAccumulator ->
  AstTreeNode ->
  ([AstLayoutNode], [AstLayoutEdge], [(Int, Int)], AstDagAccumulator, String)
layoutNodeWithDag axis coordinate nodes edges accumulator treeNode =
  ( finalNodes
  , finalEdges
  , finalOccupied
  , addDagOccurrence occurrence (addDagNode dagNode finalAccumulator)
  , nodeId
  )
  where
    children =
      astTreeNodeChildren treeNode
    (placedCoordinate, imposed) =
      placeCoordinate axis coordinate (map nodeCoordinate nodes) (imposedNodeKind (astTreeNodeKind treeNode))
    childAxis =
      flipAxis axis
    placedNode =
      AstLayoutNode
        { astLayoutNodePath = astTreeNodePath treeNode
        , astLayoutNodeKind = astTreeNodeKind treeNode
        , astLayoutNodeName = astTreeNodeName treeNode
        , astLayoutNodeX = fst placedCoordinate
        , astLayoutNodeY = snd placedCoordinate
        , astLayoutNodeAxis = axis
        , astLayoutNodeImposed = imposed
        , astLayoutNodeMetadata = astTreeNodeMetadata treeNode
        }
    (finalNodes, finalEdges, finalOccupied, finalAccumulator, childIds) =
      foldl
        (layoutChildWithDag placedNode childAxis (length children))
        (placedNode : nodes, edges, [placedCoordinate], accumulator, [])
        (indexedItems children)
    nodeId =
      astDagNodeIdFor
        (astLayoutNodeKind placedNode)
        (astLayoutNodeName placedNode)
        (astLayoutNodeMetadata placedNode)
        childIds
    occurrence =
      AstDagOccurrence
        { astDagOccurrencePath = astLayoutNodePath placedNode
        , astDagOccurrenceNodeId = nodeId
        , astDagOccurrenceContext = occurrenceContext (astLayoutNodePath placedNode)
        }
    dagNode =
      AstDagNode
        { astDagNodeId = nodeId
        , astDagNodeKind = astLayoutNodeKind placedNode
        , astDagNodeName = astLayoutNodeName placedNode
        , astDagNodeMetadata = astLayoutNodeMetadata placedNode
        , astDagNodeChildIds = childIds
        }

layoutChildWithDag ::
  AstLayoutNode ->
  AstLayoutAxis ->
  Int ->
  ([AstLayoutNode], [AstLayoutEdge], [(Int, Int)], AstDagAccumulator, [String]) ->
  (Int, AstTreeNode) ->
  ([AstLayoutNode], [AstLayoutEdge], [(Int, Int)], AstDagAccumulator, [String])
layoutChildWithDag parent childAxis childCount (nodes, edges, occupied, accumulator, childIds) (index, child) =
  (childNodes, childEdges, uniqueCoordinates (childOccupied ++ occupied), childAccumulator, childIds ++ [childId])
  where
    childCoordinate =
      childBaseCoordinate parent childAxis childCount index child
    (childNodes, childEdges, childOccupied, childAccumulator, childId) =
      layoutNodeWithDag
        childAxis
        childCoordinate
        nodes
        (AstLayoutEdge (astLayoutNodePath parent) (astTreeNodePath child) : edges)
        accumulator
        child

childBaseCoordinate :: AstLayoutNode -> AstLayoutAxis -> Int -> Int -> AstTreeNode -> (Int, Int)
childBaseCoordinate parent childAxis childCount index child
  | imposedNodeKind (astTreeNodeKind child) =
      (astLayoutNodeX parent, astLayoutNodeY parent - gridStep)
  | childAxis == AstLayoutX =
      (astLayoutNodeX parent + centeredOffset childCount index, astLayoutNodeY parent + gridStep)
  | otherwise =
      (astLayoutNodeX parent + gridStep, astLayoutNodeY parent + centeredOffset childCount index)

placeCoordinate :: AstLayoutAxis -> (Int, Int) -> [(Int, Int)] -> Bool -> ((Int, Int), Bool)
placeCoordinate axis coordinate occupied imposed =
  (avoidCollision axis coordinate occupied, imposed)

avoidCollision :: AstLayoutAxis -> (Int, Int) -> [(Int, Int)] -> (Int, Int)
avoidCollision axis coordinate occupied
  | coordinate `elem` occupied =
      avoidCollision axis (stepCoordinate axis coordinate) occupied
  | otherwise =
      coordinate

stepCoordinate :: AstLayoutAxis -> (Int, Int) -> (Int, Int)
stepCoordinate AstLayoutX (x, y) =
  (x + gridStep, y)
stepCoordinate AstLayoutY (x, y) =
  (x, y + gridStep)

centeredOffset :: Int -> Int -> Int
centeredOffset childCount index =
  (index * gridStep) - ((childCount - 1) * gridStep `div` 2)

flipAxis :: AstLayoutAxis -> AstLayoutAxis
flipAxis AstLayoutX =
  AstLayoutY
flipAxis AstLayoutY =
  AstLayoutX

imposedNodeKind :: String -> Bool
imposedNodeKind kind =
  kind `elem` ["callback", "context", "middleware", "suspense"]

nodeCoordinate :: AstLayoutNode -> (Int, Int)
nodeCoordinate node =
  (astLayoutNodeX node, astLayoutNodeY node)

uniqueCoordinates :: [(Int, Int)] -> [(Int, Int)]
uniqueCoordinates =
  foldl appendUnique []

indexedItems :: [item] -> [(Int, item)]
indexedItems =
  zip [(0 :: Int) ..]

renderLayoutNode :: AstLayoutNode -> String
renderLayoutNode node =
  "node "
    ++ renderPath (astLayoutNodePath node)
    ++ " "
    ++ astLayoutNodeKind node
    ++ " "
    ++ astLayoutNodeName node
    ++ " at "
    ++ show (astLayoutNodeX node, astLayoutNodeY node)
    ++ " axis "
    ++ show (astLayoutNodeAxis node)
    ++ if astLayoutNodeImposed node then " imposed" else ""

renderLayoutEdge :: AstLayoutEdge -> String
renderLayoutEdge edge =
  "edge " ++ renderPath (astLayoutEdgeFrom edge) ++ " -> " ++ renderPath (astLayoutEdgeTo edge)

diagnosisImpactFacts :: RuntimeFailureDiagnosis -> [(AstDiagnosisImpactKind, WorkflowFact)]
diagnosisImpactFacts diagnosis =
  [(AstDiagnosisRootFact, diagnosisRootFact diagnosis)]
    ++ [ (AstDiagnosisSuspectFact, currentFact)
       | currentFact <- diagnosisSuspects diagnosis
       , currentFact /= diagnosisRootFact diagnosis
       ]
    ++ [ (AstDiagnosisPollutedFact, currentFact)
       | currentFact <- diagnosisPollutedFacts diagnosis
       , currentFact /= diagnosisRootFact diagnosis
       , currentFact `notElem` diagnosisSuspects diagnosis
       ]

diagnosisImpactNode :: AstDiagnosisImpactKind -> WorkflowFact -> AstLayoutNode -> AstDiagnosisImpactNode
diagnosisImpactNode impactKind currentFact node =
  AstDiagnosisImpactNode
    { astDiagnosisImpactKind = impactKind
    , astDiagnosisImpactFact = currentFact
    , astDiagnosisImpactPath = astLayoutNodePath node
    , astDiagnosisImpactNodeKind = astLayoutNodeKind node
    , astDiagnosisImpactNodeName = astLayoutNodeName node
    , astDiagnosisImpactX = astLayoutNodeX node
    , astDiagnosisImpactY = astLayoutNodeY node
    }

layoutNodeMentionsFact :: WorkflowFact -> AstLayoutNode -> Bool
layoutNodeMentionsFact currentFact node =
  factText == astLayoutNodeName node
    || any (factText `isInfixOf`) metadataValues
  where
    factText =
      show currentFact
    metadataValues =
      concatMap snd (astLayoutNodeMetadata node)

allEffectFacts :: Effect.EffectTheory -> [WorkflowFact]
allEffectFacts theory =
  uniqueItems
    ( [ Effect.producerFact producer
      | (_, producer) <- allFactProducers theory
      ]
        ++ [ Effect.externalTakeFact boundary
           | (_, boundary) <- allExternalTakes theory
           ]
    )

factProducersFor :: Effect.EffectTheory -> WorkflowFact -> [(Effect.EffectUnit, Effect.FactProducer)]
factProducersFor theory currentFact =
  [ (unit, producer)
  | (unit, producer) <- allFactProducers theory
  , Effect.producerFact producer == currentFact
  ]

externalTakesFor :: Effect.EffectTheory -> WorkflowFact -> [(Effect.EffectUnit, Effect.ExternalTakeBoundary)]
externalTakesFor theory currentFact =
  [ (unit, boundary)
  | (unit, boundary) <- allExternalTakes theory
  , Effect.externalTakeFact boundary == currentFact
  ]

sendBoundariesFor :: Effect.EffectTheory -> Effect.SendName -> [(Effect.EffectUnit, Effect.SendBoundary)]
sendBoundariesFor theory send =
  [ (unit, boundary)
  | (unit, boundary) <- allSendBoundaries theory
  , Effect.sendBoundaryName boundary == send
  ]

sendPoliciesFor :: Effect.EffectTheory -> Effect.SendName -> [(Effect.EffectUnit, Effect.SendPolicy)]
sendPoliciesFor theory send =
  [ (unit, policy)
  | (unit, policy) <- allSendPolicies theory
  , Effect.sendPolicyName policy == send
  ]

allFactProducers :: Effect.EffectTheory -> [(Effect.EffectUnit, Effect.FactProducer)]
allFactProducers theory =
  [ (unit, producer)
  | unit <- Effect.theoryUnits theory
  , Effect.FactClaimSection producer <- Effect.effectUnitSections unit
  ]

allExternalTakes :: Effect.EffectTheory -> [(Effect.EffectUnit, Effect.ExternalTakeBoundary)]
allExternalTakes theory =
  [ (unit, boundary)
  | unit <- Effect.theoryUnits theory
  , Effect.ExternalTakeSection boundary <- Effect.effectUnitSections unit
  ]

allSendBoundaries :: Effect.EffectTheory -> [(Effect.EffectUnit, Effect.SendBoundary)]
allSendBoundaries theory =
  [ (unit, boundary)
  | unit <- Effect.theoryUnits theory
  , Effect.SendSection boundary <- Effect.effectUnitSections unit
  ]

allSendPolicies :: Effect.EffectTheory -> [(Effect.EffectUnit, Effect.SendPolicy)]
allSendPolicies theory =
  [ (unit, policy)
  | unit <- Effect.theoryUnits theory
  , Effect.SendPolicySection policy <- Effect.effectUnitSections unit
  ]

producerStepKind :: Effect.ProducerStep -> String
producerStepKind step =
  case step of
    Effect.Needs _ ->
      "needs"
    Effect.Uses _ ->
      "uses"
    Effect.Take _ ->
      "take"
    Effect.Make _ ->
      "make"
    Effect.Transform _ _ _ ->
      "transform"
    Effect.External ->
      "external"
    Effect.OnFailure _ ->
      "onFailure"
    Effect.Error _ ->
      "error"

producerStepName :: Effect.ProducerStep -> String
producerStepName step =
  case step of
    Effect.Needs currentFact ->
      show currentFact
    Effect.Uses send ->
      show send
    Effect.Take inputType ->
      show inputType
    Effect.Make outputType ->
      show outputType
    Effect.Transform _ _ transformName ->
      show transformName
    Effect.External ->
      "external"
    Effect.OnFailure currentFact ->
      show currentFact
    Effect.Error send ->
      show send

producerStepMetadata :: Effect.ProducerStep -> [(String, [String])]
producerStepMetadata step =
  case step of
    Effect.Needs currentFact ->
      [("fact", [show currentFact])]
    Effect.Uses send ->
      [("send", [show send])]
    Effect.Take inputType ->
      [("type", [show inputType])]
    Effect.Make outputType ->
      [("type", [show outputType])]
    Effect.Transform inputType outputType transformName ->
      [ ("transform", [show transformName])
      , ("input", [show inputType])
      , ("output", [show outputType])
      ]
    Effect.External ->
      []
    Effect.OnFailure currentFact ->
      [("fact", [show currentFact])]
    Effect.Error send ->
      [("send", [show send])]

emptyAstDagAccumulator :: AstDagAccumulator
emptyAstDagAccumulator =
  AstDagAccumulator
    { astDagAccumulatorNodes = Map.empty
    , astDagAccumulatorOccurrences = []
    , astDagAccumulatorMultiplicities = Map.empty
    , astDagAccumulatorContextIndex = []
    }

addDagNode :: AstDagNode -> AstDagAccumulator -> AstDagAccumulator
addDagNode node accumulator =
  accumulator
    { astDagAccumulatorNodes =
        Map.insertWith
          keepExistingDagNode
          (astDagNodeId node)
          node
          (astDagAccumulatorNodes accumulator)
    }

keepExistingDagNode :: AstDagNode -> AstDagNode -> AstDagNode
keepExistingDagNode _ existing =
  existing

addDagOccurrence :: AstDagOccurrence -> AstDagAccumulator -> AstDagAccumulator
addDagOccurrence occurrence accumulator =
  accumulator
    { astDagAccumulatorOccurrences =
        occurrence : astDagAccumulatorOccurrences accumulator
    , astDagAccumulatorMultiplicities =
        Map.insertWith
          (+)
          (astDagOccurrenceNodeId occurrence)
          1
          (astDagAccumulatorMultiplicities accumulator)
    }

addDagContextEntries :: [AstDagContextIndex] -> AstDagAccumulator -> AstDagAccumulator
addDagContextEntries entries accumulator =
  accumulator
    { astDagAccumulatorContextIndex =
        reverse entries ++ astDagAccumulatorContextIndex accumulator
    }

astDagModelFromAccumulator :: AstLayoutModel -> String -> AstDagAccumulator -> AstDagModel
astDagModelFromAccumulator layout rootId accumulator =
  AstDagModel
    { astDagRootPath = astLayoutRootPath layout
    , astDagRootNodeId = rootId
    , astDagNodes = map snd (Map.toList (astDagAccumulatorNodes accumulator))
    , astDagOccurrences = reverse (astDagAccumulatorOccurrences accumulator)
    , astDagMultiplicities = multiplicitiesFromMap (astDagAccumulatorMultiplicities accumulator)
    , astDagContextIndex = layoutExpectedDagContextIndex layout (layoutExpectedDagNodeIds layout)
    }

astDagModelFromAstTreeWithStats :: AstTreeNode -> (AstDagModel, Int, Int)
astDagModelFromAstTreeWithStats rootNode =
  ( astDagModelFromTreeAccumulator (astTreeNodePath rootNode) rootId accumulator
  , nodeCount
  , edgeCount
  )
  where
    (accumulator, rootId, nodeCount, edgeCount) =
      collectAstTreeDagNode emptyAstDagAccumulator rootNode

astDagModelFromTreeAccumulator :: [String] -> String -> AstDagAccumulator -> AstDagModel
astDagModelFromTreeAccumulator rootPath rootId accumulator =
  AstDagModel
    { astDagRootPath = rootPath
    , astDagRootNodeId = rootId
    , astDagNodes = map snd (Map.toList (astDagAccumulatorNodes accumulator))
    , astDagOccurrences = reverse (astDagAccumulatorOccurrences accumulator)
    , astDagMultiplicities = multiplicitiesFromMap (astDagAccumulatorMultiplicities accumulator)
    , astDagContextIndex = reverse (astDagAccumulatorContextIndex accumulator)
    }

collectAstTreeDagNode :: AstDagAccumulator -> AstTreeNode -> (AstDagAccumulator, String, Int, Int)
collectAstTreeDagNode accumulator treeNode =
  ( finalAccumulator
  , nodeId
  , childNodeCount + 1
  , childEdgeCount + length children
  )
  where
    children =
      astTreeNodeChildren treeNode
    (childAccumulator, childIds, childNodeCount, childEdgeCount) =
      foldl' collectChild (accumulator, [], 0, 0) children
    collectChild (currentAccumulator, currentChildIds, currentNodeCount, currentEdgeCount) child =
      (nextAccumulator, currentChildIds ++ [childId], currentNodeCount + nodeCount, currentEdgeCount + edgeCount)
      where
        (nextAccumulator, childId, nodeCount, edgeCount) =
          collectAstTreeDagNode currentAccumulator child
    nodeId =
      astDagNodeIdFor
        (astTreeNodeKind treeNode)
        (astTreeNodeName treeNode)
        (astTreeNodeMetadata treeNode)
        childIds
    occurrence =
      AstDagOccurrence
        { astDagOccurrencePath = astTreeNodePath treeNode
        , astDagOccurrenceNodeId = nodeId
        , astDagOccurrenceContext = occurrenceContext (astTreeNodePath treeNode)
        }
    dagNode =
      AstDagNode
        { astDagNodeId = nodeId
        , astDagNodeKind = astTreeNodeKind treeNode
        , astDagNodeName = astTreeNodeName treeNode
        , astDagNodeMetadata = astTreeNodeMetadata treeNode
        , astDagNodeChildIds = childIds
        }
    finalAccumulator =
      addDagContextEntries
        (astTreeDagContextEntries (astTreeNodePath treeNode) nodeId childIds)
        (addDagOccurrence occurrence (addDagNode dagNode childAccumulator))

astTreeDagContextEntries :: [String] -> String -> [String] -> [AstDagContextIndex]
astTreeDagContextEntries path nodeId childIds =
  rootEntry ++ contextIndexEntries path childIds
  where
    rootEntry
      | occurrenceContext path == [] =
          [ AstDagContextIndex
              { astDagContextPath = []
              , astDagContextNodeId = nodeId
              , astDagContextMultiplicity = 1
              }
          ]
      | otherwise =
          []

multiplicitiesFromOccurrences :: [AstDagOccurrence] -> [AstDagMultiplicity]
multiplicitiesFromOccurrences occurrences =
  multiplicitiesFromMap
    ( foldl'
        ( \counts occurrence ->
            Map.insertWith (+) (astDagOccurrenceNodeId occurrence) 1 counts
        )
        Map.empty
        occurrences
    )

multiplicitiesFromMap :: Map.Map String Int -> [AstDagMultiplicity]
multiplicitiesFromMap counts =
  [ AstDagMultiplicity
      { astDagMultiplicityNodeId = nodeId
      , astDagMultiplicityCount = count
      }
  | (nodeId, count) <- Map.toList counts
  ]

pathCounts :: [[String]] -> Map.Map [String] Int
pathCounts paths =
  foldl'
    (\counts path -> Map.insertWith (+) path 1 counts)
    Map.empty
    paths

layoutExpectedDagNodeIds :: AstLayoutModel -> Map.Map [String] String
layoutExpectedDagNodeIds layout =
  foldl' addExpectedNodeId Map.empty (reverse (astLayoutNodes layout))
  where
    childrenByPath =
      layoutChildrenByPath (astLayoutEdges layout)
    addExpectedNodeId expectedIds node =
      Map.insert
        (astLayoutNodePath node)
        ( astDagNodeIdFor
            (astLayoutNodeKind node)
            (astLayoutNodeName node)
            (astLayoutNodeMetadata node)
            childIds
        )
        expectedIds
      where
        childIds =
          [ Map.findWithDefault (missingLayoutChildNodeId childPath) childPath expectedIds
          | childPath <- Map.findWithDefault [] (astLayoutNodePath node) childrenByPath
          ]

layoutChildrenByPath :: [AstLayoutEdge] -> Map.Map [String] [[String]]
layoutChildrenByPath edges =
  foldl' addEdge Map.empty edges
  where
    addEdge children edge =
      Map.alter addChild (astLayoutEdgeFrom edge) children
      where
        addChild Nothing =
          Just [astLayoutEdgeTo edge]
        addChild (Just childPaths) =
          Just (childPaths ++ [astLayoutEdgeTo edge])

missingLayoutChildNodeId :: [String] -> String
missingLayoutChildNodeId path =
  "missing-layout-child:" ++ renderPath path

layoutExpectedDagContextIndex :: AstLayoutModel -> Map.Map [String] String -> [AstDagContextIndex]
layoutExpectedDagContextIndex layout expectedNodeIds =
  concatMap contextEntriesForNode (astLayoutNodes layout)
  where
    childrenByPath =
      layoutChildrenByPath (astLayoutEdges layout)
    contextEntriesForNode node =
      rootContextEntry node ++ childContextEntries node
    rootContextEntry node
      | occurrenceContext (astLayoutNodePath node) == [] =
          [ AstDagContextIndex
              { astDagContextPath = []
              , astDagContextNodeId =
                  Map.findWithDefault
                    (missingLayoutChildNodeId (astLayoutNodePath node))
                    (astLayoutNodePath node)
                    expectedNodeIds
              , astDagContextMultiplicity = 1
              }
          ]
      | otherwise =
          []
    childContextEntries node =
      contextIndexEntries
        (astLayoutNodePath node)
        [ Map.findWithDefault (missingLayoutChildNodeId childPath) childPath expectedNodeIds
        | childPath <- Map.findWithDefault [] (astLayoutNodePath node) childrenByPath
        ]

contextIndexEntries :: [String] -> [String] -> [AstDagContextIndex]
contextIndexEntries contextPath nodeIds =
  [ AstDagContextIndex
      { astDagContextPath = contextPath
      , astDagContextNodeId = nodeId
      , astDagContextMultiplicity = count
      }
  | (nodeId, count) <- countInFirstOccurrenceOrder nodeIds
  ]

countInFirstOccurrenceOrder :: [String] -> [(String, Int)]
countInFirstOccurrenceOrder =
  foldl' addCount []
  where
    addCount [] nodeId =
      [(nodeId, 1)]
    addCount ((currentNodeId, currentCount) : rest) nodeId
      | currentNodeId == nodeId =
          (currentNodeId, currentCount + 1) : rest
      | otherwise =
          (currentNodeId, currentCount) : addCount rest nodeId

occurrenceContext :: [String] -> [String]
occurrenceContext [] =
  []
occurrenceContext [_] =
  []
occurrenceContext path =
  take (length path - 1) path

astDagStructuralNodeId :: AstDagNode -> String
astDagStructuralNodeId node =
  astDagNodeIdFor
    (astDagNodeKind node)
    (astDagNodeName node)
    (astDagNodeMetadata node)
    (astDagNodeChildIds node)

astDagNodeIdFor :: String -> String -> [(String, [String])] -> [String] -> String
astDagNodeIdFor kind name metadata childIds =
  "ast-dag:" ++ stableHashText fingerprint
  where
    fingerprint =
      intercalate
        "\RS"
        [ kind
        , name
        , show metadata
        , intercalate "," childIds
        ]

stableHashText :: String -> String
stableHashText =
  padHash . (`showHex` "") . foldl fnvStep fnvOffset

fnvStep :: Integer -> Char -> Integer
fnvStep current char =
  ((current `xor` toInteger (ord char)) * fnvPrime) `mod` fnvModulus

fnvOffset :: Integer
fnvOffset =
  14695981039346656037

fnvPrime :: Integer
fnvPrime =
  1099511628211

fnvModulus :: Integer
fnvModulus =
  18446744073709551616

padHash :: String -> String
padHash hashText =
  replicate (max 0 (16 - length hashText)) '0' ++ hashText

proofConstraint :: String -> Bool -> String -> String -> AstDagProofConstraint
proofConstraint name passed expected observed =
  AstDagProofConstraint
    { astDagProofConstraintName = name
    , astDagProofConstraintPassed = passed
    , astDagProofConstraintExpected = expected
    , astDagProofConstraintObserved = observed
    }

maximumOrZero :: [Int] -> Int
maximumOrZero [] =
  0
maximumOrZero values =
  maximum values

renderAstDagNode :: AstDagNode -> String
renderAstDagNode node =
  "dag-node "
    ++ astDagNodeId node
    ++ " "
    ++ astDagNodeKind node
    ++ " "
    ++ astDagNodeName node
    ++ " children="
    ++ show (length (astDagNodeChildIds node))

renderAstDagOccurrence :: AstDagOccurrence -> String
renderAstDagOccurrence occurrence =
  "dag-occurrence "
    ++ renderPath (astDagOccurrencePath occurrence)
    ++ " -> "
    ++ astDagOccurrenceNodeId occurrence
    ++ " context "
    ++ renderPath (astDagOccurrenceContext occurrence)

renderAstDagMultiplicity :: AstDagMultiplicity -> String
renderAstDagMultiplicity multiplicity =
  "dag-multiplicity "
    ++ astDagMultiplicityNodeId multiplicity
    ++ " count="
    ++ show (astDagMultiplicityCount multiplicity)

renderAstDagContextIndex :: AstDagContextIndex -> String
renderAstDagContextIndex entry =
  "dag-context "
    ++ renderPath (astDagContextPath entry)
    ++ " -> "
    ++ astDagContextNodeId entry
    ++ " count="
    ++ show (astDagContextMultiplicity entry)

renderAstDagProofConstraint :: AstDagProofConstraint -> String
renderAstDagProofConstraint constraint =
  "dag-proof-constraint "
    ++ astDagProofConstraintName constraint
    ++ " "
    ++ (if astDagProofConstraintPassed constraint then "passed" else "failed")
    ++ " expected "
    ++ show (astDagProofConstraintExpected constraint)
    ++ " observed "
    ++ show (astDagProofConstraintObserved constraint)

renderDagNodeLimit :: Int
renderDagNodeLimit =
  40

renderDagOccurrenceLimit :: Int
renderDagOccurrenceLimit =
  40

renderDagMultiplicityLimit :: Int
renderDagMultiplicityLimit =
  40

renderDagContextLimit :: Int
renderDagContextLimit =
  40

renderDiagnosisImpactNode :: AstDiagnosisImpactNode -> String
renderDiagnosisImpactNode node =
  "impact "
    ++ show (astDiagnosisImpactKind node)
    ++ " "
    ++ show (astDiagnosisImpactFact node)
    ++ " node "
    ++ renderPath (astDiagnosisImpactPath node)
    ++ " "
    ++ astDiagnosisImpactNodeKind node
    ++ " "
    ++ astDiagnosisImpactNodeName node
    ++ " at "
    ++ show (astDiagnosisImpactX node, astDiagnosisImpactY node)

cursorDirection :: AstRuntimeCursor -> String
cursorDirection cursor
  | astRuntimeCursorEntering cursor =
      "enter"
  | otherwise =
      "exit"

firstCursorText :: (AstRuntimeCursor -> String) -> [AstRuntimeCursor] -> String
firstCursorText _ [] =
  "unresolved"
firstCursorText select (cursor : _) =
  select cursor

renderMaybePosition :: Maybe (Int, Int) -> String
renderMaybePosition position =
  case position of
    Just coordinate ->
      show coordinate
    Nothing ->
      "unresolved"

renderPath :: [String] -> String
renderPath =
  joinWith "/"

gridStep :: Int
gridStep =
  100

firstJust :: [Maybe item] -> Maybe item
firstJust [] =
  Nothing
firstJust (item : rest) =
  case item of
    Just value ->
      Just value
    Nothing ->
      firstJust rest

appendUnique :: Eq item => [item] -> item -> [item]
appendUnique items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

uniqueItems :: Eq item => [item] -> [item]
uniqueItems =
  foldl appendUnique []

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
