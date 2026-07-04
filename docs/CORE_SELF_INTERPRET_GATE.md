# Core Self-Interpret Gate

The framework release line is:

```text
core_0 -> core_1 -> empty_business
```

```text
core_0
  Previous compiled core. It provides the TrustBase for this round.

core_1
  Candidate core expressed through the current EDSL foreground.

empty_business
  NoInput / Unit terminal app that closes the candidate core's business
  parameter.
```

## Release Invariant

Promotion requires normalized exchangeability:

```text
core_0 ~= core_1
```

After promotion, the next round uses:

```text
core_1 -> core_2 -> empty_business
```

TrustBase is the generation boundary carried by the previous compiled core.

## Command

```powershell
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
```

Output schema:

```text
core-self-interpret-report.v1
```

Required stages:

```text
core_0-runs-new_core
new_core-runs-as-domain
new_core-runs-empty_business
self-interpret-ast-projection
self-interpret-gate-consolidation
self-interpret-fixed-point
```

Required claims:

```text
previous compiled core interprets candidate core foreground
candidate core runs as a framework-shaped domain
empty_business closes recursion
empty_business has no IO surface
TrustBase is non-recursive at terminal business
candidate foreground expands into boot-time AST layout
explicit hanging context emits runtime cursors
runtime cursors project onto layout nodes
runtime cursors fold into AST node status overlay
listener context is explicit evidence foreground
default gates are consolidated
artifact gate commands are consolidated
core_0/core_1 exchangeability passes
fixed-point evidence is synced
claim manifest is synced
```

## AST Inspection

```powershell
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-summary
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-layout
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-live
```

```text
self-interpret-summary
  Generation line, boot node count, live context, recursion modes.

self-interpret-layout
  Bounded boot-layout sample for the candidate core foreground.

self-interpret-live
  Runtime cursor projection and AST node status overlay.
```

The live evidence foreground uses:

```text
context: CoreSelfInterpretLiveContext
model: core-self-interpret-live-para-histo
modes: para, histo, render-before-run, listen-during-run
```

## Default Gates

```text
check-fast
  stack build
  core-self-interpret -- --json

check-semantic
  stack build
  core-self-interpret -- --json
  trust-base-manifest-witness -- --evidence-json
  architecture-concern-witness -- --json

check-release
  stack build
  core-self-interpret -- --json
  trust-base-manifest-witness -- --evidence-json
  architecture-concern-witness -- --json
```

## Artifact Gate

Promotion artifact gate:

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

Stage1 artifact commands:

```text
stack build
core-self-interpret -- --json
trust-base-manifest-witness -- --evidence-json
architecture-concern-witness -- --json
```
