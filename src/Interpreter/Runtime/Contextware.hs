module Interpreter.Runtime.Contextware
  ( contextware
  , contextwareWithEffectEnvironment
  ) where

import Core.Effect.Semantics
  ( effectSemantics
  )
import Core.Workflow.Eff
  ( WorkflowEffAlgebra (..)
  )
import Effects.EffectTheory
  ( EffectTheory
  )
import Interpreter.Runtime.Ensure
  ( ensureFact
  )
import Interpreter.Runtime.Handlers
  ( defaultRuntimeEffectEnvironment
  )
import Interpreter.Runtime.Monad
  ( runtimeEnv
  , withRuntimeEnv
  )
import Interpreter.Runtime.Types
  ( RuntimeContextware
  , RuntimeEnv
  , RuntimeEffectEnvironment
  , RuntimeFAlgebra
  )

contextware :: RuntimeContextware
contextware =
  contextwareWithEffectEnvironment defaultRuntimeEffectEnvironment

contextwareWithEffectEnvironment ::
  RuntimeEffectEnvironment ->
  EffectTheory ->
  RuntimeFAlgebra ->
  RuntimeFAlgebra
contextwareWithEffectEnvironment environment effects algebra =
  contextwareWithRuntimeEnv (runtimeEnv environment (effectSemantics effects)) algebra

contextwareWithRuntimeEnv ::
  RuntimeEnv ->
  RuntimeFAlgebra ->
  RuntimeFAlgebra
contextwareWithRuntimeEnv environment algebra =
  algebra
    { onProduceEff =
        \currentFact ->
          withRuntimeEnv environment (ensureFact (onProduceEff algebra) currentFact)
    }
