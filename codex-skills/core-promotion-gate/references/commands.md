# Commands

Use `.stack-work-codex` for current-worktree validation.

## Release Pre-gate

Preferred:

```powershell
.\scripts\check-release.cmd
```

Give the tool several minutes. The default release pre-gate is now deliberately
small and delegates ordinary semantic proof to `core-self-interpret-report.v1`.

Equivalent expanded command set:

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

Focused witnesses such as `fixed-point-smoke`, `domain-app-report`,
`workflow-semantics-witness`, and `schema-catalog-witness` remain available for
debugging their surfaces. Do not treat them as parallel release criteria when
`core-self-interpret` already covers the behavior.

If `check-release.cmd` times out, do not assume the last visible command failed.
Inspect residual Stack processes if needed, then rerun only after deciding it is
safe.

When debugging schema catalog coverage directly, remember that it executes
every schema catalog command:

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
