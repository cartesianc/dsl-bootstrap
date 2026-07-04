module Domain.Registry
  ( DomainRegistration (..)
  , DomainRegistry (..)
  , domainRegistry
  , frameworkCoreDomain
  , printAstRegistration
  , printFrameworkCoreAstTree
  , printRegisteredAstTrees
  , renderDomainRegistry
  , renderDomainRegistryJson
  , renderFrameworkCoreAstTree
  , renderFrameworkCoreAstTreeJson
  , renderRegisteredAstTreesJson
  , registeredDomains
  , runDomain
  , runFrameworkCoreDomain
  ) where

import Domain.Ast
  ( AstRegistration (..)
  , frameworkCoreAstRegistration
  , registeredAsts
  )
import Domain.EffectHandlers
  ( EffectHandlerRegistration (..)
  , frameworkCoreEffectHandlerRegistration
  , registeredEffectHandlers
  )
import Domain.Effects
  ( EffectRegistration (..)
  , frameworkCoreEffectRegistration
  , registeredEffects
  )
import Domain.Interpreter
  ( AstTreeNode (..)
  , InterpreterRegistration (..)
  , astTreeStructure
  , frameworkCoreInterpreterRegistration
  , printAstTree
  , registeredInterpreters
  , renderAstTree
  , runRegisteredInterpreter
  )
import Data.List
  ( intercalate
  )

data DomainRegistration = DomainRegistration
  { domainRegistrationName :: String
  , domainAst :: AstRegistration
  , domainEffects :: EffectRegistration
  , domainEffectHandlers :: EffectHandlerRegistration
  , domainInterpreter :: InterpreterRegistration
  }

data DomainRegistry = DomainRegistry
  { registryAsts :: [AstRegistration]
  , registryEffects :: [EffectRegistration]
  , registryEffectHandlers :: [EffectHandlerRegistration]
  , registryInterpreters :: [InterpreterRegistration]
  , registryDomains :: [DomainRegistration]
  }

domainRegistry :: DomainRegistry
domainRegistry =
  DomainRegistry
    { registryAsts = registeredAsts
    , registryEffects = registeredEffects
    , registryEffectHandlers = registeredEffectHandlers
    , registryInterpreters = registeredInterpreters
    , registryDomains = registeredDomains
    }

frameworkCoreDomain :: DomainRegistration
frameworkCoreDomain =
  DomainRegistration
    { domainRegistrationName = "framework-core"
    , domainAst = frameworkCoreAstRegistration
    , domainEffects = frameworkCoreEffectRegistration
    , domainEffectHandlers = frameworkCoreEffectHandlerRegistration
    , domainInterpreter = frameworkCoreInterpreterRegistration
    }

registeredDomains :: [DomainRegistration]
registeredDomains =
  [frameworkCoreDomain]

runFrameworkCoreDomain :: IO ()
runFrameworkCoreDomain =
  runDomain frameworkCoreDomain

runDomain :: DomainRegistration -> IO ()
runDomain registration =
  runRegisteredInterpreter
    (domainInterpreter registration)
    (effectHandlerEnvironment (domainEffectHandlers registration))
    (astRegistrationBlueprint (domainAst registration))
    (effectRegistrationTheory (domainEffects registration))

renderFrameworkCoreAstTree :: [String]
renderFrameworkCoreAstTree =
  renderAstTree (astRegistrationBlueprint (domainAst frameworkCoreDomain))

printFrameworkCoreAstTree :: IO ()
printFrameworkCoreAstTree =
  printAstRegistration (domainAst frameworkCoreDomain)

printRegisteredAstTrees :: IO ()
printRegisteredAstTrees =
  mapM_ printAstRegistration registeredAsts

printAstRegistration :: AstRegistration -> IO ()
printAstRegistration registration = do
  putStrLn ("== ast " ++ astRegistrationName registration ++ " ==")
  printAstTree (astRegistrationBlueprint registration)

renderDomainRegistry :: [String]
renderDomainRegistry =
  [ "domain registry"
  , "asts: " ++ joinNames (map astRegistrationName (registryAsts domainRegistry))
  , "effects: " ++ joinNames (map effectRegistrationName (registryEffects domainRegistry))
  , "effect-handlers: " ++ joinNames (map effectHandlerRegistrationName (registryEffectHandlers domainRegistry))
  , "interpreters: " ++ joinNames (map interpreterRegistrationName (registryInterpreters domainRegistry))
  , "domains: " ++ joinNames (map domainRegistrationName (registryDomains domainRegistry))
  , "framework-core-domain: " ++ domainRegistrationName frameworkCoreDomain
  , "framework-core-ast: " ++ astRegistrationName (domainAst frameworkCoreDomain)
  , "framework-core-effects: " ++ effectRegistrationName (domainEffects frameworkCoreDomain)
  , "framework-core-effect-handlers: " ++ effectHandlerRegistrationName (domainEffectHandlers frameworkCoreDomain)
  , "framework-core-interpreter: " ++ interpreterRegistrationName (domainInterpreter frameworkCoreDomain)
  ]

renderDomainRegistryJson :: String
renderDomainRegistryJson =
  jsonObject
    [ ("schema", jsonString "domain-registry.v1")
    , ("asts", jsonStringArray (map astRegistrationName (registryAsts domainRegistry)))
    , ("effects", jsonStringArray (map effectRegistrationName (registryEffects domainRegistry)))
    , ("effectHandlers", jsonStringArray (map effectHandlerRegistrationName (registryEffectHandlers domainRegistry)))
    , ("interpreters", jsonStringArray (map interpreterRegistrationName (registryInterpreters domainRegistry)))
    , ("domains", jsonArray (map domainRegistrationJson (registryDomains domainRegistry)))
    , ("frameworkCore", domainRegistrationJson frameworkCoreDomain)
    ]

renderRegisteredAstTreesJson :: String
renderRegisteredAstTreesJson =
  renderAstTreeRegistryJson registeredAsts

renderFrameworkCoreAstTreeJson :: String
renderFrameworkCoreAstTreeJson =
  renderAstTreeRegistryJson [frameworkCoreAstRegistration]

renderAstTreeRegistryJson :: [AstRegistration] -> String
renderAstTreeRegistryJson registrations =
  jsonObject
    [ ("schema", jsonString "ast-tree.v1")
    , ("asts", jsonArray (map astRegistrationJson registrations))
    ]

domainRegistrationJson :: DomainRegistration -> String
domainRegistrationJson registration =
  jsonObject
    [ ("name", jsonString (domainRegistrationName registration))
    , ("ast", jsonString (astRegistrationName (domainAst registration)))
    , ("effects", jsonString (effectRegistrationName (domainEffects registration)))
    , ("effectHandlers", jsonString (effectHandlerRegistrationName (domainEffectHandlers registration)))
    , ("interpreter", jsonString (interpreterRegistrationName (domainInterpreter registration)))
    ]

astRegistrationJson :: AstRegistration -> String
astRegistrationJson registration =
  jsonObject
    [ ("name", jsonString (astRegistrationName registration))
    , ("tree", astTreeNodeJson tree)
    , ("executionPaths", jsonArray (map astTreePathJson (astTreePathProjection tree)))
    , ("textTree", jsonStringArray (renderAstTree (astRegistrationBlueprint registration)))
    ]
  where
    tree =
      astTreeStructure (astRegistrationBlueprint registration)

astTreeNodeJson :: AstTreeNode -> String
astTreeNodeJson node =
  jsonObject
    [ ("kind", jsonString (astTreeNodeKind node))
    , ("name", jsonString (astTreeNodeName node))
    , ("path", jsonStringArray (astTreeNodePath node))
    , ("metadata", jsonArray (map metadataJson (astTreeNodeMetadata node)))
    , ("children", jsonArray (map astTreeNodeJson (astTreeNodeChildren node)))
    ]

metadataJson :: (String, [String]) -> String
metadataJson (name, values) =
  jsonObject
    [ ("name", jsonString name)
    , ("values", jsonStringArray values)
    ]

astTreePathProjection :: AstTreeNode -> [AstTreeNode]
astTreePathProjection node =
  node : concatMap astTreePathProjection (astTreeNodeChildren node)

astTreePathJson :: AstTreeNode -> String
astTreePathJson node =
  jsonObject
    [ ("path", jsonStringArray (astTreeNodePath node))
    , ("kind", jsonString (astTreeNodeKind node))
    , ("name", jsonString (astTreeNodeName node))
    ]

joinNames :: [String] -> String
joinNames [] =
  "none"
joinNames [name] =
  name
joinNames (name : rest) =
  name ++ ", " ++ joinNames rest

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
