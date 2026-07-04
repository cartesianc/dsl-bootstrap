# Core Self-Interpret Gate

This repository treats the framework as an EDSL-hosted self-iteration system.
The release target is not a second core inside the domain app. The release
target is exchangeability:

```text
core_0 -> core_1 -> empty_business
```

For a release candidate, `core_0` is the compiled previous core and `core_1`
is the candidate core expressed through the current EDSL foreground. The
terminal `empty_business` is a `NoInput` / `Unit` acceptance object that closes
the domain parameter without adding host IO, handlers, artifacts, or another
TrustBase layer.

## Release Invariant

The candidate is releasable only when the normalized evidence says:

```text
core_0 ~= core_1
```

That means `core_1`, after being interpreted by `core_0`, can become the next
round's `core_0` without an adapter. The next iteration then uses the same
shape:

```text
core_1 -> core_2 -> empty_business
```

TrustBase belongs to the edge between generations. It is not a business
argument and must not be passed into the terminal business app.

## Current Gate

The current focused gate is:

```powershell
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
```

It emits `core-self-interpret-report.v1` and checks:

```text
previous compiled core interprets the new core foreground
new core runs as a framework-shaped domain
empty business closes the domain parameter
empty business has no IO surface
TrustBase is non-recursive at the terminal business
candidate core foreground expands into a boot-time AST layout
explicit hanging context emits runtime cursors that project back onto layout nodes
runtime cursors fold into a renderable AST node status overlay
listener context is evidence-only and absent from the default empty business hot path
core_0 and core_1 are exchangeable under normalized fixed-point evidence
```

The AST projection claims are deliberately explicit. The normal empty business
has no listener context; the report constructs a separate evidence foreground
with a `core-self-interpret-live-para-histo` recursion model carrying
`para`, `histo`, `render-before-run`, and `listen-during-run`.
Those cursors are folded into an `AstRuntimeStatusModel`, so the live projection
can render node status such as `running`, `completed`, or `unresolved` against
layout coordinates without mutating the AST.

For human inspection, the same projection is available through `ast-layout`:

```powershell
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-summary
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-layout
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-live
```

`self-interpret-layout` prints a bounded boot-layout sample instead of dumping
the full candidate core layout. The full node/edge counts remain part of the
`core-self-interpret` evidence payload.

## Gate Consolidation

Ordinary architecture iteration should move duplicate checks behind this report
instead of adding parallel release criteria. Focused witnesses still exist, but
their role is to guard implementation surfaces while a claim is being added or
debugged. Once a behavior is covered by `core-self-interpret-report.v1`, the
release story should point at the self-interpret claim first.

The default gate shape is now intentionally small:

```text
check-fast:
  stack build
  core-self-interpret -- --json

check-semantic / check-release:
  stack build
  core-self-interpret -- --json
  trust-base-manifest-witness -- --evidence-json
  architecture-concern-witness -- --json
```

The older focused commands, such as `bootstrap-report`, `fixed-point-smoke`,
`domain-app-report`, workflow/runtime/business witnesses, and schema catalog
checks, remain cataloged and available for focused work. They are not default
release criteria once their behavior is covered by self-interpret claims.

The `self-artifact-witness` remains outside this ordinary line and appears only
behind the explicit high-risk `check-release -IncludeSelfArtifact` policy. When
that artifact gate runs, its internal command list mirrors the same release
proof inside `.generated/stage1-framework`:

```text
stack build
core-self-interpret -- --json
trust-base-manifest-witness -- --evidence-json
architecture-concern-witness -- --json
```

It does not re-add the older focused witnesses as parallel artifact release
criteria.
