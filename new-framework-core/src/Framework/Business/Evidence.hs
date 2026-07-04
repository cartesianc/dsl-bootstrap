module Framework.Business.Evidence
  ( BusinessSyntaxEvidencePayload (..)
  , BusinessSyntaxEvidenceStatus (..)
  , businessSyntaxClaimManifestEvidenceClaimName
  , businessSyntaxCoreClaimNames
  , businessSyntaxEvidence
  , businessSyntaxEvidenceArtifactSummary
  , businessSyntaxEvidenceClaimNames
  , businessSyntaxEvidencePayloadPassed
  , renderBusinessSyntaxEvidencePayloadsJson
  , renderBusinessSyntaxEvidenceStatus
  ) where

data BusinessSyntaxEvidencePayload = BusinessSyntaxEvidencePayload
  { businessSyntaxEvidenceClaim :: String
  , businessSyntaxEvidenceStatus :: BusinessSyntaxEvidenceStatus
  , businessSyntaxEvidenceExpected :: String
  , businessSyntaxEvidenceObserved :: String
  , businessSyntaxEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data BusinessSyntaxEvidenceStatus
  = BusinessSyntaxEvidencePassed
  | BusinessSyntaxEvidenceFailed
  deriving (Eq, Show)

businessSyntaxCoreClaimNames :: [String]
businessSyntaxCoreClaimNames =
  [ "business-syntax-needs-lowering"
  , "business-syntax-take-lowering"
  , "business-syntax-make-lowering"
  , "business-syntax-uses-lowering"
  , "business-syntax-external-make-lowering"
  , "business-syntax-transform-lowering"
  , "business-syntax-effects-facade-lowering"
  , "business-syntax-domain-business-boundary"
  , "business-syntax-domain-effect-vocabulary-boundary"
  , "business-syntax-effects-facade-boundary"
  , "business-syntax-domain-runtime-handler-boundary"
  , "business-syntax-handler-binding-alignment"
  , "business-syntax-pipeline-adjacent-transform"
  , "business-syntax-runtime-pipeline-adapter"
  , "effect-system-boundary-metadata"
  , "effect-system-scope-metadata"
  , "business-syntax-capability-system-boundary"
  , "business-syntax-capability-private-fact-boundary"
  ]

businessSyntaxEvidenceClaimNames :: [String]
businessSyntaxEvidenceClaimNames =
  businessSyntaxCoreClaimNames ++ [businessSyntaxClaimManifestEvidenceClaimName]

businessSyntaxClaimManifestEvidenceClaimName :: String
businessSyntaxClaimManifestEvidenceClaimName =
  "business-syntax-claim-manifest"

businessSyntaxEvidenceArtifactSummary :: String
businessSyntaxEvidenceArtifactSummary =
  "business syntax evidence payload claims: "
    ++ joinWith ", " businessSyntaxEvidenceClaimNames

businessSyntaxEvidence :: String -> Bool -> String -> String -> String -> BusinessSyntaxEvidencePayload
businessSyntaxEvidence claim passed expected observed artifact =
  BusinessSyntaxEvidencePayload
    { businessSyntaxEvidenceClaim = claim
    , businessSyntaxEvidenceStatus =
        if passed
          then BusinessSyntaxEvidencePassed
          else BusinessSyntaxEvidenceFailed
    , businessSyntaxEvidenceExpected = expected
    , businessSyntaxEvidenceObserved = observed
    , businessSyntaxEvidenceArtifact = artifact
    }

businessSyntaxEvidencePayloadPassed :: BusinessSyntaxEvidencePayload -> Bool
businessSyntaxEvidencePayloadPassed payload =
  businessSyntaxEvidenceStatus payload == BusinessSyntaxEvidencePassed

renderBusinessSyntaxEvidencePayloadsJson :: [BusinessSyntaxEvidencePayload] -> String
renderBusinessSyntaxEvidencePayloadsJson payloads =
  jsonObject
    [ jsonField "schema" (jsonString "business-syntax-evidence.v1")
    , jsonField "status" (jsonString statusText)
    , jsonField "payloads" (jsonArray (map businessSyntaxEvidencePayloadJson payloads))
    ]
  where
    statusText =
      if all businessSyntaxEvidencePayloadPassed payloads
        then "passed"
        else "failed"

businessSyntaxEvidencePayloadJson :: BusinessSyntaxEvidencePayload -> String
businessSyntaxEvidencePayloadJson payload =
  jsonObject
    [ jsonField "claim" (jsonString (businessSyntaxEvidenceClaim payload))
    , jsonField "status" (jsonString (renderBusinessSyntaxEvidenceStatus (businessSyntaxEvidenceStatus payload)))
    , jsonField "expected" (jsonString (businessSyntaxEvidenceExpected payload))
    , jsonField "observed" (jsonString (businessSyntaxEvidenceObserved payload))
    , jsonField "artifact" (jsonString (businessSyntaxEvidenceArtifact payload))
    ]

renderBusinessSyntaxEvidenceStatus :: BusinessSyntaxEvidenceStatus -> String
renderBusinessSyntaxEvidenceStatus BusinessSyntaxEvidencePassed =
  "passed"
renderBusinessSyntaxEvidenceStatus BusinessSyntaxEvidenceFailed =
  "failed"

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

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
