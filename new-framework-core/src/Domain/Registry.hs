module Domain.Registry
  ( DomainRegistration (..)
  , DomainRegistry (..)
  , domainRegistry
  , frameworkCoreDomain
  , printAstRegistration
  , printFrameworkCoreAstTree
  , printRegisteredAstTrees
  , renderDomainRegistry
  , renderFrameworkCoreAstTree
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
  ( InterpreterRegistration (..)
  , frameworkCoreInterpreterRegistration
  , printAstTree
  , registeredInterpreters
  , renderAstTree
  , runRegisteredInterpreter
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

joinNames :: [String] -> String
joinNames [] =
  "none"
joinNames [name] =
  name
joinNames (name : rest) =
  name ++ ", " ++ joinNames rest
