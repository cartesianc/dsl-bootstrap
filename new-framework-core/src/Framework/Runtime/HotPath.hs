{-# LANGUAGE PatternSynonyms #-}

module Framework.Runtime.HotPath
  ( RuntimeHotPathEvidencePayload (..)
  , RuntimeHotPathEvidenceStatus (..)
  , renderRuntimeHotPathEvidencePayload
  , renderRuntimeHotPathEvidencePayloadsJson
  , renderRuntimeHotPathEvidenceStatus
  , runtimeHotPathEvidenceArtifactSummary
  , runtimeHotPathCoreClaimNames
  , runtimeHotPathEvidenceClaimNames
  , runtimeHotPathEvidencePayloadPassed
  , runtimeHotPathEvidencePayloads
  ) where

import Bootstrap.Effect
  ( EffectName (..)
  , EffectTheory
  , HandlerName (..)
  , SendName (..)
  , TypeName (..)
  , effect
  , externalMake
  , fact
  , make
  , pattern NoInput
  , theory
  , uses
  )
import Bootstrap.Workflow
  ( AppBlueprint (..)
  , EffectSystemName (..)
  , WorkflowFact (..)
  , effectSystem
  , factItems
  , freeHanging
  , run
  )
import Framework.Runtime.Interpreter
  ( HandlerBinding (..)
  , HandlerRegistry (..)
  , HandlerResult (..)
  , Runtime
  , RuntimeEffectEnvironment
  , RuntimeHandler (..)
  , RuntimeResult (..)
  , RuntimeValue (..)
  , availableFacts
  , runBlueprintWithEffectEnvironmentRuntimeResult
  , runtimeEffectEnvironment
  , runtimeValues
  )

data RuntimeHotPathEvidencePayload = RuntimeHotPathEvidencePayload
  { runtimeHotPathEvidenceClaim :: String
  , runtimeHotPathEvidenceStatus :: RuntimeHotPathEvidenceStatus
  , runtimeHotPathEvidenceExpected :: String
  , runtimeHotPathEvidenceObserved :: String
  , runtimeHotPathEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data RuntimeHotPathEvidenceStatus
  = RuntimeHotPathEvidencePassed
  | RuntimeHotPathEvidenceFailed
  deriving (Eq, Show)

runtimeHotPathEvidencePayloads :: IO [RuntimeHotPathEvidencePayload]
runtimeHotPathEvidencePayloads = do
  interpreterSource <- readFile "new-framework-core/src/Framework/Runtime/Interpreter.hs"
  runtimeResult <-
    runBlueprintWithEffectEnvironmentRuntimeResult
      hotPathEnvironment
      hotPathTheory
      hotPathBlueprint
  let corePayloads =
        [ importBoundaryPayload interpreterSource
        , behaviorPayload runtimeResult
        ]
  pure
    (corePayloads ++ [runtimeHotPathClaimManifestPayload corePayloads])

runtimeHotPathCoreClaimNames :: [String]
runtimeHotPathCoreClaimNames =
  [ "runtime-hot-path-import-boundary"
  , "runtime-hot-path-executes-minimal-workflow"
  ]

runtimeHotPathEvidenceClaimNames :: [String]
runtimeHotPathEvidenceClaimNames =
  runtimeHotPathCoreClaimNames ++ ["runtime-hot-path-claim-manifest"]

runtimeHotPathEvidenceArtifactSummary :: String
runtimeHotPathEvidenceArtifactSummary =
  "runtime hot-path evidence payload claims: "
    ++ joinWith ", " runtimeHotPathEvidenceClaimNames

runtimeHotPathEvidencePayloadPassed :: RuntimeHotPathEvidencePayload -> Bool
runtimeHotPathEvidencePayloadPassed payload =
  runtimeHotPathEvidenceStatus payload == RuntimeHotPathEvidencePassed

renderRuntimeHotPathEvidencePayload :: RuntimeHotPathEvidencePayload -> [String]
renderRuntimeHotPathEvidencePayload payload =
  [ "claim: " ++ runtimeHotPathEvidenceClaim payload
  , "status: " ++ renderRuntimeHotPathEvidenceStatus (runtimeHotPathEvidenceStatus payload)
  , "expected: " ++ runtimeHotPathEvidenceExpected payload
  , "observed: " ++ runtimeHotPathEvidenceObserved payload
  , "artifact: " ++ runtimeHotPathEvidenceArtifact payload
  ]

renderRuntimeHotPathEvidenceStatus :: RuntimeHotPathEvidenceStatus -> String
renderRuntimeHotPathEvidenceStatus RuntimeHotPathEvidencePassed =
  "passed"
renderRuntimeHotPathEvidenceStatus RuntimeHotPathEvidenceFailed =
  "failed"

renderRuntimeHotPathEvidencePayloadsJson :: [RuntimeHotPathEvidencePayload] -> String
renderRuntimeHotPathEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "runtime-hot-path-evidence.v1")
    , jsonField "status" (jsonString statusText)
    , jsonField "payloads" (jsonArray (map runtimeHotPathEvidencePayloadJson payloads))
    ]
  where
    statusText =
      if all runtimeHotPathEvidencePayloadPassed payloads
        then "passed"
        else "failed"

importBoundaryPayload :: String -> RuntimeHotPathEvidencePayload
importBoundaryPayload source =
  hotPathEvidence
    "runtime-hot-path-import-boundary"
    passed
    "typed runtime hot path does not import report, evidence, fixed-point, registry codegen, trust base, or artifact gate modules"
    observed
    "RuntimeHotPathImportBoundaryArtifact"
  where
    forbidden =
      [ "Bootstrap.Report"
      , "Framework.FixedPoint"
      , "Framework.RegistryCodegen"
      , "Framework.Runtime.Evidence"
      , "Framework.Runtime.HotPath"
      , "Framework.Runtime.Policy"
      , "Framework.SelfArtifact"
      , "Framework.TrustBase"
      ]
    present =
      [ item
      | item <- forbidden
      , item `containsIn` source
      ]
    passed =
      null present
    observed =
      if passed
        then "no forbidden hot-path imports found"
        else "forbidden imports found: " ++ joinWith ", " present

behaviorPayload :: RuntimeResult Runtime -> RuntimeHotPathEvidencePayload
behaviorPayload result =
  hotPathEvidence
    "runtime-hot-path-executes-minimal-workflow"
    passed
    "typed runtime executes minimal workflow and records only business fact/value state"
    observed
    "RuntimeHotPathExecutionArtifact"
  where
    passed =
      case result of
        RuntimeSucceeded runtime _ ->
          hotPathFact `elem` availableFacts runtime
            && RuntimeValue hotPathOutput "hot-path-ok" `elem` runtimeValues runtime
            && noEvidenceArtifacts runtime
        RuntimeFailed _ _ ->
          False
    observed =
      case result of
        RuntimeSucceeded runtime _ ->
          "facts="
            ++ show (map show (availableFacts runtime))
            ++ "; values="
            ++ show (map runtimeValueText (runtimeValues runtime))
        RuntimeFailed errorReport _ ->
          "runtime failed: " ++ show errorReport

noEvidenceArtifacts :: Runtime -> Bool
noEvidenceArtifacts runtime =
  null
    [ value
    | value <- runtimeValues runtime
    , "Evidence" `containsIn` show (runtimeValueType value)
        || "Report" `containsIn` show (runtimeValueType value)
        || "ArtifactGate" `containsIn` show (runtimeValueType value)
    ]

hotPathEvidence :: String -> Bool -> String -> String -> String -> RuntimeHotPathEvidencePayload
hotPathEvidence claim passed expected observed artifact =
  RuntimeHotPathEvidencePayload
    { runtimeHotPathEvidenceClaim = claim
    , runtimeHotPathEvidenceStatus =
        if passed
          then RuntimeHotPathEvidencePassed
          else RuntimeHotPathEvidenceFailed
    , runtimeHotPathEvidenceExpected = expected
    , runtimeHotPathEvidenceObserved = observed
    , runtimeHotPathEvidenceArtifact = artifact
    }

runtimeHotPathClaimManifestPayload :: [RuntimeHotPathEvidencePayload] -> RuntimeHotPathEvidencePayload
runtimeHotPathClaimManifestPayload payloads =
  hotPathEvidence
    "runtime-hot-path-claim-manifest"
    manifestSynced
    "runtime hot-path payload claims match exported claim manifest"
    observed
    "RuntimeHotPathClaimManifestArtifact"
  where
    actualCoreClaimNames =
      map runtimeHotPathEvidenceClaim payloads
    actualEvidenceClaimNames =
      actualCoreClaimNames ++ ["runtime-hot-path-claim-manifest"]
    manifestSynced =
      actualCoreClaimNames == runtimeHotPathCoreClaimNames
        && actualEvidenceClaimNames == runtimeHotPathEvidenceClaimNames
    observed =
      if manifestSynced
        then "claim manifest synced: " ++ show (length actualCoreClaimNames) ++ " core claims"
        else "expected " ++ show runtimeHotPathEvidenceClaimNames ++ "; actual " ++ show actualEvidenceClaimNames

hotPathBlueprint :: AppBlueprint
hotPathBlueprint =
  AppBlueprint
    { blueprintApp =
        run
          ( effectSystem
              (EffectSystemName "RuntimeHotPathFlow")
              (factItems [hotPathFact])
          )
    , blueprintHanging = freeHanging []
    }

hotPathTheory :: EffectTheory
hotPathTheory =
  theory
    [ effect
        (EffectName "RuntimeHotPathEffect")
        [ externalMake hotPathSend NoInput hotPathOutput
        , fact hotPathFact
            [ uses hotPathSend
            , make hotPathOutput
            ]
        ]
    ]

hotPathEnvironment :: RuntimeEffectEnvironment
hotPathEnvironment =
  runtimeEffectEnvironment
    ( HandlerRegistry
        [ HandlerBinding
            hotPathSend
            (HandlerName "RuntimeHotPathHandler")
            hotPathHandler
        ]
    )

hotPathHandler :: RuntimeHandler
hotPathHandler =
  RuntimeHandler
    ( \_ _ _ ->
        pure
          ( HandlerSucceeded
              [ RuntimeValue hotPathOutput "hot-path-ok"
              ]
          )
    )

hotPathFact :: WorkflowFact
hotPathFact =
  WorkflowFact "RuntimeHotPathFact"

hotPathSend :: SendName
hotPathSend =
  SendName "RuntimeHotPathSend"

hotPathOutput :: TypeName
hotPathOutput =
  TypeName "RuntimeHotPathOutput"

runtimeHotPathEvidencePayloadJson :: RuntimeHotPathEvidencePayload -> String
runtimeHotPathEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (runtimeHotPathEvidenceClaim payload))
    , jsonField "status" (jsonString (renderRuntimeHotPathEvidenceStatus (runtimeHotPathEvidenceStatus payload)))
    , jsonField "expected" (jsonString (runtimeHotPathEvidenceExpected payload))
    , jsonField "observed" (jsonString (runtimeHotPathEvidenceObserved payload))
    , jsonField "artifact" (jsonString (runtimeHotPathEvidenceArtifact payload))
    ]

jsonObject :: [String] -> String
jsonObject fields =
  "{" ++ joinWith "," fields ++ "}"

jsonField :: String -> String -> String
jsonField name value =
  jsonString name ++ ":" ++ value

jsonArray :: [String] -> String
jsonArray values =
  "[" ++ joinWith "," values ++ "]"

jsonString :: String -> String
jsonString value =
  "\"" ++ concatMap jsonChar value ++ "\""

jsonChar :: Char -> String
jsonChar currentChar =
  case currentChar of
    '"' ->
      "\\\""
    '\\' ->
      "\\\\"
    '\n' ->
      "\\n"
    '\r' ->
      "\\r"
    '\t' ->
      "\\t"
    _ ->
      [currentChar]

containsIn :: String -> String -> Bool
containsIn needle haystack =
  any (startsWith needle) (tails haystack)

startsWith :: String -> String -> Bool
startsWith [] _ =
  True
startsWith _ [] =
  False
startsWith (left : leftRest) (right : rightRest)
  | left == right =
      startsWith leftRest rightRest
  | otherwise =
      False

tails :: [item] -> [[item]]
tails [] =
  [[]]
tails value@(_ : rest) =
  value : tails rest

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
