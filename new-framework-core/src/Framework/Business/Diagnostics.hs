module Framework.Business.Diagnostics
  ( renderBusinessShapeDiagnostic
  , renderBusinessShapeDiagnostics
  , renderRuntimeErrorDiagnostic
  ) where

import Bootstrap.Business
  ( BusinessShapeIssue (..)
  , renderBusinessShapeIssue
  )
import Framework.Runtime.Types
  ( RuntimeError (..) )

renderBusinessShapeDiagnostics :: [BusinessShapeIssue] -> [String]
renderBusinessShapeDiagnostics =
  map renderBusinessShapeDiagnostic

renderBusinessShapeDiagnostic :: BusinessShapeIssue -> String
renderBusinessShapeDiagnostic issue =
  case issue of
    CapabilityHasNoProducer name ->
      "Capability " ++ name ++ " does not produce a fact and does not declare a send boundary. Add produces/uses/onError, or remove the empty capability. Underlying detail: " ++ renderBusinessShapeIssue issue
    HandlerImplementsUnknownCapability handlerName name ->
      "Handler binding " ++ show handlerName ++ " points at unknown capability " ++ name ++ ". Change handlerBinding implements to an existing capability name. Underlying detail: " ++ renderBusinessShapeIssue issue
    HandlerConsumesMismatch handlerName name expected actual ->
      "Handler binding " ++ show handlerName ++ " does not consume the artifacts declared by capability " ++ name ++ ". Expected " ++ show expected ++ ", got " ++ show actual ++ ". Align handlerBinding inputs with the capability uses/input clauses."
    HandlerEmitsMismatch handlerName name expected actual ->
      "Handler binding " ++ show handlerName ++ " does not emit the artifacts declared by capability " ++ name ++ ". Expected " ++ show expected ++ ", got " ++ show actual ++ ". Align handlerBinding outputs with the capability uses/output clauses."
    HandlerClaimsMismatch handlerName name expected actual ->
      "Handler binding " ++ show handlerName ++ " claims facts outside capability " ++ name ++ ". Expected a subset of " ++ show expected ++ ", got " ++ show actual ++ ". Move the claim to the capability produces list or remove it from the handler binding."
    TransformBindingOutsidePipeline transformName inputType outputType ->
      "Transform " ++ show transformName ++ " is declared for " ++ show inputType ++ " -> " ++ show outputType ++ ", but that edge is not adjacent in any capability pipeline. Add the adjacent pipeline edge or correct the transform binding."
    FactNameMissingSuffix currentFact ->
      "Business fact " ++ show currentFact ++ " should end with Fact. Rename the fact so state and runtime artifacts stay distinguishable. Underlying detail: " ++ renderBusinessShapeIssue issue
    ArtifactNameLooksLikeFact typeName ->
      "Runtime artifact type " ++ show typeName ++ " looks like a business fact. Rename the artifact type without the Fact suffix. Underlying detail: " ++ renderBusinessShapeIssue issue
    FactArtifactNameCollision currentFact typeName ->
      "Business fact " ++ show currentFact ++ " collides with runtime artifact " ++ show typeName ++ ". Rename one side so facts and typed values stay separate. Underlying detail: " ++ renderBusinessShapeIssue issue

renderRuntimeErrorDiagnostic :: RuntimeError -> String
renderRuntimeErrorDiagnostic errorReport =
  case errorReport of
    RuntimeMissingFactRule fact ->
      "The app waits for " ++ show fact ++ ", but no capability/effect rule produces it. Add a produces/privateFact rule for that fact or change the AppBlueprint requirement."
    RuntimeMissingSendBoundary send ->
      "A capability uses " ++ show send ++ ", but the effect theory has no matching send boundary. Declare the uses/onError through Framework.Business, or add the matching externalMake boundary in normalized IR."
    RuntimeMissingHandler send ->
      "A capability uses " ++ show send ++ ", but RuntimeEffectEnvironment has no handler registered for that send. Add a HandlerBinding in Domain.Runtime for " ++ show send ++ "."
    RuntimeMissingHandlerInput send inputType ->
      "Handler " ++ show send ++ " needs input artifact " ++ show inputType ++ ", but that value is not available at the send boundary. Check the capability pipeline, input, transform, and producer declarations."
    RuntimeHandlerOutputMismatch send expected actual ->
      "Handler " ++ show send ++ " returned the wrong output shape. Expected " ++ show expected ++ ", got " ++ show actual ++ ". Align the runtime handler output with the capability uses/output declaration."
    RuntimeHandlerFailed send message ->
      "Handler " ++ show send ++ " failed while executing the declared capability. Fix the handler implementation or add an onError policy for this boundary. Underlying detail: " ++ message
    RuntimeMissingTransform transformName ->
      "A capability pipeline declares transform " ++ show transformName ++ ", but RuntimeEffectEnvironment has no TransformBinding for it. Register the transform in Domain.Runtime."
    RuntimeMissingTransformInput transformName inputType ->
      "Transform " ++ show transformName ++ " needs input artifact " ++ show inputType ++ ", but the artifact was not produced. Check pipeline adjacency and the preceding capability output."
    RuntimeTransformInputMismatch transformName expected actual ->
      "Transform " ++ show transformName ++ " received " ++ show actual ++ " but expects " ++ show expected ++ ". Align the transform binding with the pipeline edge."
    RuntimeTransformSignatureMismatch transformName expectedInput expectedOutput actualInput actualOutput ->
      "Transform " ++ show transformName ++ " is registered with shape " ++ show actualInput ++ " -> " ++ show actualOutput ++ ", but the capability pipeline expects " ++ show expectedInput ++ " -> " ++ show expectedOutput ++ "."
    RuntimeWaitBlocked message ->
      renderWaitBlockedDiagnostic message
    RuntimeChoiceMissingBranch message ->
      "The AppBlueprint selected a choice branch that was not declared. Fix the branch key in the workflow. Underlying detail: " ++ message
    RuntimeParallelBranchFailed index nested ->
      "Parallel branch " ++ show index ++ " failed. Fix that branch's capability requirements first. Underlying detail: " ++ renderRuntimeErrorDiagnostic nested
    RuntimeParallelMergeConflict message ->
      "Parallel branches produced conflicting runtime state. Make the branches produce distinct facts/artifacts or define an explicit merge path. Underlying detail: " ++ message
    RuntimeFallbackExhausted ->
      "Every fallback branch failed. Add a viable branch or fix the capability requirements in the existing branches."
    RuntimeRaceEmpty ->
      "The AppBlueprint declares an empty race. Add at least one branch."
    RuntimeRaceExhausted ->
      "Every race branch failed. Fix at least one branch so the race can complete."
    RuntimeLoopExceeded count ->
      "The workflow loop did not reach a fixed point within " ++ show count ++ " iterations. Check the loop body for a capability that keeps changing runtime state."
    RuntimeIoException message ->
      "Runtime IO failed inside a handler. Fix the handler implementation or wrap it with an explicit error boundary. Underlying detail: " ++ message

renderWaitBlockedDiagnostic :: String -> String
renderWaitBlockedDiagnostic message
  | "missing send boundary" `containsIn` message =
      "A capability declares uses/onError, but the matching send boundary is missing from the effect theory. Add the corresponding uses/onError through Framework.Business. Underlying detail: " ++ message
  | "missing or duplicate pipe maker" `containsIn` message =
      "A capability takes an artifact, but the pipeline has zero or multiple producers for that artifact. Make exactly one capability produce the input type. Underlying detail: " ++ message
  | "rule uses transform outside pipeline edge" `containsIn` message =
      "A transform is declared outside the adjacent capability pipeline edge. Fix the pipeline order or the transform binding. Underlying detail: " ++ message
  | "effect system import has no exporter" `containsIn` message =
      "An effect system imports a fact that no capability exports. Add produces for that fact or remove the import. Underlying detail: " ++ message
  | "effect system import references private fact" `containsIn` message =
      "An effect system imports another system's private fact. Export a public fact instead, or keep the dependency inside the same capability group. Underlying detail: " ++ message
  | "handler references undeclared send" `containsIn` message =
      "A handler binding references a send that is not declared by the capability boundary. Add the uses/onError declaration or fix the handler binding. Underlying detail: " ++ message
  | "handler send must have one handler" `containsIn` message =
      "A send boundary must have exactly one handler binding. Register one handler for the capability send and remove duplicates. Underlying detail: " ++ message
  | otherwise =
      "The app plan is blocked by a declaration mismatch. Fix the capability/effect declaration reported by the underlying detail: " ++ message

containsIn :: String -> String -> Bool
containsIn needle haystack =
  any (startsWith needle) (tails haystack)

startsWith :: String -> String -> Bool
startsWith [] _ =
  True
startsWith _ [] =
  False
startsWith (left : leftRest) (right : rightRest)
  | left == right =
      startsWith leftRest rightRest
  | otherwise =
      False

tails :: [item] -> [[item]]
tails [] =
  [[]]
tails value@(_ : rest) =
  value : tails rest
