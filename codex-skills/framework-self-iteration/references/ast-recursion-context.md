# AST Recursion Context

Use this reference for AST rendering, runtime listener, and recursion scheme context work.

## Invariants

```text
layout is a read-only projection
listener writes runtime events, not AST mutations
context is explicit in hanging tree
context algebra effects enter build validation
default framework-core app does not auto-install layout context
runtime cursor path matches AstLayoutModel node path
```

## Public Surface

```text
Framework.Ast
  context
  withRecursionContext
  RecursionContextName
  recursionContext
  recursionContextAlgebra
  recursionModel
  cata/para/histo/ana/apo/futu/hylo/chrono/prepro/zygo/generalized modes
  renderBeforeRunMode
  listenDuringRunMode

Framework.Ast.Layout
  AstLayoutModel
  AstLayoutNode
  AstRuntimeCursor
  astLayoutContext
  astLiveLayoutContext
  layoutAppBlueprint
  layoutAstTree
  astRuntimeCursorFromEvent
  astLayoutNodeByPath
```

## Two Models

Pre-run rendering:

```text
AppBlueprint -> astTreeStructure -> AstLayoutModel
```

Live listening:

```text
hanging context
  -> RecursionContextModel with listen-during-run
  -> RuntimeContextEvent
  -> AstRuntimeCursor
  -> AstLayoutModel node lookup by path
```

## Witnesses

Required claims:

```text
workflow-recursion-context
session123-ast-layout-optional-projection
framework-core-frontend-core-surface-exposed-modules
```

Run after changing context/layout/listener:

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

Also inspect:

```powershell
stack --work-dir .stack-work-codex exec ast-tree -- json all
```
