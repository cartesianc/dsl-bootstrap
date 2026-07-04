# Self Artifact Gate

`self-artifact-witness` is the high-risk promotion gate.

## Rules

```text
run only after release pre-gate passes
same HEAD at most once unless marker reset is intentional
expected runtime at least 10 minutes
tool timeout should be 15-20 minutes
timeout is inconclusive
do not run for README/docs-only changes
do not rerun casually after timeout
```

## Preferred Command

Run only after the default release pre-gate has passed:

```text
build + core-self-interpret + TrustBase manifest + architecture guardrail
```

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

Direct execution is allowed only when the SOP or user explicitly asks:

```powershell
stack --work-dir .stack-work-codex exec self-artifact-witness
```

## Evidence Required

The gate must prove:

```text
.generated/stage1-framework created
artifact build passed
artifact core-self-interpret passed
artifact TrustBase manifest evidence passed
artifact architecture guardrail passed
artifact commands remain collapsed onto the self-interpret release proof
```

Focused witnesses such as `fixed-point-smoke`, `domain-app-report`, workflow,
runtime, registry, business, and schema checks stay available for debugging
their surfaces. They are not reintroduced as parallel artifact release criteria
once the behavior is covered by `core-self-interpret-report.v1`.

## Failure Handling

```text
failed: do not replace core
timeout: inconclusive; inspect processes and logs
build lock: stop or wait for the other Stack process, then rerun only if the round still permits it
marker exists: start a new round or reset only with explicit intent
```

Do not call the candidate promoted until this gate passes.
