# new-framework-core

这个仓库现在拆成两个当前参与构建的包：

```text
new-framework-core
  新的 framework core/compiler 包。

domain-app
  一个最小 domain app。它依赖 new-framework-core，内容就是 framework-core 自身，用来验证“新 core 作为 compiler，同时作为 domain 被表达”可以通过编译和 runtime closure。
```

旧的业务 DomainApp、generated plugin registry、generated effect registry、`current` / `demo` registry alias 都不再是 production surface。

## Core 表达内容

`new-framework-core` 表达的是 framework core 自身：

```text
AST 数据结构
effect theory DSL
runtime interpreter
buildApp / validation
boundary checks
hylo / rendering / proof surface
runtime fact closure
```

主结构保持为：

```text
new-framework-core/src/Bootstrap/*
new-framework-core/src/Bootstrap/Effects/<Group>/Registration
new-framework-core/src/Bootstrap/Effects/<Group>/Facts
new-framework-core/src/Domain/*
```

公共入口：

```text
frameworkCoreAst
frameworkCoreEffects
frameworkCoreDomain
runFrameworkCoreDomain
```

## Self Domain App

`domain-app` 不再承载 core 实现。它只做第一层使用者：

```text
domain-app/src/SelfDomainApp.hs
domain-app/app/Main.hs
```

它把 `frameworkCoreDomain` 作为自己的内容，并通过 `Bootstrap.Report.buildFrameworkCoreReport` 验证：

```text
domain-app:self-framework-core
  content: framework-core
```

这一步的意义是确认新 core 已经可以被一个外部 domain app 使用，而不是继续把 domain app 和 core 混成同一个包。

## Self-Hosting 模型

不引入 compatibility layer 或 migration layer：

```text
Stage 0 当前已编译 framework
  -> 按旧约束构建新的 framework implementation / semantic surface
  -> 产出 Stage 1 framework

Stage 1 framework
  -> 拥有新语义
  -> 重新解释并验证同一份 framework expression
```

即使修改 AST 语义、effect DSL 语法、fact closure 规则，Stage 0 也只是构建新的 kernel artifact；新语义由 Stage 1 产生后承担。

## 构建

使用 watcher：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-watch.ps1 -CommandLine "stack build --no-terminal"
```

## Smoke

core 自检：

```powershell
stack exec domain-registry
stack exec ast-tree -- all
stack exec domain-map -- json all
stack exec bootstrap-smoke
stack exec bootstrap-runtime-smoke
stack exec bootstrap-report
stack exec mytest
```

self domain app 自检：

```powershell
stack exec domain-app-self-smoke
```

## 负向边界

Production source 和输出不得重新暴露：

```text
Foo
Greeting
UserNameAsked
ReportGenerated
Plugins.
Effects.User
Effects.Report
Effects.Demo
Framework.* production import
```

`Bootstrap.CoreSurface` 中出现的历史 `Framework.*` 名字只是被表达对象的 catalog data，不是 production import。
