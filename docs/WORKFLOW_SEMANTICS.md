# Workflow Semantics

This document records the runtime contract for the workflow AST.

## Runtime Contract

```text
chain      runs steps in order and stops on the first failure
parallel   starts all branches concurrently from the same input runtime
race       starts all branches concurrently and keeps the first successful branch
fallback   tries branches in order and discards failed branch state
choice     runs only the selected ChoiceKey branch
wait       satisfies the fact expression before running the body
FactAll    satisfies every expression
FactAny    tries expressions in order and keeps the first successful expression
loop       runs until facts/runtime values reach a fixed point, capped at 16 iterations
callback   runs on target component entry; failure is recorded, not propagated
middleware records entered/exited events around the body, including failure paths
suspense   records target status and a lightweight RuntimeSnapshot
```

`parallel` and `race` use real runtime branches. Each branch starts with the
same input runtime state. Parallel branch results are merged in blueprint order.
If two successful branches produce different values for the same `TypeName`, the
parallel node fails with a merge conflict.

`suspense` is not durable persistence. It captures a renderable runtime snapshot
that can be inspected or stored by a future host, but this framework does not
define a database schema or resume queue.

## Witness

Run:

```powershell
stack exec workflow-semantics-witness
```

The witness covers concurrent parallel execution, race cancellation, failed
branch isolation, exact choice selection, `FactAny`, loop fixed points,
middleware exit events, suspense snapshots, callback failure recording, and
native/framework runtime fact alignment.
