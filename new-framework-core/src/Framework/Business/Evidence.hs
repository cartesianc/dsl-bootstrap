module Framework.Business.Evidence
  ( businessSyntaxClaimManifestEvidenceClaimName
  , businessSyntaxCoreClaimNames
  , businessSyntaxEvidenceArtifactSummary
  , businessSyntaxEvidenceClaimNames
  ) where

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

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
