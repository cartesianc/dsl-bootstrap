---
name: core-promotion-gate
description: "Use in the dsl-bootstrap/newframework repository when validating, publishing, or replacing a promoted framework core: domain framework to core framework promotion, release pre-gate, TrustBase/fixed-point/schema validation, self-artifact-witness planning, artifact gate execution, or deciding whether a candidate core can replace the current core. This skill owns heavy release verification and prevents casual self-artifact-witness runs."
---

# Core Promotion Gate

Use this skill only for promotion or release rounds.

Ordinary architecture iteration belongs to `$framework-self-iteration`.

## Promotion Chain

The candidate core must pass the whole chain:

```text
domain-as-core expression
  -> facade conformance
  -> semantic witness
  -> fixed-point
  -> TrustBase manifest
  -> release pre-gate
  -> self-artifact gate
  -> replacement decision
```

Passing `self-artifact-witness` is required, but not enough by itself.

## Required References

Read these before acting:

- `references/preconditions.md` before running any gate.
- `references/commands.md` when choosing exact commands.
- `references/self-artifact.md` before any `self-artifact-witness` run.

Also inspect repo docs when changing the SOP:

```text
docs/CORE_PROMOTION_SOP.zh.md
docs/SELF_BOOTSTRAP_GATE.md
docs/TRUST_BASE.zh.md
```

## Decision Rule

Do not promote if any item is missing, timed out, failed, or only indirectly proven:

```text
build passed
facade conformance passed
semantic witness passed
fixed-point diffs 0
TrustBase manifest passed
schema catalog passed
domain-side acceptance passed
self-artifact gate passed
git diff contains only intended changes
```

Timed out means inconclusive.

## User Updates

Report status using these exact categories:

```text
not ready for promotion
ready for release pre-gate
ready for self-artifact gate
self-artifact inconclusive
self-artifact passed
promotion blocked
promotion approved
```

Never say a new core is replaceable until the artifact gate has actually passed.
