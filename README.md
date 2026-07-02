# dsl-bootstrap

`dsl-bootstrap` is a small Haskell framework experiment for describing an app as:

- a workflow AST
- an effect theory
- a runtime environment
- a domain report that proves the AST/effect/runtime contract closes

The current architecture has two active packages:

```text
new-framework-core
  Framework kernel, facade modules, bootstrap evidence, and self-domain expression.

domain-app
  The frontend domain source. It uses the same facade DSL shape as framework-core.
```

## Current Shape

The project now uses one source style for framework and domain code.

Framework-core expresses itself through `Domain.*` modules:

```text
new-framework-core/src/Domain/AppBlueprint.hs
new-framework-core/src/Domain/Effects.hs
new-framework-core/src/Domain/Vocabulary.hs
```

Domain-app expresses the frontend through the same layers:

```text
domain-app/src/Domain/AppBlueprint.hs
domain-app/src/Effects/Theory.hs
domain-app/src/Domain/Runtime.hs
domain-app/app/Main.hs
```

The frontend entrypoint is:

```haskell
main :: IO ()
main =
  currentInterpreter currentAst currentEffects
```

Run it with:

```powershell
stack exec mytest
```

## Public Facade

Frontend/domain code should import the public facade:

```haskell
import Framework.Workflow
import Framework.Effect
import Framework.Background
```

The stable facade modules are:

```text
Framework.Workflow
Framework.Effect
Framework.Background
Framework.Domain
Framework.Runtime
Framework.FixedPoint
```

`Bootstrap.*` remains the kernel/native bootstrap layer. `Bootstrap.*` must not import `Framework.*`.

## Runtime

`Framework.Background` exposes the production runtime API through `Framework.Runtime`.

Supported runtime behavior includes:

- typed runtime values
- typed handler results
- transform registry execution
- middleware enter/exit trace
- callback trigger/completion trace
- suspense request trace
- loop start trace
- fact closure execution
- handler coverage reporting

The domain app demonstrates typed runtime flow:

```text
AskUserName -> UserName
UserNameToReportInput: UserName -> ReportInput
GenerateReport: ReportInput -> ReportOutput
```

## Workflow Expression

The workflow AST supports the frontend expression used by old-version:

- `chain`
- `parallel`
- `fallback`
- `race`
- `choice`
- `wait`
- `fact`
- `hanging`
- `middleware`
- `callback`
- `suspense`
- `loop`

Both framework-core and domain-app use this shape through facade imports.

## Effect System

The effect DSL supports:

- fact declarations
- dependencies through `needs`
- pipe input through `take`
- pipe output through `make`
- external sends through `uses`
- external boundaries through `externalMake`
- transform declarations
- send policies such as idempotency and retry metadata
- handler coverage in reports

Framework-core self expression uses `Framework.Effect` in `Domain.Effects`.
Domain-app uses the same facade in `Effects.*`.

## Diagnosis And SMT Status

Current implementation status:

- Runtime failures have structured `RuntimeError` values and rendered failure output.
- Bootstrap evidence includes core boundary, frontend boundary, language spec, elaboration contract, constraint IR, and SMT proof facts.
- `bootstrap-report` and `fixed-point-smoke` verify the self-domain evidence path.
- A full old-version-style public `RuntimeDiagnosis` module is still pending.
- A full public SMT solver adapter module is still pending.

The current SMT path is represented as bootstrap evidence via `RunSmtProof` and `SmtProofPassedFact`. Public solver APIs should be restored in a later stage.

## Package Boundaries

Expected boundaries:

```text
Bootstrap.* -> no Framework.* imports
domain-app/src -> no Bootstrap.* imports
domain-app/app/Main.hs -> currentInterpreter currentAst currentEffects
new-framework-core/src/Domain/* -> self-domain facade expression
```

`new-framework-core/src/Domain/*` is allowed to import `Framework.Workflow` and `Framework.Effect` so framework-core can describe itself with the same facade style as domain-app.

## Reports And Smoke Commands

Build:

```powershell
stack build
```

Frontend/domain app:

```powershell
stack exec mytest
stack exec domain-app-report
stack exec domain-app-self-smoke
```

Framework-core bootstrap and self evidence:

```powershell
stack exec framework-core-mytest
stack exec bootstrap-smoke
stack exec bootstrap-runtime-smoke
stack exec bootstrap-report
stack exec fixed-point-smoke
```

Expected high-level results:

```text
domain-app-report: passed
domain-app-self-smoke: passed
bootstrap-report: passed
fixed-point-smoke: diffs: 0
```

## Next Work

Recommended next stage:

1. Restore public diagnosis modules.
2. Restore public SMT/proof adapter modules.
3. Add focused runtime assertion tests for fallback, race, choice, failure, retry metadata, and handler output mismatch.
4. Restore automatic plugin/effect registry generation after the semantic APIs settle.
5. Add a compact architecture diagram/report generated from the domain registry.
