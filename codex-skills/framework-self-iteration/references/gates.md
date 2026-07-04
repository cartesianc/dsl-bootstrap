# Local Gates

Use the smallest gate that proves the touched semantics.

## Fast

For local compile and domain smoke:

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec mytest
stack --work-dir .stack-work-codex exec domain-app-report -- --json
```

## Semantic

For framework semantics:

```powershell
stack --work-dir .stack-work-codex exec bootstrap-report -- --json
stack --work-dir .stack-work-codex exec fixed-point-smoke -- --summary-json
stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

Add focused witnesses as needed:

```powershell
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec runtime-evidence-witness -- --json
stack --work-dir .stack-work-codex exec runtime-hot-path-witness -- --json
stack --work-dir .stack-work-codex exec runtime-policy-witness -- --json
stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json
stack --work-dir .stack-work-codex exec registry-codegen-witness -- --json
stack --work-dir .stack-work-codex exec constraint-proof-witness -- --smt=auto
```

## Local Rule

Do not run promotion gates from this skill.

```text
self-artifact-witness belongs to core-promotion-gate
check-release.cmd belongs to core-promotion-gate unless the user asks for a release pre-gate
docs-only changes use git diff --check and targeted text search
```
