# AST Layout 与 Recursion Context

本文记录 AST 渲染和运行监听的当前设计。

能力范围：

```text
运行前可以生成整棵 AST 的 layout model
运行时可以监听当前进入/退出的 AST 节点
recursion scheme 模式保持可选
context 挂载进入 hanging tree
algebra 通过 effect system 进入验证
默认 core 保持无 layout/listener 自动挂载
```

## 1. 语义位置

AST layout 是当前 AST 的只读 projection。

runtime listener 也不改写 AST 本体。它通过挂在 hanging tree 上的 `context` 节点声明一个 recursion context，runtime 只捕捉这个 context handle 下的节点事件。

```text
AppBlueprint
  app workflow
  hanging
    context RecursionContext
      workflow body
```

`context` 节点携带：

```text
RecursionContextName
RecursionSchemeModel
RecursionContextAlgebra
```

`RecursionContextAlgebra` 持有一组 `EffectSystem WorkflowFact`。这些 effect systems 会进入 build validation，context algebra 属于可验证声明。

## 2. Recursion Scheme 模式

当前 facade 暴露的是开放模式标签，不把解释器锁死成两种模式：

```text
cata
para
histo
ana
apo
futu
hylo
chrono
prepro
zygo
generalized
```

这些模式目前是 context model 的语义标签。具体 algebra 如何解释由挂载方和后续 renderer/listener 决定。

当前内置 helper 使用：

```text
astLayoutContext
  modes: zygo + render-before-run

astLiveLayoutContext
  modes: zygo + render-before-run + listen-during-run
```

选择 `zygo` 的原因是 AST layout 需要同时保留节点身份并计算坐标辅助结果。后续如果需要 subtree 原貌、历史 cache 或 unfold 方向，可以继续挂 `para`、`histo`、`hylo`、`chrono` 等模式；默认 core 保持现状。

## 3. 运行前 Layout

运行前渲染入口：

```haskell
layoutAppBlueprint :: AppBlueprint -> AstLayoutModel
layoutAstTree :: AstTreeNode -> AstLayoutModel
renderAstLayoutModel :: AstLayoutModel -> [String]
layoutAppBlueprintWithDag :: AppBlueprint -> (AstLayoutModel, AstDagModel)
layoutAstTreeWithDag :: AstTreeNode -> (AstLayoutModel, AstDagModel)
astDagAppBlueprintProjection :: AppBlueprint -> (AstDagModel, AstDagEquivalenceProof)
astDagDomainAppBlueprintProjection :: EffectTheory -> AppBlueprint -> (AstDagModel, AstDagEquivalenceProof)
astTreeDagProjection :: AstTreeNode -> (AstDagModel, AstDagEquivalenceProof)
astDagEquivalenceProof :: AstLayoutModel -> AstDagModel -> AstDagEquivalenceProof
renderAstDagModel :: AstDagModel -> [String]
renderAstDagEquivalenceProof :: AstDagEquivalenceProof -> [String]
```

数据模型：

```text
AstLayoutModel
  rootPath
  nodes
  edges

AstLayoutNode
  path
  kind
  name
  x / y
  axis
  imposed
  metadata

AstDagModel
  rootPath
  rootNodeId
  unique content-addressed nodes
  occurrence path -> node id index
  context path -> node id multiplicity index
```

布局规则：

```text
入口 root 从 (0, 0) 开始
每展开一层切换 X/Y 轴
同层 children 以 parent 为中心平衡展开
callback / context / middleware / suspense 标记为 imposed
imposed 节点放在 parent 上方
坐标冲突时沿当前展开轴继续延展
```

这一步只产出 layout model。SVG、Canvas、TUI、Graphviz 或自定义 renderer 都可以消费同一个 model 来完成具体画法。

## 4. 运行时 Listener

运行时监听通过 context mode 开启：

```text
listen-during-run
```

runtime 事件：

```text
RuntimeContextStarted
RuntimeContextCompleted
RuntimeContextNodeEntered
RuntimeContextNodeExited
```

cursor projection：

```haskell
astRuntimeCursorFromEvent :: RuntimeContextEvent -> Maybe AstRuntimeCursor
renderAstRuntimeCursor :: AstRuntimeCursor -> String
renderAstRuntimeCursorOnLayout :: AstLayoutModel -> AstRuntimeCursor -> String
```

`AstRuntimeCursor` 保存：

```text
context
path
kind
name
entering
```

renderer 可以用 `path` 在 `AstLayoutModel` 里找到节点坐标，再把当前运行位置高亮出来。

## 5. Facade 切换点

业务或自举代码从 facade 切 context：

```haskell
withRecursionContext contextDefinition appBlueprint
```

或直接在 hanging tree 中写：

```haskell
hanging
  [ context contextDefinition workflowBody
  ]
```

`Framework.Ast.Layout` 提供两个现成 context builder：

```haskell
astLayoutContext
astLiveLayoutContext
```

它们都要求调用方传入 algebra effect systems。默认 framework-core AST 不自动挂 layout context。

## 6. Diagnosis Impact Overlay

diagnosis 是 runtime listener 之后的复盘层。fact 失败、handler 返回空值、缺少 transform 或 send 失败时，runtime 先记录 `RuntimeFailureDiagnosis`，layout 层再把它投影成可渲染的影响范围。

```text
RuntimeFailureDiagnosis
  -> astDiagnosisImpactModel AstLayoutModel
  -> AstDiagnosisImpactModel
```

`AstDiagnosisImpactModel` 不修改 AST，也不修改 runtime 语义。它只把 diagnosis 里的事实映射到已有 layout 节点：

```text
rootFact
suspectFacts
pollutedFacts
```

renderer 可以把 `AstDiagnosisRootFact`、`AstDiagnosisSuspectFact`、`AstDiagnosisPollutedFact` 画成不同图层。后台监听系统拿到 fact 错误后，可以沿着 AST layout 展示影响范围。

## 7. Witness

当前 witness 覆盖：

```text
workflow-recursion-context
  context 可挂载
  listen mode 会记录节点进入/退出事件
  context algebra effect systems 进入 plan validation
  缺少 import 的 context algebra 会让 plan validation 失败

session123-ast-layout-optional-projection
  Framework.Ast.Layout 进入 CoreSurface
  layout 是默认 AST 的只读 projection
  默认 framework-core AST 不含 context node
  layout node count 与 AST tree node count 对齐
  diagnosis impact overlay 可以把 root fact 映射到 layout 节点
```

推荐轻量验证：

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec ast-layout
stack --work-dir .stack-work-codex exec ast-layout -- layout
stack --work-dir .stack-work-codex exec ast-layout -- cursor
stack --work-dir .stack-work-codex exec ast-layout -- diagnosis
stack --work-dir .stack-work-codex exec ast-layout -- live
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-dag
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

`ast-layout -- live` 是轻量 runtime listener 样板。`ast-layout -- live-core` 会运行完整 framework-core self-domain 路径，可能触发较重 handler，不作为默认查看命令。

`self-artifact-witness` 只在 core promotion gate 中运行。
