module Interpreter.View.Program
  ( Program
  , firstChildIndent
  , childIndent
  , factProgram
  , printFactExpr
  , printNode
  , renderChoiceKey
  , renderFacts
  , renderInterceptor
  , renderWorkflowName
  , runChildren
  , runChoiceBranch
  ) where

import Data.Char
  ( toLower
  )

import AST.Vocabulary
import Core.Architecture
import Core.Architecture.Internal
  ( ChoiceBranch (..)
  , RequirementEffect (..)
  )

type Program = Int -> IO ()

firstChildIndent :: Int
firstChildIndent =
  indentStep

indentStep :: Int
indentStep =
  4

childIndent :: Int -> Int
childIndent indent =
  indent + indentStep

factProgram :: Fact WorkflowFact -> Program
factProgram currentFact indent =
  case factExpression currentFact of
    FactItems currentFacts ->
      printNode indent ("fact " ++ renderFacts currentFacts)
    currentFacts -> do
      printNode indent "fact"
      printFactExpr (childIndent indent) currentFacts

printFactExpr :: Int -> FactExpr WorkflowFact -> IO ()
printFactExpr indent (FactItems currentFacts) =
  printNode indent ("fact " ++ renderFacts currentFacts)
printFactExpr indent (FactAll currentFacts) = do
  printNode indent "and"
  mapM_ (printFactExpr (childIndent indent)) currentFacts
printFactExpr indent (FactAny currentFacts) = do
  printNode indent "or"
  mapM_ (printFactExpr (childIndent indent)) currentFacts

runChildren :: Int -> [Program] -> IO ()
runChildren indent =
  mapM_ (\child -> child indent)

runChoiceBranch :: Int -> ChoiceBranch ChoiceKey Program -> IO ()
runChoiceBranch indent (ChoiceBranch key body) = do
  printNode indent ("branch " ++ renderChoiceKey key)
  body (childIndent indent)

printNode :: Int -> String -> IO ()
printNode indent =
  putStrLn . indentLine indent . ("|-- " ++)

indentLine :: Int -> String -> String
indentLine indent text =
  replicate indent ' ' ++ text

renderFacts :: Requirement WorkflowFact -> String
renderFacts currentFacts =
  "[" ++ joinWith ", " (map renderWorkflowFact (requirementEffectItems (requirementFacts currentFacts))) ++ "]"

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
