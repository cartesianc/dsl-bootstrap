module Domain.Relations
  ( renderRegisteredDomainMap
  , renderRegisteredDomainMapJson
  , renderSelectedDomainMap
  , renderSelectedDomainMapJson
  ) where

import Bootstrap.Workflow
  ( App
  , AppBlueprint (..)
  , AppHanging
  , Callback (..)
  , ChoiceKey (..)
  , Fact (..)
  , FactExpr (..)
  , HangingAction (..)
  , Interceptor
  , Loop (..)
  , Middleware (..)
  , Suspense (..)
  , Wait (..)
  , Workflow (..)
  , WorkflowFact
  , chainItems
  , choiceItems
  , fallbackItems
  , hangingItems
  , parallelItems
  , raceItems
  , requirementItems
  )
import Bootstrap.Runtime
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , NativeAppPlan (..)
  , NativeFactRule (..)
  , SendContract (..)
  , TransformBinding (..)
  , TransformRegistry (..)
  , buildNativeApp
  , renderNativeAppError
  )
import Data.List
  ( intercalate
  )
import Domain.Ast
  ( AstRegistration (..)
  )
import Domain.EffectHandlers
  ( EffectHandlerRegistration (..)
  )
import Domain.Effects
  ( EffectRegistration (..)
  )
import Domain.Interpreter
  ( InterpreterRegistration (..)
  )
import Domain.Registry
  ( DomainRegistration (..)
  , registeredDomains
  )
import Bootstrap.Effect
  ( EffectSection (..)
  , EffectTheory (..)
  , EffectUnit (..)
  , ExternalTakeBoundary (..)
  , FactProducer (..)
  , SendBoundary (..)
  , SendName
  , SendPolicy (..)
  , SendSignature (..)
  , TransformName
  , TypeName
  )

data AstNode = AstNode
  { astNodeKind :: String
  , astNodeName :: String
  , astNodePath :: [String]
  , astNodeWaitFacts :: [WorkflowFact]
  , astNodeClaimFacts :: [WorkflowFact]
  }

renderRegisteredDomainMap :: [String]
renderRegisteredDomainMap =
  renderDomainMap registeredDomains

renderRegisteredDomainMapJson :: String
renderRegisteredDomainMapJson =
  jsonObject
    [ ( "domains"
      , jsonArray (map domainJson registeredDomains)
      )
    ]

renderSelectedDomainMap :: String -> Either String [String]
renderSelectedDomainMap name =
  case selectDomains name of
    [] ->
      Left ("unknown domain: " ++ name)
    domains ->
      Right (renderDomainMap domains)

renderSelectedDomainMapJson :: String -> Either String String
renderSelectedDomainMapJson name =
  case selectDomains name of
    [] ->
      Left ("unknown domain: " ++ name)
    domains ->
      Right
        ( jsonObject
            [ ( "domains"
              , jsonArray (map domainJson domains)
              )
            ]
        )

renderDomainMap :: [DomainRegistration] -> [String]
renderDomainMap domains =
  "domain-map" : concatMap renderDomain domains

renderDomain :: DomainRegistration -> [String]
renderDomain registration =
  [ "domain " ++ domainRegistrationName registration
  , "  ast: " ++ astRegistrationName (domainAst registration)
  , "  effects: " ++ effectRegistrationName (domainEffects registration)
  , "  effect-handlers: " ++ effectHandlerRegistrationName (domainEffectHandlers registration)
  , "  interpreter: " ++ interpreterRegistrationName (domainInterpreter registration)
  , "  effect-units: " ++ formatList (map (show . effectUnitName) effectUnits)
  ]
    ++ renderBuild
  where
    blueprint =
      astRegistrationBlueprint (domainAst registration)
    effects =
      effectRegistrationTheory (domainEffects registration)
    effectUnits =
      theoryUnits effects
    renderBuild =
      case buildNativeApp blueprint effects of
        Left appError ->
          ["  build-error: " ++ renderNativeAppError appError]
        Right plan ->
          renderPlan registration blueprint effectUnits plan

renderPlan ::
  DomainRegistration ->
  AppBlueprint ->
  [EffectUnit] ->
  NativeAppPlan ->
  [String]
renderPlan registration blueprint effectUnits plan =
  [ "  ast-root-facts: " ++ formatList (map show (collectBlueprintFacts blueprint))
  , "  closure-facts: " ++ formatList (map show (nativeAppPlanFacts plan))
  , "  send-boundaries: " ++ formatList (map show (nativeAppPlanSendBoundaries plan))
  , "  handlers: " ++ formatList (map renderHandlerBinding handlerBindings)
  , "  transforms: " ++ formatList (map renderTransformBinding transformBindings)
  ]
    ++ ["  ast-modules:"]
    ++ indentLines 4 (map renderAstNode (collectBlueprintNodes blueprint))
    ++ ["  fact-graph:"]
    ++ indentLines 4 (concatMap renderFactRule (nativeAppPlanFactRules plan))
    ++ ["  send-graph:"]
    ++ indentLines 4 (map (renderSendBoundary plan handlerBindings) (nativeAppPlanSendBoundaries plan))
    ++ ["  effect-sections:"]
    ++ indentLines 4 (concatMap renderEffectUnit effectUnits)
  where
    HandlerRegistry handlerBindings =
      effectHandlerRegistry (domainEffectHandlers registration)
    TransformRegistry transformBindings =
      effectHandlerTransforms (domainEffectHandlers registration)

renderAstNode :: AstNode -> String
renderAstNode currentNode =
  astNodeKind currentNode
    ++ " "
    ++ astNodeName currentNode
    ++ " path="
    ++ intercalate "/" (astNodePath currentNode)
    ++ " waits="
    ++ formatList (map show (astNodeWaitFacts currentNode))
    ++ " claims="
    ++ formatList (map show (astNodeClaimFacts currentNode))

renderFactRule :: NativeFactRule -> [String]
renderFactRule currentRule =
  [ show (nativeRuleFact currentRule)
      ++ " source="
      ++ if nativeRuleExternal currentRule then "external" else "internal"
  , "  needs: " ++ formatList (map show (nativeRuleNeeds currentRule))
  , "  pipe-takes: " ++ formatList (map show (nativeRuleTakes currentRule))
  , "  pipe-inputs: " ++ formatList (map show (nativeRuleTakes currentRule))
  , "  pipe-outputs: " ++ formatList (map show (nativeRuleMakes currentRule))
  , "  makes: " ++ formatList (map show (nativeRuleMakes currentRule))
  , "  sends: " ++ formatList (map show (nativeRuleUses currentRule))
  , "  transforms: " ++ formatList (map renderTransformUse (nativeRuleTransforms currentRule))
  , "  error-handlers: " ++ formatList (map show (nativeRuleErrors currentRule))
  , "  failure-facts: none"
  ]

renderSendBoundary :: NativeAppPlan -> [HandlerBinding] -> SendName -> String
renderSendBoundary plan handlerBindings currentSend =
  show currentSend
    ++ " signature="
    ++ renderSendContract currentContract
    ++ " handlers="
    ++ formatList (map (show . handlerBindingName) handlers)
  where
    currentContract =
      [ contract
      | contract <- nativeAppPlanSendContracts plan
      , sendContractName contract == currentSend
      ]
    handlers =
      [ binding
      | binding <- handlerBindings
      , handlerBindingSend binding == currentSend
      ]

renderSendContract :: [SendContract] -> String
renderSendContract [] =
  "missing"
renderSendContract (currentContract : _) =
  show (sendInput signature)
    ++ "->"
    ++ show (sendOutput signature)
    ++ " idempotency="
    ++ show (sendContractIdempotency currentContract)
    ++ " retry="
    ++ show (sendContractRetry currentContract)
  where
    signature =
      sendContractSignature currentContract

renderEffectUnit :: EffectUnit -> [String]
renderEffectUnit currentUnit =
  (show (effectUnitName currentUnit) ++ ":")
    : indentLines 2 (map renderEffectSection (effectUnitSections currentUnit))

renderEffectSection :: EffectSection -> String
renderEffectSection (FactClaimSection producer) =
  "fact " ++ show (producerFact producer)
renderEffectSection (SendSection boundary) =
  "send "
    ++ show (sendBoundaryName boundary)
    ++ " "
    ++ renderSignature (sendBoundarySignature boundary)
renderEffectSection (SendPolicySection policy) =
  "send-policy "
    ++ show (sendPolicyName policy)
    ++ " idempotency="
    ++ maybe "default" show (sendPolicyIdempotency policy)
    ++ " retry="
    ++ maybe "default" show (sendPolicyRetry policy)
renderEffectSection (ExternalTakeSection boundary) =
  "external-take "
    ++ show (externalTakeFact boundary)
    ++ " output="
    ++ maybe "none" show (externalTakeOutput boundary)

renderSignature :: SendSignature -> String
renderSignature signature =
  show (sendInput signature) ++ "->" ++ show (sendOutput signature)

renderHandlerBinding :: HandlerBinding -> String
renderHandlerBinding binding =
  show (handlerBindingSend binding) ++ "->" ++ show (handlerBindingName binding)

renderTransformBinding :: TransformBinding -> String
renderTransformBinding binding =
  show (transformBindingName binding)
    ++ " "
    ++ show (transformBindingInput binding)
    ++ "->"
    ++ show (transformBindingOutput binding)

renderTransformUse :: (TypeName, TypeName, TransformName) -> String
renderTransformUse (input, output, name) =
  show name
    ++ " "
    ++ show input
    ++ "->"
    ++ show output

domainJson :: DomainRegistration -> String
domainJson registration =
  case buildNativeApp blueprint effects of
    Left appError ->
      jsonObject
        ( commonFields
            ++ [("buildError", jsonString (renderNativeAppError appError))]
        )
    Right plan ->
      jsonObject
        ( commonFields
            ++ [ ("effectUnits", jsonArray (map effectUnitJson effectUnits))
               , ("astRootFacts", jsonStringArray (map show (collectBlueprintFacts blueprint)))
               , ("closureFacts", jsonStringArray (map show (nativeAppPlanFacts plan)))
               , ("astModules", jsonArray (map astNodeJson (collectBlueprintNodes blueprint)))
               , ("factGraph", jsonArray (map factRuleJson (nativeAppPlanFactRules plan)))
               , ("sendGraph", jsonArray (map (sendJson plan handlerBindings) (nativeAppPlanSendBoundaries plan)))
               , ("handlers", jsonArray (map handlerJson handlerBindings))
               , ("transforms", jsonArray (map transformJson transformBindings))
               ]
        )
  where
    blueprint =
      astRegistrationBlueprint (domainAst registration)
    effects =
      effectRegistrationTheory (domainEffects registration)
    effectUnits =
      theoryUnits effects
    HandlerRegistry handlerBindings =
      effectHandlerRegistry (domainEffectHandlers registration)
    TransformRegistry transformBindings =
      effectHandlerTransforms (domainEffectHandlers registration)
    commonFields =
      [ ("name", jsonString (domainRegistrationName registration))
      , ("ast", jsonString (astRegistrationName (domainAst registration)))
      , ("effects", jsonString (effectRegistrationName (domainEffects registration)))
      , ("effectHandlers", jsonString (effectHandlerRegistrationName (domainEffectHandlers registration)))
      , ("interpreter", jsonString (interpreterRegistrationName (domainInterpreter registration)))
      ]

effectUnitJson :: EffectUnit -> String
effectUnitJson currentUnit =
  jsonObject
    [ ("name", jsonString (show (effectUnitName currentUnit)))
    , ("sections", jsonArray (map effectSectionJson (effectUnitSections currentUnit)))
    ]

effectSectionJson :: EffectSection -> String
effectSectionJson (FactClaimSection producer) =
  jsonObject
    [ ("kind", jsonString "fact")
    , ("fact", jsonString (show (producerFact producer)))
    ]
effectSectionJson (SendSection boundary) =
  jsonObject
    [ ("kind", jsonString "send")
    , ("send", jsonString (show (sendBoundaryName boundary)))
    , ("input", jsonString (show (sendInput (sendBoundarySignature boundary))))
    , ("output", jsonString (show (sendOutput (sendBoundarySignature boundary))))
    ]
effectSectionJson (SendPolicySection policy) =
  jsonObject
    [ ("kind", jsonString "send-policy")
    , ("send", jsonString (show (sendPolicyName policy)))
    , ("idempotency", jsonString (maybe "default" show (sendPolicyIdempotency policy)))
    , ("retry", jsonString (maybe "default" show (sendPolicyRetry policy)))
    ]
effectSectionJson (ExternalTakeSection boundary) =
  jsonObject
    [ ("kind", jsonString "external-take")
    , ("fact", jsonString (show (externalTakeFact boundary)))
    , ("output", maybe jsonNull (jsonString . show) (externalTakeOutput boundary))
    ]

astNodeJson :: AstNode -> String
astNodeJson currentNode =
  jsonObject
    [ ("kind", jsonString (astNodeKind currentNode))
    , ("name", jsonString (astNodeName currentNode))
    , ("path", jsonStringArray (astNodePath currentNode))
    , ("waitFacts", jsonStringArray (map show (astNodeWaitFacts currentNode)))
    , ("claimFacts", jsonStringArray (map show (astNodeClaimFacts currentNode)))
    ]

factRuleJson :: NativeFactRule -> String
factRuleJson currentRule =
  jsonObject
    [ ("fact", jsonString (show (nativeRuleFact currentRule)))
    , ("source", jsonString (if nativeRuleExternal currentRule then "external" else "internal"))
    , ("needs", jsonStringArray (map show (nativeRuleNeeds currentRule)))
    , ("pipeTakes", jsonStringArray (map show (nativeRuleTakes currentRule)))
    , ("pipeInputs", jsonStringArray (map show (nativeRuleTakes currentRule)))
    , ("pipeOutputs", jsonStringArray (map show (nativeRuleMakes currentRule)))
    , ("makes", jsonStringArray (map show (nativeRuleMakes currentRule)))
    , ("sends", jsonStringArray (map show (nativeRuleUses currentRule)))
    , ("transforms", jsonArray (map transformUseJson (nativeRuleTransforms currentRule)))
    , ("errorHandlers", jsonStringArray (map show (nativeRuleErrors currentRule)))
    , ("failureFacts", jsonStringArray [])
    ]

transformUseJson :: (TypeName, TypeName, TransformName) -> String
transformUseJson (input, output, name) =
  jsonObject
    [ ("name", jsonString (show name))
    , ("input", jsonString (show input))
    , ("output", jsonString (show output))
    ]

sendJson :: NativeAppPlan -> [HandlerBinding] -> SendName -> String
sendJson plan handlerBindings currentSend =
  jsonObject
    [ ("send", jsonString (show currentSend))
    , ("contract", sendContractJson contract)
    , ("handlers", jsonStringArray (map (show . handlerBindingName) handlers))
    ]
  where
    contract =
      [ currentContract
      | currentContract <- nativeAppPlanSendContracts plan
      , sendContractName currentContract == currentSend
      ]
    handlers =
      [ binding
      | binding <- handlerBindings
      , handlerBindingSend binding == currentSend
      ]

sendContractJson :: [SendContract] -> String
sendContractJson [] =
  jsonNull
sendContractJson (currentContract : _) =
  jsonObject
    [ ("input", jsonString (show (sendInput signature)))
    , ("output", jsonString (show (sendOutput signature)))
    , ("idempotency", jsonString (show (sendContractIdempotency currentContract)))
    , ("retry", jsonString (show (sendContractRetry currentContract)))
    ]
  where
    signature =
      sendContractSignature currentContract

handlerJson :: HandlerBinding -> String
handlerJson binding =
  jsonObject
    [ ("send", jsonString (show (handlerBindingSend binding)))
    , ("handler", jsonString (show (handlerBindingName binding)))
    ]

transformJson :: TransformBinding -> String
transformJson binding =
  jsonObject
    [ ("name", jsonString (show (transformBindingName binding)))
    , ("input", jsonString (show (transformBindingInput binding)))
    , ("output", jsonString (show (transformBindingOutput binding)))
    ]

collectBlueprintNodes :: AppBlueprint -> [AstNode]
collectBlueprintNodes blueprint =
  collectWorkflowNodes ["app"] (blueprintApp blueprint)
    ++ collectHangingNodes ["hanging"] (blueprintHanging blueprint)

collectWorkflowNodes :: [String] -> App -> [AstNode]
collectWorkflowNodes path currentWorkflow =
  case currentWorkflow of
    FactWorkflow _ ->
      []
    ChainWorkflow name steps ->
      namedWorkflowNode "chain" (show name) path currentWorkflow
        : concatMap (collectWorkflowNodes (path ++ [show name])) (chainItems steps)
    ParallelWorkflow name branches ->
      namedWorkflowNode "parallel" (show name) path currentWorkflow
        : concatMap (collectWorkflowNodes (path ++ [show name])) (parallelItems branches)
    FallbackWorkflow branches ->
      namedWorkflowNode "fallback" "fallback" path currentWorkflow
        : concatMap (collectWorkflowNodes (path ++ ["fallback"])) (fallbackItems branches)
    RaceWorkflow branches ->
      namedWorkflowNode "race" "race" path currentWorkflow
        : concatMap (collectWorkflowNodes (path ++ ["race"])) (raceItems branches)
    ChoiceWorkflow key choices ->
      namedWorkflowNode "choice" (choiceKeyText key) path currentWorkflow
        : concatMap (collectChoiceBranch (path ++ ["choice:" ++ choiceKeyText key])) (choiceItems choices)
    WaitWorkflow (Wait facts) body ->
      AstNode
        { astNodeKind = "wait"
        , astNodeName = "wait"
        , astNodePath = path ++ ["wait"]
        , astNodeWaitFacts = collectFactExpr facts
        , astNodeClaimFacts = collectWorkflowFacts body
        }
        : collectWorkflowNodes (path ++ ["wait"]) body

collectChoiceBranch :: [String] -> (ChoiceKey, App) -> [AstNode]
collectChoiceBranch path (key, branch) =
  collectWorkflowNodes (path ++ [choiceKeyText key]) branch

namedWorkflowNode :: String -> String -> [String] -> App -> AstNode
namedWorkflowNode kind name path currentWorkflow =
  AstNode
    { astNodeKind = kind
    , astNodeName = name
    , astNodePath = path ++ [name]
    , astNodeWaitFacts = collectWorkflowWaitFacts currentWorkflow
    , astNodeClaimFacts = collectWorkflowFacts currentWorkflow
    }

collectHangingNodes :: [String] -> AppHanging -> [AstNode]
collectHangingNodes path currentHanging =
  concatMap (uncurry (collectHangingAction path)) (zip [(1 :: Int) ..] (hangingItems currentHanging))

collectHangingAction :: [String] -> Int -> HangingAction WorkflowFact Interceptor App -> [AstNode]
collectHangingAction path index currentAction =
  case currentAction of
    HangingCallback (Callback target body) ->
      AstNode
        { astNodeKind = "callback"
        , astNodeName = show target
        , astNodePath = actionPath "callback" (show target)
        , astNodeWaitFacts = collectWorkflowWaitFacts body
        , astNodeClaimFacts = collectWorkflowFacts body
        }
        : collectWorkflowNodes (actionPath "callback" (show target)) body
    HangingSuspense (Suspense target) ->
      [ AstNode
          { astNodeKind = "suspense"
          , astNodeName = show target
          , astNodePath = actionPath "suspense" (show target)
          , astNodeWaitFacts = []
          , astNodeClaimFacts = []
          }
      ]
    HangingLoop (Loop body) ->
      AstNode
        { astNodeKind = "loop"
        , astNodeName = "loop"
        , astNodePath = actionPath "loop" (show index)
        , astNodeWaitFacts = collectWorkflowWaitFacts body
        , astNodeClaimFacts = collectWorkflowFacts body
        }
        : collectWorkflowNodes (actionPath "loop" (show index)) body
    HangingMiddleware (Middleware hook) body ->
      AstNode
        { astNodeKind = "middleware"
        , astNodeName = show hook
        , astNodePath = actionPath "middleware" (show hook)
        , astNodeWaitFacts = collectWorkflowWaitFacts body
        , astNodeClaimFacts = collectWorkflowFacts body
        }
        : collectWorkflowNodes (actionPath "middleware" (show hook)) body
  where
    actionPath kind name =
      path ++ [kind ++ ":" ++ name]

collectBlueprintFacts :: AppBlueprint -> [WorkflowFact]
collectBlueprintFacts blueprint =
  unique
    ( collectWorkflowFacts (blueprintApp blueprint)
        ++ collectHangingFacts (blueprintHanging blueprint)
    )

collectHangingFacts :: AppHanging -> [WorkflowFact]
collectHangingFacts currentHanging =
  concatMap collectHangingActionFacts (hangingItems currentHanging)

collectHangingActionFacts :: HangingAction WorkflowFact Interceptor App -> [WorkflowFact]
collectHangingActionFacts currentAction =
  case currentAction of
    HangingCallback (Callback _ body) ->
      collectWorkflowFacts body
    HangingSuspense _ ->
      []
    HangingLoop (Loop body) ->
      collectWorkflowFacts body
    HangingMiddleware _ body ->
      collectWorkflowFacts body

collectWorkflowFacts :: App -> [WorkflowFact]
collectWorkflowFacts currentWorkflow =
  case currentWorkflow of
    FactWorkflow (Fact facts) ->
      collectFactExpr facts
    ChainWorkflow _ steps ->
      unique (concatMap collectWorkflowFacts (chainItems steps))
    ParallelWorkflow _ branches ->
      unique (concatMap collectWorkflowFacts (parallelItems branches))
    FallbackWorkflow branches ->
      unique (concatMap collectWorkflowFacts (fallbackItems branches))
    RaceWorkflow branches ->
      unique (concatMap collectWorkflowFacts (raceItems branches))
    ChoiceWorkflow _ choices ->
      unique
        [ currentFact
        | (_, branch) <- choiceItems choices
        , currentFact <- collectWorkflowFacts branch
        ]
    WaitWorkflow _ body ->
      collectWorkflowFacts body

collectWorkflowWaitFacts :: App -> [WorkflowFact]
collectWorkflowWaitFacts currentWorkflow =
  case currentWorkflow of
    FactWorkflow _ ->
      []
    ChainWorkflow _ steps ->
      unique (concatMap collectWorkflowWaitFacts (chainItems steps))
    ParallelWorkflow _ branches ->
      unique (concatMap collectWorkflowWaitFacts (parallelItems branches))
    FallbackWorkflow branches ->
      unique (concatMap collectWorkflowWaitFacts (fallbackItems branches))
    RaceWorkflow branches ->
      unique (concatMap collectWorkflowWaitFacts (raceItems branches))
    ChoiceWorkflow _ choices ->
      unique
        [ currentFact
        | (_, branch) <- choiceItems choices
        , currentFact <- collectWorkflowWaitFacts branch
        ]
    WaitWorkflow (Wait facts) body ->
      unique (collectFactExpr facts ++ collectWorkflowWaitFacts body)

collectFactExpr :: FactExpr WorkflowFact -> [WorkflowFact]
collectFactExpr currentExpr =
  case currentExpr of
    FactItems requirement ->
      requirementItems requirement
    FactAll facts ->
      unique (concatMap collectFactExpr facts)
    FactAny facts ->
      unique (concatMap collectFactExpr facts)

selectDomains :: String -> [DomainRegistration]
selectDomains "all" =
  registeredDomains
selectDomains name =
  [ registration
  | registration <- registeredDomains
  , domainRegistrationName registration == name
  ]

choiceKeyText :: ChoiceKey -> String
choiceKeyText (ChoiceKey text) =
  text

indentLines :: Int -> [String] -> [String]
indentLines count =
  map (replicate count ' ' ++)

formatList :: [String] -> String
formatList [] =
  "none"
formatList items =
  intercalate ", " (unique items)

unique :: Eq item => [item] -> [item]
unique =
  foldr addUnique []
  where
    addUnique item items
      | item `elem` items =
          items
      | otherwise =
          item : items

jsonObject :: [(String, String)] -> String
jsonObject fields =
  "{" ++ intercalate "," (map renderField fields) ++ "}"
  where
    renderField (name, value) =
      jsonString name ++ ":" ++ value

jsonArray :: [String] -> String
jsonArray values =
  "[" ++ intercalate "," values ++ "]"

jsonStringArray :: [String] -> String
jsonStringArray =
  jsonArray . map jsonString

jsonString :: String -> String
jsonString text =
  "\"" ++ concatMap escapeJson text ++ "\""

jsonNull :: String
jsonNull =
  "null"

escapeJson :: Char -> String
escapeJson '"' =
  "\\\""
escapeJson '\\' =
  "\\\\"
escapeJson '\n' =
  "\\n"
escapeJson '\r' =
  "\\r"
escapeJson '\t' =
  "\\t"
escapeJson currentChar =
  [currentChar]
