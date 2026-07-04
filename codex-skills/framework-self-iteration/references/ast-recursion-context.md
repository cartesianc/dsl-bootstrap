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
  AstRuntimeNodeStatus
  AstRuntimeStatus
  AstRuntimeStatusModel
  AstDiagnosisImpactModel
  astLayoutContext
  astLiveLayoutContext
  layoutAppBlueprint
  layoutAstTree
  astRuntimeCursorFromEvent
  astRuntimeStatusModel
  astLayoutNodeByPath
  astDiagnosisImpactModel
  renderAstRuntimeCursor
  renderAstRuntimeCursorOnLayout
  renderAstRuntimeStatusModel
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
  -> AstRuntimeStatusModel node status overlay
```

Diagnosis impact:

```text
RuntimeFailureDiagnosis
  -> astDiagnosisImpactModel AstLayoutModel
  -> root/suspect/polluted fact overlay nodes
```

Use diagnosis impact when a failed fact, empty handler output, missing handler, missing transform, or send failure must be replayed on top of the AST layout. The overlay is read-only; it gives the renderer coordinates and impact categories without changing runtime semantics.

## Witnesses

Default self-interpret claims:

```text
core-self-interpret-boot-ast-layout-expands
core-self-interpret-live-ast-cursor-projects
core-self-interpret-listener-context-explicit
```

The focused lower-level claims remain:

```text
workflow-recursion-context
session123-ast-layout-optional-projection
framework-core-frontend-core-surface-exposed-modules
```

Run the default proof after changing context/layout/listener:

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
```

For human inspection of the self-interpret line:

```powershell
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-summary
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-layout
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-live
```

Use the focused witnesses only while debugging the underlying layout/listener
surface:

```powershell
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

Use `ast-layout -- live` for a lightweight runtime listener sample.
`ast-layout -- live-core` runs the full framework-core self-domain path and can
be slow; reserve it for explicit core listener investigation.
