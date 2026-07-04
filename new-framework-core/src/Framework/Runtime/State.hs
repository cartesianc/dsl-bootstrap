module Framework.Runtime.State
  ( emptyRuntime
  , renderRuntimeSnapshot
  , runtimeSnapshot
  ) where

import Framework.Runtime.Types

emptyRuntime :: Runtime
emptyRuntime =
  Runtime
    { availableFacts = []
    , availablePipeTypes = []
    , runtimeValues = []
    , runtimeTypedValues = []
    , runtimeFactClaims = []
    , runtimeTrace = []
    , runtimeActiveComponents = []
    , runtimeCompletedComponents = []
    , runtimeComponentEvents = []
    , runtimeCallbackEvents = []
    , runtimeSuspenseEvents = []
    , runtimeActiveContexts = []
    , runtimeContextEvents = []
    , runtimeMiddlewareStack = []
    , runtimeMiddlewareEvents = []
    , runtimeFailureDiagnoses = []
    }

runtimeSnapshot :: Runtime -> RuntimeSnapshot
runtimeSnapshot runtime =
  RuntimeSnapshot
    { snapshotAvailableFacts = availableFacts runtime
    , snapshotAvailablePipeTypes = availablePipeTypes runtime
    , snapshotRuntimeValues = runtimeValues runtime
    , snapshotRuntimeTypedValues = runtimeTypedValues runtime
    , snapshotRuntimeFactClaims = runtimeFactClaims runtime
    , snapshotRuntimeActiveComponents = runtimeActiveComponents runtime
    , snapshotRuntimeCompletedComponents = runtimeCompletedComponents runtime
    , snapshotRuntimeActiveContexts = runtimeActiveContexts runtime
    , snapshotRuntimeContextEvents = runtimeContextEvents runtime
    , snapshotRuntimeTrace = runtimeTrace runtime
    }

renderRuntimeSnapshot :: RuntimeSnapshot -> [String]
renderRuntimeSnapshot snapshot =
  [ "runtime snapshot"
  , "  facts: " ++ show (snapshotAvailableFacts snapshot)
  , "  pipe types: " ++ show (snapshotAvailablePipeTypes snapshot)
  , "  values: " ++ show (snapshotRuntimeValues snapshot)
  , "  typed values: " ++ show (snapshotRuntimeTypedValues snapshot)
  , "  fact claims: " ++ show (snapshotRuntimeFactClaims snapshot)
  , "  active components: " ++ show (snapshotRuntimeActiveComponents snapshot)
  , "  completed components: " ++ show (snapshotRuntimeCompletedComponents snapshot)
  , "  active contexts: " ++ show (snapshotRuntimeActiveContexts snapshot)
  , "  context events: " ++ show (length (snapshotRuntimeContextEvents snapshot))
  , "  trace lines: " ++ show (length (snapshotRuntimeTrace snapshot))
  ]
