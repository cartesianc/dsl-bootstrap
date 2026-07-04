# Semantic Risk

Classify risk before editing.

## High Risk

Pause for explicit architecture review before changing:

```text
AST constructor / hanging branch / recursion context semantics
capability lowering semantics
effect/fact visibility, imports, private facts, exports
runtime interpreter behavior
retry / idempotency / error dispatch / concurrency policy algebra
fixed-point diff keys
TrustBase manifest semantics
self-artifact manifest source list or artifact commands
machine-readable schema meaning
```

Required evidence:

```text
new or updated semantic handle
new or updated witness claim
claim manifest sync
CoreSurface/cabal sync if public
relevant JSON evidence when schema/report changes
```

## Medium Risk

Review locally and add focused evidence:

```text
new facade value or type
new report field with compatible schema
module boundary movement
runtime event payload extension
layout projection behavior
diagnosis attribution path
handler/transform boundary metadata
```

## Low Risk

Usually needs only diff/doc checks:

```text
README or docs wording
navigation links
comment-only changes
command index updates
non-semantic typo fixes
```

Docs-only changes do not trigger `self-artifact-witness`.

## Start Checklist

Before editing, write down:

```text
touched semantic boundary
expected invariant
facade location
AST/effect/fact handle
witness/report that will prove it
gate tier
```
