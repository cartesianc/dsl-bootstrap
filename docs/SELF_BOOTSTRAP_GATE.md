# Self-Bootstrap Gate

This repository treats framework changes as bootstrap changes.

Every new framework version must prove itself before it can replace an older framework version.

## Current Status

The current implementation has reached evidence fixed point:

```text
Stage 0: Bootstrap.* direct framework-core report
Stage 1: Framework.* facade/domain framework-core report
Result: fixed-point-smoke reports diffs: 0
```

Registry/codegen is now expressed as framework semantics:

```text
Framework.RegistryCodegen
RegistryCodegenExpressedFact
RegistryCodegenEvidencePassedFact
domain-app registry-codegen semantic evidence
```

The stronger artifact rebuild loop is still a required next gate:

```text
Stage 0 builds a Stage 1 artifact.
Stage 1 compiles.
Stage 1 validates its own report.
Stage 1 evidence matches the accepted fixed point.
```

## Rule

No framework change is complete until the framework compiles and validates itself.

No old framework replacement is allowed until the artifact rebuild gate passes.

## Required Gate For Every Framework Change

Run these commands before committing framework code:

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
stack exec runtime-diagnosis-witness
stack exec constraint-proof-witness
stack exec registry-codegen-witness
```

Required results:

```text
domain-app-report: status passed
domain-app semantic evidence: failed 0
bootstrap-report: status passed
fixed-point-smoke: diffs 0
runtime-diagnosis-witness: passed
constraint-proof-witness: passed
registry-codegen-witness: passed
```

Run boundary checks:

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
```

Both commands must return no matches.

## Artifact Rebuild Gate

Artifact rebuild becomes mandatory before replacing any old framework source.

The gate is:

```text
1. Stage 0 framework builds a Stage 1 framework artifact.
2. Stage 1 artifact is added as an isolated package or replacement worktree.
3. Stage 1 package compiles with stack build.
4. Stage 1 runs its own domain report.
5. Stage 1 runs its own fixed-point evidence comparison.
6. Stage 1 evidence has no semantic regressions against Stage 0 accepted evidence.
```

The old framework remains a reference and rollback point until all six steps pass.

## Replacement Gate

Replace old framework code only after:

```text
artifact rebuild gate: passed
boundary checks: passed
self-domain report: passed
fixed-point evidence: diffs 0
domain-app frontend entry: passed
git status: clean after commit
```

Replacement commit requirements:

```text
commit 1: introduce or update the new self-validated framework
commit 2: replace the old framework with the validated new framework
```

If artifact rebuild fails, do not replace the old framework.

## Stage Plan

```text
Stage 5: automatic registry/codegen for plugins and effects
Stage 6: artifact rebuild self-hosting
Stage 7: validated replacement of old framework source
```

Stage 5 status:

```text
registry/codegen is declared in framework-core AST/effect semantics
domain-app plugin/effect registries have generated-line semantic evidence
registry-codegen-witness is a host witness for that evidence
```

Each later stage must preserve the required gate above.
