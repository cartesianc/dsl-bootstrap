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

Artifact materialization is now an implemented witness:

```text
Framework.SelfArtifact
SelfArtifactManifestExpressedFact
SelfArtifactManifestEvidencePassedFact
self-artifact-witness
.generated/stage1-framework
```

The checked-in framework source is the core source. The artifact tree is the isolated replacement candidate built from that source.

## Rule

No framework change is complete until the framework compiles and validates itself.

No old framework replacement is allowed until `self-artifact-witness` passes for the target commit.

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
stack exec self-artifact-witness
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
self-artifact-witness: passed
```

Run boundary checks:

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
```

Both commands must return no matches.

## Artifact Materialization Gate

Artifact materialization is mandatory before replacing any old framework source.

The gate is:

```text
1. Run stack exec self-artifact-witness from the target commit.
2. The witness creates .generated/stage1-framework.
3. The Stage 1 artifact runs stack build.
4. The Stage 1 artifact runs bootstrap-report.
5. The Stage 1 artifact runs fixed-point-smoke.
6. The Stage 1 artifact runs domain-app-report.
7. The Stage 1 artifact runs registry-codegen-witness.
```

The old framework remains a reference and rollback point until all seven steps pass.

## Replacement Gate

Replace old framework code only after:

```text
artifact materialization gate: passed
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

If artifact materialization fails, keep the old framework unchanged.

## Stage Plan

```text
Stage 5: automatic registry/codegen for plugins and effects
Stage 6: artifact materialization self-hosting
Stage 7: validated replacement of old framework source
```

Stage 5 status:

```text
registry/codegen is declared in framework-core AST/effect semantics
domain-app plugin/effect registries have generated-line semantic evidence
registry-codegen-witness is a host witness for that evidence
```

Stage 6 status:

```text
self-artifact manifest is declared in framework-core AST/effect semantics
self-artifact-witness materializes .generated/stage1-framework
stage1 framework artifact compiles and validates its own reports
```

Each later stage must preserve the required gate above.
