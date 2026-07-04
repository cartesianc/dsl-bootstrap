# Preconditions

Before promotion, verify the change is meant to publish or replace core.

## Candidate Identity

Record:

```text
target commit or worktree state
semantic-risk scope
changed facade/CoreSurface modules
changed AST/effect/fact handles
changed witness/report/schema files
changed artifact source or command lists
```

## Required State

Promotion cannot start unless:

```text
current worktree diff is understood
no unrelated user changes will be reverted
ordinary semantic witnesses for touched areas have already passed
docs-only changes are not being escalated to artifact gate
the user explicitly accepts this as a promotion/release round
```

## Inconclusive States

Treat these as not ready:

```text
tool timeout
Stack build lock
leftover stack/ghc process
schema-catalog witness still running after timeout
unknown git diff
missing witness coverage
failed or skipped TrustBase manifest evidence
```

If a command times out, inspect residual processes before rerunning. A release pre-gate timeout under 20 minutes is usually too short to prove failure.
