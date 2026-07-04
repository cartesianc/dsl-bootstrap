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
artifact bootstrap-report passed
artifact fixed-point-smoke diffs 0
artifact runtime evidence passed
artifact workflow semantics passed
artifact domain-app-report passed
artifact registry-codegen witness passed
artifact business-syntax witness passed
```

## Failure Handling

```text
failed: do not replace core
timeout: inconclusive; inspect processes and logs
build lock: stop or wait for the other Stack process, then rerun only if the round still permits it
marker exists: start a new round or reset only with explicit intent
```

Do not call the candidate promoted until this gate passes.
