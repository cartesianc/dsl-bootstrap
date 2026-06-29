module Core.Workflow.Semantics.Render
  ( printBlueprintProgram
  , renderBlueprintProgram
  , renderHangingProgram
  , renderWorkflowProgram
  ) where

import AST.AppBlueprint
  ( AppBlueprint (..)
  )
import Core.Architecture
import Core.Architecture.Internal
  ( ChoiceBranch (..)
  , freeAlternativeBranches
  , freeApplicativeBranches
  , freeChoiceBranches
  , freeMonadSteps
  , freeMonoidItems
  , requirementEffectItems
  )
import Core.Workflow.Semantics
  ( HangingProgram (..)
  , HangingProgramAction (..)
  , WorkflowProgram (..)
  , lowerHanging
  , lowerWorkflow
  )

renderBlueprintProgram :: AppBlueprint -> [String]
renderBlueprintProgram blueprint =
  [ "blueprint"
  , indent 1 "app"
  ]
    ++ map (indent 2) (renderWorkflowProgram (lowerWorkflow (blueprintApp blueprint)))
    ++ [ indent 1 "hanging"
       ]
    ++ map (indent 2) (renderHangingProgram (lowerHanging (blueprintHanging blueprint)))

printBlueprintProgram :: AppBlueprint -> IO ()
printBlueprintProgram =
  mapM_ putStrLn . renderBlueprintProgram

renderWorkflowProgram :: Show fact => WorkflowProgram fact -> [String]
renderWorkflowProgram currentProgram =
  case currentProgram of
    ProgramFact currentFact ->
      renderFact currentFact
    ProgramChain label steps ->
      ("chain " ++ show label) : renderWorkflowChildren (freeMonadSteps (chainSteps steps))
    ProgramParallel label branches ->
      ("parallel " ++ show label) : renderWorkflowChildren (freeApplicativeBranches (parallelBranches branches))
    ProgramFallback branches ->
      "fallback" : renderWorkflowChildren (freeAlternativeBranches (fallbackBranches branches))
    ProgramRace branches ->
      "race" : renderWorkflowChildren (freeAlternativeBranches (raceBranches branches))
    ProgramChoice selectedKey branches ->
      ("choice " ++ renderChoiceKey selectedKey) : concatMap renderChoiceBranch (freeChoiceBranches (choiceBranches branches))
    ProgramWait facts body ->
      ("wait " ++ renderFactExpr (waitFacts facts)) : map (indent 1) (renderWorkflowProgram body)

renderHangingProgram :: (Show fact, Show hook) => HangingProgram fact hook -> [String]
renderHangingProgram =
  concatMap renderHangingAction . freeMonoidItems . hangingActions . hangingProgramActions

renderHangingAction :: (Show fact, Show hook) => HangingProgramAction fact hook -> [String]
renderHangingAction currentAction =
  case currentAction of
    ProgramCallback currentCallback ->
      ("callback " ++ renderFactExpr (callbackFacts currentCallback)) : map (indent 1) (renderWorkflowProgram (callbackBody currentCallback))
    ProgramSuspense currentSuspense ->
      ("suspense " ++ renderFactExpr (suspenseFacts currentSuspense)) : map (indent 1) (renderWorkflowProgram (suspenseTarget currentSuspense))
    ProgramLoop currentLoop ->
      "loop" : map (indent 1) (renderWorkflowProgram (loopBody currentLoop))
    ProgramMiddleware currentMiddleware body ->
      ("middleware " ++ show (middlewareHook currentMiddleware)) : map (indent 1) (renderWorkflowProgram body)

renderWorkflowChildren :: Show fact => [WorkflowProgram fact] -> [String]
renderWorkflowChildren =
  concatMap (map (indent 1) . renderWorkflowProgram)

renderChoiceBranch :: Show fact => ChoiceBranch ChoiceKey (WorkflowProgram fact) -> [String]
renderChoiceBranch (ChoiceBranch key body) =
  ("branch " ++ renderChoiceKey key) : map (indent 1) (renderWorkflowProgram body)

renderFact :: Show fact => Fact fact -> [String]
renderFact currentFact =
  case factExpression currentFact of
    FactItems currentFacts ->
      ["fact " ++ renderFacts currentFacts]
    currentFacts ->
      "fact" : map (indent 1) (renderFactExprLines currentFacts)

renderFactExpr :: Show fact => FactExpr fact -> String
renderFactExpr (FactItems currentFacts) =
  renderFacts currentFacts
renderFactExpr (FactAll currentFacts) =
  "allOf " ++ show (map renderFactExpr currentFacts)
renderFactExpr (FactAny currentFacts) =
  "anyOf " ++ show (map renderFactExpr currentFacts)

renderFactExprLines :: Show fact => FactExpr fact -> [String]
renderFactExprLines (FactItems currentFacts) =
  ["fact " ++ renderFacts currentFacts]
renderFactExprLines (FactAll currentFacts) =
  "allOf" : concatMap (map (indent 1) . renderFactExprLines) currentFacts
renderFactExprLines (FactAny currentFacts) =
  "anyOf" : concatMap (map (indent 1) . renderFactExprLines) currentFacts

renderFacts :: Show fact => Requirement fact -> String
renderFacts currentFacts =
  show (requirementEffectItems (requirementFacts currentFacts))

renderChoiceKey :: ChoiceKey -> String
renderChoiceKey (ChoiceKey value) =
  value

indent :: Int -> String -> String
indent level text =
  replicate (level * 2) ' ' ++ text
