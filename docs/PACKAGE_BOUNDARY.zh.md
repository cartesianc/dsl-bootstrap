# 包边界

本文档定义项目前台/后台边界。

## 总原则

用户可声明、可配置、可跳转阅读的内容属于前台。

递归、解释、校验、约束抽取、SMT 后端、runtime 调度属于后台。

## 前台入口

业务 workflow 模块导入：

```haskell
import Framework.Workflow
```

暴露 workflow DSL：

```text
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

业务 effect 模块导入：

```haskell
import Framework.Effect
```

暴露 effect DSL：

```text
effect
fact
needs
uses
onFailure
externalMake
externalTake
profile
implement
```

外部 seed / fixture / JSON 入口导入：

```haskell
import Framework.Hylo
```

暴露：

```text
CataModel
HyloModel
AppSeed
WorkflowSeed
EffectTheorySeed
WorkflowLayer
WorkflowCoalgebra
WorkflowCoalgebraM
HangingLayer
HangingCoalgebra
HangingCoalgebraM
anaAppBlueprint
anaEffectTheory
hyloAppWith
hyloAppWithM
hyloAppModel
```

## 后台入口

解释器、检查器、solver 后端和框架内部模块导入：

```haskell
import Framework.Background
```

暴露：

```text
Core.App
Core.App.Boundary
Core.Architecture.Recursion
Core.Effect.Constraint
Core.Effect.Constraint.SMT
Core.Effect.Semantics
Core.Workflow.Eff
Core.Workflow.Semantics
Interpreter.Runtime
Interpreter.Runtime.Contextware
Interpreter.Runtime.Handlers
Interpreter.Runtime.Monad
```

业务模块禁止直接依赖 `Core.*` 或 `Interpreter.*`。

## 前台边界检查

前台 import 边界由 `Core.Boundary.Frontend` 抽成 IR：

```text
FrontendImport
FrontendBoundaryRules
FrontendBoundaryPolicy
FrontendBoundaryError
```

默认检查入口：

```powershell
stack exec frontend-boundary-smoke
```

规则范围：public frontend surface。配置来源由 `FrontendBoundaryRules` / `FrontendBoundaryPolicy` 决定。

自举和 SMT 应优先接纯层：

```text
FrontendBoundaryRules
  -> [FrontendImport]
  -> [FrontendBoundaryError]
```

文件扫描 adapter：

```text
FrontendBoundaryPolicy
  -> extractFrontendImports
  -> checkFrontendImports
```

默认前台禁止直接导入：

```text
Core.*
Interpreter.*
Framework.Background
Blueprint
Effects.EffectTheory
```

默认前台通过 facade 导入：

```text
Framework.Workflow
Framework.Effect
Framework.Hylo
```

## 用户代码

用户前台：

```text
app/CurrentAst.hs
app/CurrentEffects.hs
app/InterpretConfig.hs
src/AST/Facts.hs
src/AST/Names.hs
src/AST/Interceptors.hs
src/Effects/Names.hs
src/Plugins/*.hs
src/Effects/Demo.hs
src/Effects/System.hs
src/Effects/User.hs
src/Effects/Report.hs
src/Effects/Logging.hs
```

职责：领域词汇、workflow 组件、effect claim、profile、入口选择。

`app/InterpretConfig.hs` 保留应用入口到后台解释器的薄别名。recursion model、contextware、algebra 和 runtime wiring 属于 `Interpreter.Runtime`。

## 框架代码

后台模块：

```text
src/Core/Architecture*.hs
src/Core/Workflow/*.hs
src/Core/App.hs
src/Core/App/Ana.hs
src/Core/Effect/*.hs
src/Core/Validation.hs
src/Interpreter/*.hs
src/Interpreter/Runtime/*.hs
src/Interpreter/View/*.hs
```

职责：AST 结构、recursion scheme、AppPlan、constraint IR、effect semantics、runtime algebra、解释流程。

## Core Bootstrap 分层

Core bootstrap boundary IR：

```text
Core.Bootstrap.defaultCoreBoundary
  -> [CoreSlice]
  -> [CoreBoundaryError]
```

Slice：

```text
syntax            AST、hanging、workflow DSL、Framework.Workflow
recursion         cata / gprepro / workflow lowering
hylo              seed、coalgebra、ana/hylo 入口
effect-theory     effect 声明、take/make、profile、handler contract
app-build         AppPlan、AST validation、effect completeness
constraint-ir     ConstraintFact、ConstraintError
proof-boundary    MinimalCoreReport
smt-backend       SMT/proof backend adapter
frontend-facade   Framework.Workflow / Effect / Hylo
frontend-boundary 前台 import 边界 IR
runtime-adapter   RuntimeM、handler dispatch、runtime algebra
```

检查入口：

```powershell
stack exec core-boundary-smoke
```

作用：固定自举依赖的 core map；不移动前台；不改变 runtime。

最小核心验收入口：

```text
Core.App.Boundary.checkMinimalCore
  AppBlueprint
  -> EffectTheory
  -> ProfileName
  -> Either AppError MinimalCoreReport
```

`MinimalCoreReport` 聚合：

```text
AppPlan
ConstraintFact
ConstraintError
MinimalCoreStatus
```

SMT backend 和自举流程输入：`MinimalCoreReport`。
自举规则：使用同一套边界声明 workflow、effect、hylo 输入和 proof 流程；不得新增 core 专用语义。
自举声明范围：`blueprintApp` 和 `blueprintHanging`。`blueprintApp` 覆盖主 workflow；`blueprintHanging` 覆盖 middleware、callback、suspense、loop。

最小 effect handler dispatch：

```text
uses externalMake
  -> profile implement
  -> RuntimeEffectEnvironment
  -> HandlerRegistry
  -> RuntimeHandler
```

`contextware` 负责把 recursion scheme 的 `onProduceEff` 接到 effect boundary。profile 和 handler registry 属于 `RuntimeEffectEnvironment`。

`RuntimeM` 整理运行时环境、状态、错误和 IO 边界：

```text
Reader  RuntimeEnv
State   RuntimeState
Except  RuntimeError
IO      handler execution
Writer  RuntimeState.runtimeTrace
```

`RuntimeState` 保存 active middleware stack。middleware 最小运行时语义：

```text
enter middleware
run body
exit middleware
```

进入和退出写入结构化 middleware event。target body 失败时仍执行 exit，并合并失败分支 event。

未实现：callback / suspense scheduler；component identity 匹配。

业务模块无需直接使用 `RuntimeM`。

SMT v0 入口：

```text
Core.Effect.Constraint.SMT.proveMinimalCore
  MinimalCoreReport
  -> [SmtResult]
```

SMT v0 使用 `ConstraintError` 作为 Haskell evidence。接 SBV/Z3 时替换 `SmtBackend`，保留前台 DSL、AppPlan 和 Constraint IR。

## 生成层

以下模块由 `Setup.hs` 维护，属于注册表出口：

```text
src/Core/Plugins.hs
src/Effects/Theory.hs
```

业务模块通过标记加入注册表：

```haskell
-- plugin: userModule
-- effect: userEffect
```

## Ana / Hylo 边界

Canonical documentation：手写 Haskell AST。

`HyloModel` 用于外部 seed、fixture、重启恢复和边界测试。外部输入通过 unfold algebra / coalgebra 展开成 `AppBlueprint + EffectTheory`，再进入 app build、constraint IR、runtime 或 SMT。

推荐关系：

```text
CataModel
  AppBlueprint + EffectTheory
  -> app / runtime / constraint

HyloModel
  AppSeed + EffectTheorySeed
  -> ana
  -> AppBlueprint + EffectTheory
  -> app / runtime / constraint
```

JSON、RPC、文件或 fixture 作为 unfold algebra seed。

Hanging 输入同样走 hylo：

```text
HangingSeed
  -> HangingCoalgebra / HangingCoalgebraM
  -> HangingLayer
  -> blueprintHanging
```

结果：自举、fixture、边界测试可描述完整 `AppBlueprint`。

名字解析、版本判断或错误处理使用 effectful hylo：

```text
raw seed
  -> WorkflowCoalgebraM / HangingCoalgebraM
  -> AppUnfoldAlgebraM / EffectTheoryUnfoldAlgebraM
  -> AppBlueprint + EffectTheory
  -> AppFoldAlgebraM
```

归属：hylo 入口；不新增解码层前台概念。

展开时的名字解析属于 coalgebra 的实现细节；折叠时的 app build、constraint extraction、runtime 或 SMT 属于 fold algebra 的实现细节。

## 后续物理拆包方向

物理拆包方案：

```text
framework-core
  Core.*
  Interpreter.*
  Framework.*
  Effects.EffectTheory
  Blueprint

domain-app
  AST.Facts
  AST.Names
  AST.Interceptors
  Effects.Names
  Plugins.*
  Effects.User / Effects.Report / ...
  CurrentAst / CurrentEffects / InterpretConfig
```

现阶段保留单 package，控制 Cabal、Setup 和 HLS 成本。
