module Interpreter.View.Algebra
  ( Tree (..)
  , blueprintViewAlgebra
  , renderTree
  ) where

import Data.Char
  ( toLower
  )

import Architecture
import Architecture.Cata
import Architecture.Internal
  ( ChoiceBranch (..)
  , FreeAlternative (..)
  , FreeApplicative (..)
  , FreeChoice (..)
  , FreeMonad (..)
  , RequirementEffect (..)
  )
import AST.Vocabulary

data Tree = Tree String [Tree]

blueprintViewAlgebra :: WorkflowAlgebra WorkflowFact Interceptor Tree
blueprintViewAlgebra =
  WorkflowAlgebra
    { onEffect = effectTree
    , onChain = chainTree
    , onParallel = parallelTree
    , onFallback = fallbackTree
    , onRace = raceTree
    , onChoice = choiceTree
    , onCallback = callbackTree
    , onMiddleware = middlewareTree
    }

effectTree :: Effect WorkflowFact -> Tree
effectTree currentEffect =
  Tree ("effect " ++ renderFacts (effectFacts currentEffect)) []

chainTree :: WorkflowName -> Chain Tree -> Tree
chainTree label steps =
  Tree ("chain " ++ renderWorkflowName label) (freeMonadSteps (chainSteps steps))

parallelTree :: WorkflowName -> Parallel Tree -> Tree
parallelTree label branches =
  Tree ("parallel " ++ renderWorkflowName label) (freeApplicativeBranches (parallelBranches branches))

fallbackTree :: Fallback Tree -> Tree
fallbackTree branches =
  Tree "fallback" (freeAlternativeBranches (fallbackBranches branches))

raceTree :: Race Tree -> Tree
raceTree branches =
  Tree "race" (freeAlternativeBranches (raceBranches branches))

choiceTree :: ChoiceKey -> Choice Tree -> Tree
choiceTree selectedKey choices =
  Tree
    ("choice " ++ renderChoiceKey selectedKey)
    (map choiceBranchTree (freeChoiceBranches (choiceBranches choices)))

callbackTree :: Callback WorkflowFact -> Tree -> Tree
callbackTree facts body =
  Tree ("callback " ++ renderFacts (callbackFacts facts)) [body]

middlewareTree :: Middleware Interceptor -> Tree -> Tree
middlewareTree currentMiddleware body =
  Tree ("middleware " ++ renderInterceptor (middlewareHook currentMiddleware)) [body]

choiceBranchTree :: ChoiceBranch ChoiceKey Tree -> Tree
choiceBranchTree (ChoiceBranch key body) =
  Tree ("branch " ++ renderChoiceKey key) [body]

renderTree :: Tree -> [String]
renderTree (Tree label children) =
  label : renderChildren 4 children

renderChildren :: Int -> [Tree] -> [String]
renderChildren indent =
  concatMap (renderChildAt indent)

renderChildAt :: Int -> Tree -> [String]
renderChildAt indent (Tree label children) =
  indentLine indent ("|-- " ++ label)
    : renderChildren (indent + 4) children

indentLine :: Int -> String -> String
indentLine indent text =
  replicate indent ' ' ++ text

renderFacts :: Requirement WorkflowFact -> String
renderFacts facts =
  "[" ++ joinWith ", " (map renderWorkflowFact (requirementEffectItems (requirementFacts facts))) ++ "]"

renderWorkflowFact :: WorkflowFact -> String
renderWorkflowFact =
  show

renderInterceptor :: Interceptor -> String
renderInterceptor =
  lowerFirst . show

renderChoiceKey :: ChoiceKey -> String
renderChoiceKey (ChoiceKey value) =
  value

renderWorkflowName :: WorkflowName -> String
renderWorkflowName =
  lowerFirst . show

lowerFirst :: String -> String
lowerFirst [] =
  []
lowerFirst (firstChar : rest) =
  toLower firstChar : rest

joinWith :: String -> [String] -> String
joinWith _ [] =
  ""
joinWith _ [item] =
  item
joinWith separator (item : rest) =
  item ++ separator ++ joinWith separator rest
