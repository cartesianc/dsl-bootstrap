# Local Gates

Use the smallest gate that proves the touched semantics, but keep ordinary
architecture iteration on the self-interpret spine:

```text
core_0 -> new_core -> empty_business
```

## Default

For ordinary framework iteration:

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
```

`core-self-interpret-report.v1` is the first-class proof. It covers:

```text
previous compiled core runs the new core foreground
new core runs as a domain expression
empty_business closes recursion without IO or TrustBase leakage
boot AST layout expansion
runtime cursor projection through explicit hanging context
runtime node status overlay
default gate consolidation
artifact gate command consolidation
core_0 ~= core_1 normalized fixed-point evidence
```

## Guardrails

For semantic/release guardrails after the default proof:

```powershell
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

The default scripts reflect this:

```powershell
.\scripts\check-fast.cmd -List
.\scripts\check-semantic.cmd -List
.\scripts\check-release.cmd -List
```

## Business Boundary Acceptance

Business boundary tests still matter, but they sit after the self-interpret
spine instead of becoming a parallel release matrix:

```text
core_0 -> new_core -> boundary_business_suite
```

Use `empty_business` to prove recursion closure and no IO/TrustBase leakage.
Use focused business/domain/runtime witnesses to prove facade, lowering,
validator, diagnosis, listener, or domain acceptance behavior after the
candidate core can interpret itself.

## Focused Debugging

Use focused witnesses only when changing or debugging their specific surface:

```powershell
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec runtime-evidence-witness -- --json
stack --work-dir .stack-work-codex exec runtime-hot-path-witness -- --json
stack --work-dir .stack-work-codex exec runtime-policy-witness -- --json
stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json
stack --work-dir .stack-work-codex exec registry-codegen-witness -- --json
stack --work-dir .stack-work-codex exec constraint-proof-witness -- --smt=auto
stack --work-dir .stack-work-codex exec fixed-point-smoke -- --summary-json
stack --work-dir .stack-work-codex exec domain-app-report -- --json
```

These commands remain cataloged guardrails. Do not add them back to the default
ordinary gate unless `core-self-interpret` first loses coverage for the relevant
behavior.

## AST Observation

For boot layout and runtime cursor inspection on the self-interpret line:

```powershell
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-summary
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-layout
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-live
```

## Local Rule

Do not run promotion gates from this skill.

```text
self-artifact-witness belongs to core-promotion-gate
check-release.cmd -IncludeSelfArtifact belongs to core-promotion-gate
docs-only changes use git diff --check and targeted text search
```
