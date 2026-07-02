# dsl-bootstrap

`dsl-bootstrap` is a self-bootstrapping Haskell framework for writing an application as declarative source:

- workflow AST
- effect theory
- typed runtime handlers
- semantic evidence
- framework self-validation

The repository is organized around two active packages:

```text
new-framework-core
  Kernel, public facade, runtime, proof API, self-domain source, and bootstrap reports.

domain-app
  A real frontend/domain package written with the same facade style as framework-core.
```

The checked-in source is the core source. The self-artifact gate builds an isolated Stage 1 package from this source and validates it before a replacement or release.

## Quick Start

Build everything:

```powershell
stack build
```

Run the domain frontend:

```powershell
stack exec mytest
```

Build the domain report:

```powershell
stack exec domain-app-report
```

Run the framework fixed point:

```powershell
stack exec fixed-point-smoke
```

Run the workflow semantics witness:

```powershell
stack exec workflow-semantics-witness
```

Build and validate an isolated Stage 1 artifact:

```powershell
stack exec self-artifact-witness
```

Expected headline results:

```text
domain-app-report: status passed
bootstrap-report: status passed
fixed-point-smoke: diffs: 0
workflow-semantics-witness: ok workflow semantics evidence
self-artifact-witness: passed
```

## Architecture

The public authoring surface is the `Framework.*` facade:

```haskell
import Framework.Workflow
import Framework.Effect
import Framework.Background
```

Facade modules:

```text
Framework.Workflow        workflow AST constructors
Framework.Effect          effect theory DSL
Framework.Background      runtime, reports, diagnosis, proof facade
Framework.Runtime         typed RuntimeM interpreter API
Framework.Domain          domain registration and reports
Framework.FixedPoint      bootstrap-vs-facade evidence comparison
Framework.RegistryCodegen registry rendering and generated-line checks
Framework.SelfArtifact    isolated Stage 1 artifact materialization
```

Internal layers:

```text
Bootstrap.*
  Native bootstrap kernel used by framework-core self-validation.

Domain.*
  Framework-core's own self-domain expression written through the facade style.

domain-app/src/*
  Frontend/domain code. It imports facade modules and local domain modules.
```

Boundary rules:

```text
Bootstrap.* does not import Framework.*.
domain-app/src and domain-app/app do not import Bootstrap.*.
new-framework-core/src/Domain expresses framework-core through the public facade style.
```

Check the boundaries with:

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
```

Both commands should return no matches.

## Authoring A Domain

The domain app shows the intended shape for frontend code:

```text
domain-app/src/Domain/Vocabulary.hs
domain-app/src/Domain/AppBlueprint.hs
domain-app/src/Effects/Theory.hs
domain-app/src/Domain/Runtime.hs
domain-app/src/Domain/SemanticEvidence.hs
domain-app/src/SelfDomainApp.hs
domain-app/app/Main.hs
```

### 1. Define Vocabulary

Declare domain facts, send names, type names, and transform names in `Domain.Vocabulary` and `Domain.EffectVocabulary`.

Use stable names. Reports, runtime traces, diagnosis, and proof evidence all flow through these names.

### 2. Write The Workflow AST

Use `Blueprint` and `Framework.Workflow` in `Domain.AppBlueprint`.

Common workflow constructors:

```text
chain
parallel
fallback
race
choice
wait
fact
hanging
middleware
callback
suspense
loop
```

Workflow runtime semantics:

```text
chain      runs steps in order and stops on the first failure
parallel   starts all branches concurrently from the same input runtime, then merges successful branch state deterministically
race       starts all branches concurrently, keeps the first successful branch, and cancels the remaining branches
fallback   tries branches in order; failed branch state is discarded before trying the next branch
choice     runs only the branch matching the selected ChoiceKey
wait       satisfies the fact expression before running the body
factAny    tries alternatives in order and keeps the first successful alternative
loop       runs until facts/runtime values reach a fixed point, capped at 16 iterations
callback   runs when the target component is entered; callback failure is recorded but does not fail the target flow
middleware records entered/exited events around the body, including failure paths
suspense   records target status plus a lightweight RuntimeSnapshot; it is not database persistence
```

Example shape:

```haskell
appFlow :: App
appFlow =
  chain AppFlow
    [ parallel BootPreparation
        [ fact [AppStartedFact]
        , fact [RuntimePreparedFact]
        ]
    , wait
        (allOf [UserKnownFact])
        (fact [ReportGeneratedFact])
    ]
```

### 3. Declare The Effect Theory

Use `Framework.Effect` in `Effects.*`.

Core producer steps:

```text
needs          fact dependency
take           pipe input type
make           pipe output type
uses           external send boundary
externalMake   send boundary declaration
transform      typed value transform
error          error handler dispatch
idempotent     replay-safe send marker
retry          retry policy
```

The effect theory is the contract that links workflow facts to runtime handlers and generated reports.

### 4. Implement Runtime Handlers

Use `Framework.Background` and `Framework.Runtime` in `Domain.Runtime`.

The runtime supports:

```text
RuntimeM
RuntimeTypedValue
SomeRuntimeValue
ValueTag
RuntimeHandler
HandlerSucceededTyped
RuntimeTransform
HandlerRegistry
TransformRegistry
RuntimeEffectEnvironment
```

The current domain demonstrates this typed pipeline:

```text
AskUserName -> UserName
UserNameToReportInput: UserName -> ReportInput
GenerateReport: ReportInput -> ReportOutput
```

### 5. Wire The Entrypoint

The frontend executable uses the declarative source directly:

```haskell
main :: IO ()
main =
  currentInterpreter currentAst currentEffects
```

Run it with:

```powershell
stack exec mytest
```

### 6. Register Semantic Evidence

Domain evidence lives in `Domain.SemanticEvidence` and is attached through `SelfDomainApp`.

Current evidence includes:

```text
constraint-ir-built
constraint-proof-passed
constraint-negative-check
runtime-closure-executed
runtime-diagnosis-error-handler
runtime-diagnosis-retry-probe
runtime-diagnosis-non-idempotent-blocker
registry-codegen-plugins
registry-codegen-effects
```

Run:

```powershell
stack exec domain-app-report
stack exec domain-app-self-smoke
```

## Diagnosis And Proof

`Framework.Background` re-exports runtime diagnosis and constraint proof APIs:

```text
Framework.Background.RuntimeDiagnosis
Framework.Background.ConstraintProof
```

Runtime diagnosis covers:

```text
handler failure
output mismatch
missing handler input
missing transform
error handler dispatch with ErrorInput
idempotent RetryOnce replay
diagnosis probes
non-idempotent replay blockers
```

Constraint/proof support covers:

```text
constraint IR extraction
pure Haskell proof evidence
optional z3 or cvc5 solver witness
render helpers for facts, errors, propositions, and results
```

Run:

```powershell
stack exec runtime-diagnosis-witness
stack exec constraint-proof-witness
```

## Registry Codegen

Registry codegen is expressed inside the framework semantics.

Domain registry specs live in:

```text
domain-app/src/Domain/RegistryCodegenSpec.hs
```

Generated-line evidence checks:

```text
domain-app/src/Plugins.hs
domain-app/src/Effects/Theory.hs
```

Run:

```powershell
stack exec registry-codegen-witness
```

## Self-Bootstrap

Every framework change should prove itself before commit.

Core self-validation:

```powershell
stack exec framework-core-mytest
stack exec bootstrap-smoke
stack exec bootstrap-runtime-smoke
stack exec bootstrap-report
stack exec fixed-point-smoke
```

The fixed-point check compares:

```text
Stage 0: Bootstrap.* direct framework-core report
Stage 1: Framework.* facade/domain framework-core report
```

Accepted result:

```text
fixed-point-smoke: diffs: 0
```

The artifact gate materializes `.generated/stage1-framework` and runs that isolated package through:

```text
stack build
stack exec bootstrap-report
stack exec fixed-point-smoke
stack exec domain-app-report
stack exec registry-codegen-witness
```

Run:

```powershell
stack exec self-artifact-witness
```

Detailed gate rules are in [docs/SELF_BOOTSTRAP_GATE.md](docs/SELF_BOOTSTRAP_GATE.md).
Workflow runtime rules are in [docs/WORKFLOW_SEMANTICS.md](docs/WORKFLOW_SEMANTICS.md).

## Command Reference

Daily development:

```powershell
stack build
stack exec mytest
stack exec domain-app-report
```

Framework validation:

```powershell
stack exec framework-core-mytest
stack exec bootstrap-smoke
stack exec bootstrap-runtime-smoke
stack exec bootstrap-report
stack exec fixed-point-smoke
```

Witnesses:

```powershell
stack exec runtime-diagnosis-witness
stack exec constraint-proof-witness
stack exec workflow-semantics-witness
stack exec registry-codegen-witness
stack exec self-artifact-witness
```

Full gate:

```powershell
stack build
stack exec mytest
stack exec domain-app-report
stack exec domain-app-self-smoke
stack exec framework-core-mytest
stack exec bootstrap-smoke
stack exec bootstrap-runtime-smoke
stack exec bootstrap-report
stack exec fixed-point-smoke
stack exec workflow-semantics-witness
stack exec runtime-diagnosis-witness
stack exec constraint-proof-witness
stack exec registry-codegen-witness
stack exec self-artifact-witness
```
