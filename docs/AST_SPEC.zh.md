# AST 规范

本文描述当前 production AST 如何表达 framework-core。旧业务 DomainApp 的组件、插件和 effect 示例不再属于本文档。

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
```

## 2. AST 只表达结构

AST 表达 framework core 的能力结构；执行细节留给 bootstrap runtime 和 witness。

AST 中可以出现：

```text
workflow grouping
capability grouping
final atomic facts
control-flow shape
wait gates
hanging hooks
```

AST 中不应该出现：

```text
module scan implementation detail
handler lookup detail
intermediate catalog facts
temporary classification facts
proof construction steps that are not final capabilities
runtime artifact plumbing
```

这些中间事实进入 effect theory closure。

## 3. Leaf Fact 规则

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

不要把这些中间过程写成 AST leaf：

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

## 5. Hanging

Hanging 只表达附加控制结构。

当前 production AST 不依赖复杂 scheduler。`middleware` 可以用于 trace/report 包装；`callback`、`suspense`、`loop` 保留为 DSL 能力，但不要把它们作为 framework core 主验证路径的必要条件。

## 6. 渲染

AST 渲染入口：

```powershell
stack exec ast-tree -- all
```

输出必须只显示 `framework-core` AST。

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
