module Framework.Ast.Layout
  ( AstDiagnosisImpactKind (..)
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
  , astLayoutNodeByPath
  , astRuntimeCursorFromEvent
  , astRuntimeStatusModel
  , layoutAppBlueprint
  , layoutAstTree
  , layoutDomainAppBlueprint
  , renderAstDiagnosisImpactModel
  , renderAstLayoutModel
  , renderAstRuntimeCursor
  , renderAstRuntimeCursorOnLayout
  , renderAstRuntimeStatus
  , renderAstRuntimeStatusModel
  ) where

import Data.List
  ( isInfixOf )

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

layoutDomainAppBlueprint :: Effect.EffectTheory -> AppBlueprint -> AstLayoutModel
layoutDomainAppBlueprint theory =
  layoutAstTree . expandAstTreeWithEffectTheory theory . astTreeStructure

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
