# Commands

Use `.stack-work-codex` for current-worktree validation.

## Release Pre-gate

Preferred:

```powershell
.\scripts\check-release.cmd
```

Give the tool 20-30 minutes. The release pre-gate re-runs many JSON witnesses; `schema-catalog-witness -- --json` alone can take several minutes because it executes every schema catalog command.

Equivalent expanded command set:

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec mytest
stack --work-dir .stack-work-codex exec domain-app-report -- --json
stack --work-dir .stack-work-codex exec domain-app-self-smoke
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec framework-core-mytest
stack --work-dir .stack-work-codex exec bootstrap-smoke
stack --work-dir .stack-work-codex exec bootstrap-runtime-smoke
stack --work-dir .stack-work-codex exec bootstrap-report -- --json
stack --work-dir .stack-work-codex exec fixed-point-smoke -- --summary-json
stack --work-dir .stack-work-codex exec runtime-evidence-witness -- --json
stack --work-dir .stack-work-codex exec runtime-hot-path-witness -- --json
stack --work-dir .stack-work-codex exec runtime-policy-witness -- --json
stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --runtime-concurrency-json
stack --work-dir .stack-work-codex exec constraint-proof-witness -- --smt=auto
stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec schema-catalog-witness -- --json
stack --work-dir .stack-work-codex exec registry-codegen-witness -- --json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

If `check-release.cmd` times out, do not assume the last visible command failed. A 10 minute tool timeout can expire while `schema-catalog-witness` is still legitimately running. Inspect and stop residual Stack processes if needed, then rerun only after deciding it is safe.

To distinguish slow schema catalog from a release-wide failure:

```powershell
Measure-Command { stack --work-dir .stack-work-codex exec schema-catalog-witness -- --json | Out-Null }
```

## Boundary Searches

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
rg -n "self-artifact-witness|IncludeSelfArtifact|check-release" README.md docs scripts new-framework-core/src
```

The first two searches should have no output.
