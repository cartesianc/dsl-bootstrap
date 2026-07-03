module Bootstrap.Runtime.Contract
  ( validateRuntimeArtifactClosure
  , validateRuntimeFactRuleClosure
  , validateRuntimeHandlerRegistry
  , validateRuntimePlanBuilt
  , validateRuntimeSendBoundaryCoverage
  , validateRuntimeTransformRegistry
  ) where

import Bootstrap.Runtime.Build
  ( isPipeType
  , nativePlanPassed
  , renderNativePlanErrors
  )
import Bootstrap.Runtime.Types
import Bootstrap.Effect
  ( SendName
  , TransformName
  , TypeName
  )
import Bootstrap.Workflow
  ( WorkflowFact )

validateRuntimePlanBuilt :: NativeAppPlan -> Either String String
validateRuntimePlanBuilt plan
  | nativePlanPassed plan =
      Right
        ( "runtime plan built: facts "
            ++ show (length (nativeAppPlanFacts plan))
            ++ ", roots "
            ++ show (length (nativeAppPlanRootFacts plan))
            ++ ", sends "
            ++ show (length (nativeAppPlanSendBoundaries plan))
            ++ ", constraints "
            ++ show (length (nativeAppPlanConstraints plan))
        )
  | otherwise =
      Left (renderNativePlanErrors plan)

validateRuntimeFactRuleClosure :: NativeAppPlan -> Either String String
validateRuntimeFactRuleClosure plan =
  case rootErrors ++ needErrors of
    [] ->
      Right
        ( "runtime fact rule closure validated: rules "
            ++ show (length rules)
            ++ ", roots "
            ++ show (length (nativeAppPlanRootFacts plan))
            ++ ", needs "
            ++ show (sum (map (length . nativeRuleNeeds) rules))
        )
    errors ->
      Left (joinLines errors)
  where
    rules =
      nativeAppPlanFactRules plan
    ruleFacts =
      map nativeRuleFact rules
    rootErrors =
      [ "missing root fact rule " ++ show currentFact
      | currentFact <- nativeAppPlanRootFacts plan
      , currentFact `notElem` ruleFacts
      ]
    needErrors =
      [ "missing needed fact " ++ show neededFact ++ " for " ++ show (nativeRuleFact rule)
      | rule <- rules
      , neededFact <- nativeRuleNeeds rule
      , neededFact `notElem` ruleFacts
      ]

validateRuntimeArtifactClosure :: NativeAppPlan -> Either String String
validateRuntimeArtifactClosure plan =
  case makerErrors ++ takeErrors of
    [] ->
      Right
        ( "runtime artifact closure validated: pipe types "
            ++ show (length pipeTypes)
            ++ ", takes "
            ++ show (length pipeTakes)
        )
    errors ->
      Left (joinLines errors)
  where
    rules =
      nativeAppPlanFactRules plan
    pipeTypes =
      unique (filter isPipeType (concatMap nativeRuleMakes rules))
    pipeTakes =
      [ currentType
      | rule <- rules
      , currentType <- nativeRuleTakes rule
      , isPipeType currentType
      ]
    makerErrors =
      [ "pipe type must have one maker "
          ++ show currentType
          ++ ", makers: "
          ++ show makers
      | currentType <- pipeTypes
      , let makers = sourceFactsForTypeFromRules rules currentType
      , length makers /= 1
      ]
    takeErrors =
      [ "take must have one maker "
          ++ show (nativeRuleFact rule)
          ++ " takes "
          ++ show currentType
          ++ ", makers: "
          ++ show makers
      | rule <- rules
      , currentType <- nativeRuleTakes rule
      , isPipeType currentType
      , let makers = sourceFactsForTypeFromRules rules currentType
      , length makers /= 1
      ]

validateRuntimeSendBoundaryCoverage :: NativeAppPlan -> Either String String
validateRuntimeSendBoundaryCoverage plan =
  case missingSendErrors of
    [] ->
      Right
        ( "runtime send boundary coverage validated: declared "
            ++ show (length declaredSends)
            ++ ", used "
            ++ show (length usedSends)
            ++ ", error "
            ++ show (length errorSends)
        )
    errors ->
      Left (joinLines errors)
  where
    declaredSends =
      map sendContractName (nativeAppPlanSendContracts plan)
    usedSends =
      unique (concatMap nativeRuleUses (nativeAppPlanFactRules plan))
    errorSends =
      unique (concatMap nativeRuleErrors (nativeAppPlanFactRules plan))
    missingSendErrors =
      [ "missing send boundary " ++ show currentSend
      | currentSend <- unique (usedSends ++ errorSends)
      , currentSend `notElem` declaredSends
      ]

validateRuntimeHandlerRegistry :: NativeAppPlan -> HandlerRegistry -> Either String String
validateRuntimeHandlerRegistry plan registry =
  case handlerErrors of
    [] ->
      Right
        ( "runtime handler registry validated: boundaries "
            ++ show (length (nativeAppPlanSendBoundaries plan))
            ++ ", bindings "
            ++ show (length (handlerRegistryBindings registry))
        )
    errors ->
      Left (joinLines errors)
  where
    handlerErrors =
      [ "send boundary must have one handler "
          ++ show currentSend
          ++ ", handlers: "
          ++ show (map handlerBindingName handlers)
      | currentSend <- nativeAppPlanSendBoundaries plan
      , let handlers = handlersFor registry currentSend
      , length handlers /= 1
      ]

validateRuntimeTransformRegistry :: NativeAppPlan -> TransformRegistry -> Either String String
validateRuntimeTransformRegistry plan registry =
  case transformErrors of
    [] ->
      Right
        ( "runtime transform registry validated: required "
            ++ show (length requiredTransforms)
            ++ ", bindings "
            ++ show (length (transformRegistryBindings registry))
        )
    errors ->
      Left (joinLines errors)
  where
    requiredTransforms =
      unique (concatMap nativeRuleTransforms (nativeAppPlanFactRules plan))
    transformErrors =
      [ "transform use must have one binding "
          ++ show name
          ++ ": "
          ++ show inputType
          ++ " -> "
          ++ show outputType
          ++ ", bindings: "
          ++ show matches
      | (inputType, outputType, name) <- requiredTransforms
      , let matches = transformBindingsFor registry inputType outputType name
      , length matches /= 1
      ]

handlersFor :: HandlerRegistry -> SendName -> [HandlerBinding]
handlersFor registry currentSend =
  [ binding
  | binding <- handlerRegistryBindings registry
  , handlerBindingSend binding == currentSend
  ]

transformBindingsFor :: TransformRegistry -> TypeName -> TypeName -> TransformName -> [TransformBinding]
transformBindingsFor registry inputType outputType name =
  [ binding
  | binding <- transformRegistryBindings registry
  , transformBindingName binding == name
  , transformBindingInput binding == inputType
  , transformBindingOutput binding == outputType
  ]

sourceFactsForTypeFromRules :: [NativeFactRule] -> TypeName -> [WorkflowFact]
sourceFactsForTypeFromRules rules currentType =
  [ nativeRuleFact rule
  | rule <- rules
  , currentType `elem` nativeRuleMakes rule
  ]

unique :: Eq item => [item] -> [item]
unique =
  foldl appendUnique []

appendUnique :: Eq item => [item] -> item -> [item]
appendUnique items item
  | item `elem` items =
      items
  | otherwise =
      items ++ [item]

joinLines :: [String] -> String
joinLines [] =
  ""
joinLines [line] =
  line
joinLines (line : rest) =
  line ++ "\n" ++ joinLines rest
