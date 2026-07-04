---
name: framework-self-iteration
description: "Use when making ordinary architecture-internal iterations in the dsl-bootstrap/newframework repository: locating a feature, mapping it through Framework.* facade, CoreSurface, AST/effect handles, runtime listener paths, and witness claims, then choosing the smallest local validation gate. Use for AST layout/listener, recursion context, facade boundary, capability/effect/runtime semantics, and evidence work. Do not use for publishing or replacing a new core; use core-promotion-gate for that."
---

# Framework Self Iteration

Use this skill to make ordinary framework iterations with the lowest possible mental load.

## Three-step Loop

1. Locate one anchor.
2. Change the smallest semantic surface.
3. Run the smallest witness that proves it.

Do not start from the whole repository. Start from one of:

```text
Framework.* facade symbol
CoreSurface module/capability
AST fact or workflow node
EffectSystem / capability lowering rule
runtime event / handler / transform
witness claim name
```

## Load References

Read only the reference needed for the current task:

- `references/semantic-risk.md`: before changing AST constructors, capability lowering, effect/fact semantics, runtime interpreter behavior, TrustBase, artifact sources, or witness schemas.
- `references/ast-recursion-context.md`: when using AST layout, runtime listener, recursion scheme modes, `context`, or `Framework.Ast.Layout`.
- `references/gates.md`: before choosing local build, smoke, or semantic witness commands.

## Location Workflow

Start from the narrowest public surface:

```text
Framework.* facade
  -> Bootstrap.CoreSurface
  -> Domain self-expression / framework-core AST
  -> EffectTheory / capability lowering
  -> runtime implementation or handler implementation
  -> witness claim / report payload
```

Useful search anchors:

```powershell
rg -n "ModuleOrCapabilityName" new-framework-core/src domain-app/src new-framework-core/app
rg -n "claim-name|FactName|EffectName" new-framework-core/src new-framework-core/app domain-app
rg -n "Framework.Ast.Layout|RecursionContext|RuntimeContextEvent" new-framework-core/src new-framework-core/app docs
```

Prefer these entry points:

```text
Framework.Business  capability authoring surface
Framework.Ast       workflow / AppBlueprint / recursion context facade
Framework.Ast.Layout optional AST layout and runtime cursor projection
Framework.Handler   handler / transform implementation API
Framework.TrustBase self-iteration, reports, manifests, gates
```

Avoid treating `Framework.Runtime` or `Bootstrap.Runtime` as business frontend.

## Recursion Context Model

Use the two-model split:

```text
Pre-run model:
  layoutAppBlueprint / layoutAstTree -> AstLayoutModel

Live model:
  hanging context + listen-during-run -> RuntimeContextEvent -> AstRuntimeCursor
```

Keep the context optional. Do not hardcode layout/listener context into the default core app.

The runtime cursor path must match an `AstLayoutModel` node path. If path behavior changes, strengthen `workflow-recursion-context` or `session123-ast-layout-optional-projection` before trusting the feature.

## Architecture Pressure

When this skill feels hard to use, improve the architecture rather than adding more instructions:

```text
add a facade symbol
add a CoreSurface capability
add an AST/effect/fact handle
add a runtime event or layout cursor
add a witness claim
add a schema-cataloged JSON payload
```

The goal is to make future location and validation cheaper.

## Response Discipline

When reporting status, separate:

```text
implemented
validated by lightweight gates
needs promotion gate
```

Publishing or replacing a new core belongs to `$core-promotion-gate`.
