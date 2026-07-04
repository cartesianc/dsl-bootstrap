# AST 规范

本文描述当前 production AST 如何表达 framework-core。旧业务 DomainApp 的组件、插件和 effect 示例归档在历史文档中。

## 1. 入口

AST 入口是：

```text
Domain.Ast.frameworkCoreAst
Bootstrap.Blueprint.coreBootstrapBlueprint
```

根 workflow 是：

```text
FrameworkCoreFlow
```

AST 使用本地 DSL：

```text
Bootstrap.Workflow
```

它定义：

```text
AppBlueprint
Workflow
FactExpr
WorkflowFact
WorkflowName
Interceptor
chain
parallel
fact
wait
fallback
race
choice
hanging
middleware
callback
suspense
  loop
  context
```

## 2. AST 只表达结构

AST 表达 framework core 的能力结构；执行细节留给 bootstrap runtime 和 witness。

AST 中可以出现：

```text
workflow 分组
capability 分组
最终原子 facts
control-flow 形态
wait gates
hanging hooks
```

中间过程进入 effect theory closure：

```text
module scan 实现细节
handler lookup 细节
中间 catalog facts
临时 classification facts
proof 构造步骤
runtime artifact plumbing
```

这些中间事实进入 effect theory closure。

## 3. 叶子 Fact 规则

AST leaf fact 应该是最终原子能力。

当前核心 leaf facts：

```text
AstStructureExpressedFact
EffectTheoryDslExpressedFact
RuntimeInterpreterExpressedFact
BuildAppValidationExpressedFact
BoundaryChecksExpressedFact
HyloRenderingProofSurfaceExpressedFact
RuntimeFactClosureExpressedFact
FrameworkCoreNativeValidatedFact
FrameworkCoreExpressedFact
FrameworkCoreReportPublishedFact
```

示例：

```haskell
fact [AstStructureExpressedFact]
```

这些中间过程保持在 handler、runtime 或 policy 层：

```text
PackageModulesDiscoveredFact
FrameworkCoreModulesClassifiedFact
CoreHostModulesClassifiedFact
ImportGraphBuiltFact
ConstraintIRBuiltFact
```

它们可以在 effect theory 中声明为 producers、needs、takes、makes 或 runtime artifacts。

## 4. Workflow 分组

推荐分组：

```text
FrameworkCoreFlow
  CoreSurfaceFormalizationFlow
  ValidateStaticContractsFlow
  BuildProofFlow
  ValidateRuntimeFlow
  PublishFrameworkCoreReportFlow
```

并行检查使用 `parallel`：

```text
core boundary
frontend boundary
language spec
elaboration contract
```

运行时 closure 使用独立 workflow：

```text
ValidateRuntimeFlow
```

## 5. Hanging 控制结构

Hanging 只表达附加控制结构。

当前 production AST 依赖基础 workflow。`middleware` 可以用于 trace/report 包装；`callback`、`suspense`、`loop` 保留为 DSL 能力，framework core 主验证路径继续使用基础 workflow。

`context` 用于把 recursion scheme model 和 algebra effect systems 挂到 hanging tree。它是可选 observer/projection handle，不改变默认 core 的主 workflow。只有调用方显式挂载 context 时，对应 algebra effect systems 才进入 plan validation。

## 6. 渲染

AST 渲染入口：

```powershell
stack exec ast-tree -- all
stack exec ast-tree -- json all
```

文本输出和 `ast-tree.v1` JSON 输出都必须只显示 `framework-core` AST。

`ast-tree.v1` 是现有 AST 语义的只读 projection：

```text
tree            结构化整树，节点带 kind/name/path/metadata/children
executionPaths  扁平路径表，用来索引每个可运行或控制节点
textTree        兼容人工阅读的文本树
```

动态运行位置不写入 AST 本体。监听“当前运行到哪个节点”时，应显式挂 `context`，让 runtime 输出 `RuntimeContextNodeEntered` / `RuntimeContextNodeExited` 事件，并用 path 对齐 `ast-tree.v1` 或 `AstLayoutModel` 节点。

AST layout / live cursor 设计见 [AST layout and recursion context](AST_LAYOUT_CONTEXT.zh.md)。

负向规则：

```text
不得显示旧业务 fact
不得显示旧 generated plugin/effect registry
不得显示 current/demo registry aliases
```

## 7. 与 Effect Theory 的边界

AST 说：

```text
framework core 需要表达哪些最终能力
```

Effect theory 说：

```text
这些能力需要哪些中间事实、artifact、send boundary、transform 和 handler
```

Runtime 说：

```text
这些声明是否闭合，是否可以执行，最终产生哪些 fact 和 artifact
```
