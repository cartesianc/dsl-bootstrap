{-# LANGUAGE PatternSynonyms #-}

module Framework.Frontend.Evidence
  ( FrontendClaimModuleLink (..)
  , frameworkCoreFrontendCoreClaimNames
  , frameworkCoreFrontendEvidenceClaimNames
  , frontendClaimModuleLinkEvidenceClaimName
  , frontendClaimModuleLinks
  ) where

import Domain.Vocabulary
  ( pattern AstStructureExpressedFact
  , pattern EffectTheoryDslExpressedFact
  , pattern RegistryCodegenExpressedFact
  , pattern RuntimeBackendParityExpressedFact
  , pattern RuntimeConcurrencySemanticsExpressedFact
  , pattern RuntimeDiagnosisExpressedFact
  , pattern RuntimeFactClosureExpressedFact
  , pattern SelfArtifactManifestExpressedFact
  )
import Framework.Ast
  ( WorkflowFact )
import Framework.RegistryCodegen
  ( GeneratedSource (..)
  , frameworkCoreFrontendSources
  )

data FrontendClaimModuleLink = FrontendClaimModuleLink
  { frontendClaimModuleFact :: WorkflowFact
  , frontendClaimModuleName :: String
  }
  deriving (Eq, Show)

frontendClaimModuleLinks :: [FrontendClaimModuleLink]
frontendClaimModuleLinks =
  [ FrontendClaimModuleLink AstStructureExpressedFact "Framework.Ast"
  , FrontendClaimModuleLink EffectTheoryDslExpressedFact "Framework.Effect"
  , FrontendClaimModuleLink RuntimeConcurrencySemanticsExpressedFact "Framework.Runtime.Concurrency"
  , FrontendClaimModuleLink RuntimeDiagnosisExpressedFact "Framework.Runtime.Diagnosis"
  , FrontendClaimModuleLink RuntimeBackendParityExpressedFact "Framework.FixedPoint"
  , FrontendClaimModuleLink RuntimeFactClosureExpressedFact "Framework.Runtime.Evidence"
  , FrontendClaimModuleLink RegistryCodegenExpressedFact "Framework.RegistryCodegen"
  , FrontendClaimModuleLink SelfArtifactManifestExpressedFact "Framework.SelfArtifact"
  ]

frameworkCoreFrontendCoreClaimNames :: [String]
frameworkCoreFrontendCoreClaimNames =
  map generatedSourceClaimName frameworkCoreFrontendSources
    ++ map frontendClaimModuleLinkEvidenceClaimName frontendClaimModuleLinks
    ++ [ "framework-core-frontend-core-surface-exposed-modules"
       , "framework-core-frontend-runtime-diagnosis-implementation-boundary"
       ]

frameworkCoreFrontendEvidenceClaimNames :: [String]
frameworkCoreFrontendEvidenceClaimNames =
  frameworkCoreFrontendCoreClaimNames ++ ["framework-core-frontend-claim-manifest"]

frontendClaimModuleLinkEvidenceClaimName :: FrontendClaimModuleLink -> String
frontendClaimModuleLinkEvidenceClaimName link =
  "framework-core-frontend-claim-link:" ++ show (frontendClaimModuleFact link)

generatedSourceClaimName :: GeneratedSource -> String
generatedSourceClaimName source =
  "framework-core-frontend-generated-source:" ++ generatedSourcePath source
