module Framework.Ast.Layout
  ( AstLayoutAxis (..)
  , AstLayoutEdge (..)
  , AstLayoutModel (..)
  , AstLayoutNode (..)
  , AstRuntimeCursor (..)
  , astLayoutContext
  , astLiveLayoutContext
  , astLayoutNodeByPath
  , astRuntimeCursorFromEvent
  , layoutAppBlueprint
  , layoutAstTree
  , renderAstLayoutModel
  ) where

import Domain.Interpreter
  ( AstTreeNode (..)
  , astTreeStructure
  )
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

renderAstLayoutModel :: AstLayoutModel -> [String]
renderAstLayoutModel model =
  ("root " ++ renderPath (astLayoutRootPath model))
    : map renderLayoutNode (astLayoutNodes model)
    ++ map renderLayoutEdge (astLayoutEdges model)

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

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
