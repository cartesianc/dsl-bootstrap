# 包边界

项目当前拆成两个 Stack/Cabal package：

```text
framework-core
domain-app
```

依赖方向固定为：

```text
domain-app -> framework-core
framework-core -> domain-app  禁止
```

`stack build` 会强制这个方向。`core-boundary-smoke` 会再扫描真实 Haskell import graph，检查 package 方向和 `Core.Bootstrap.defaultCoreBoundary` 是否一致。

## framework-core

路径：

```text
framework-core/
  framework-core.cabal
  src/AST
  src/Core
  src/Effects/EffectTheory.hs
  src/Effects/Names.hs
  src/Framework
  src/Interpreter
```

职责：

```text
workflow AST 基础结构
AppBlueprint 类型
EffectTheory DSL 和 effect semantics
validation
AppPlan build
constraint IR
SMT backend
frontend boundary checker
import graph checker
runtime algebra / RuntimeM / handler dispatch
recursion / hylo facade
```

公开 facade：

```text
Framework.Workflow
Framework.Effect
Framework.Hylo
Framework.Background
```

`Framework.Workflow` 是 framework 级 workflow facade。当前 domain 为了保留具体 `WorkflowFact`、`WorkflowName`、`Interceptor` 的简洁写法，另有 `domain-app/src/Blueprint.hs` 作为业务 facade。

## domain-app

路径：

```text
domain-app/
  domain-app.cabal
  Setup.hs
  app/
  src/Blueprint.hs
  src/Domain/AppBlueprint.hs
  src/Plugins
  src/Effects
```

职责：

```text
当前业务蓝图
workflow plugins
effect units
effect theory registry
runtime smoke
main / smoke executables
```

前台入口：

```text
domain-app/app/Main.hs
domain-app/app/CurrentAst.hs
domain-app/app/CurrentEffects.hs
domain-app/app/InterpretConfig.hs
```

主入口保持：

```haskell
main =
  currentInterpreter currentAst currentEffects
```

## 前台导入规则

业务 workflow 模块导入：

```haskell
import Blueprint
```

业务 effect 模块导入：

```haskell
import Framework.Effect
```

外部 seed / fixture / hylo 入口导入：

```haskell
import Framework.Hylo
```

业务前台禁止直接导入：

```text
Core.*
Interpreter.*
Framework.Background
Effects.EffectTheory
```

`domain-app/app/InterpretConfig.hs` 是应用入口到 runtime 的薄绑定，可以导入 `Interpreter.Runtime`。普通 workflow/effect 声明不走这条路。

## 自动注册

`domain-app/Setup.hs` 维护两个注册表：

```text
domain-app/src/Plugins.hs
domain-app/src/Effects/Theory.hs
```

标记：

```haskell
-- plugin: userModule
-- effect: userEffect
```

构建时生成统一出口。新增业务 plugin 或 effect 后，需要把模块加入 `domain-app/domain-app.cabal` 的 `exposed-modules`。

## 检查入口

Frontend boundary：

```powershell
stack exec frontend-boundary-smoke
```

检查前台 import 是否绕过 facade。

Core/package boundary：

```powershell
stack exec core-boundary-smoke
```

检查内容：

```text
framework-core 不 import domain-app
domain-app 只按声明依赖 framework-core
Core.Bootstrap slice 无重复、无未知依赖、无非法环
真实 import graph 落在 slice 依赖闭包内
minimal core / SMT smoke 仍通过
```

## Core Bootstrap 分层

`Core.Bootstrap.defaultCoreBoundary` 描述自举前的 core map：

```text
syntax
language-spec
recursion
hylo
effect-theory
app-build
constraint-ir
proof-boundary
smt-backend
frontend-facade
frontend-boundary
runtime-adapter
```

手写 slice 图用于表达架构意图。真实 import graph 用于检查代码是否遵守这张图。

## Ana / Hylo 边界

Canonical documentation 仍是手写 Haskell AST：

```text
Domain.AppBlueprint.blueprint
Effects.Theory.effectTheory
```

`Framework.Hylo` 用于外部 seed、fixture、重启恢复和边界测试。外部输入通过 unfold algebra / coalgebra 展开成 `AppBlueprint + EffectTheory`，再进入 app build、constraint IR、runtime 或 SMT。
