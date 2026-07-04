# Core 自举设计

本文描述当前 framework 如何把自身表达为一个 domain，并逐步走向 self-hosting。

## 1. 范围

当前 self-iteration snapshot 保留可自举 core kernel。旧 framework 入口和旧业务 DomainApp 作为历史参照。

当前范围：

```text
new-framework-core
  作为新的 compiler/core
  表达 AST、effect theory、runtime、validation、boundary、proof、rendering、fact closure

domain-app
  作为外部使用者
  内容就是 framework-core 自身
  验证新 core 可以被 domain 使用并通过编译
```

## 2. 生产 Core

production core 由 `new-framework-core` 提供。

核心模块：

```text
Bootstrap.Workflow
Bootstrap.Effect
Bootstrap.Blueprint
Bootstrap.Effects
Bootstrap.CoreSurface
Bootstrap.Runtime
Bootstrap.Report
Domain.Ast
Domain.Effects
Domain.EffectHandlers
Domain.Interpreter
Domain.Registry
```

主入口：

```text
frameworkCoreAst
frameworkCoreEffects
frameworkCoreDomain
runFrameworkCoreDomain
```

生产 registry：

```text
framework-core
```

## 3. 自举流程

AST 主干只描述最终能力：

```text
core surface 形式化
AST 数据结构表达
effect theory DSL 表达
runtime interpreter 表达
buildApp / validation 表达
boundary checks 表达
hylo / rendering / proof surface 表达
runtime fact closure 表达
framework core report 发布
```

目录加载、module catalog、import graph、report assembly 这类中间事实属于 effect theory closure，不污染 AST leaf。

## 4. 原生 Runtime

`Bootstrap.Runtime` 当前负责：

```text
buildNativeApp
native fact rule 提取
native send contract 提取
native constraint 校验
handler coverage 校验
source import graph 提取
core boundary check
frontend boundary check
language/elaboration check
proof evidence 构建
runtime fact closure 执行
```

旧 framework oracle 不参与当前 build/runtime，也不作为中间层。

## 5. 自托管

采用直接 staged model：

```text
Stage 0 当前已编译 framework
  -> 按旧约束构建新的 framework implementation / semantic surface
  -> 产出 Stage 1 framework

Stage 1 framework
  -> 拥有新语义
  -> 重新编译或验证同一份 expression
  -> 产出 self report
```

如果修改 compiler kernel 自身，例如 AST 语义、effect DSL 语法、fact closure 规则：

```text
Stage 0 承载现有语义
Stage 0 只需要按旧约束构建新 kernel artifact
Stage 1 产生后负责解释和验证新语义
```

这里没有 compatibility layer 或 migration layer。

## 6. 业务稳定版打薄

自举机制服务 framework 迭代：

```text
修改 kernel 语义
替换 framework source
验证 Stage 0 / Stage 1 fixed point
生成隔离 artifact
维护 witness 和 gate
```

进入业务稳定版后，默认入口收敛为薄 facade：

```text
Framework.Business
业务 vocabulary
workflow
effect theory
runtime handlers
轻量 diagnosis/report
```

业务稳定版默认隐藏：

```text
Bootstrap.*
SelfArtifact
fixed-point gate
self-artifact-witness
workflow-semantics-witness
kernel replacement flow
```

这些能力保留在 framework devtools 或 bootstrap 包中，由框架作者维护。

在当前 self-iteration 仓库里，这些能力保留在发布快照中；其中 `self-artifact-witness` 按高危/重型 artifact gate 管理，只在大构建和轻量 gates 完成后最多运行一次。

## 7. 当前成功标准

core 成功：

```text
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

self domain app 成功：

```text
core_0 -> new_core -> empty_business closes without IO
core_0/core_1 exchangeability passes in core-self-interpret-report.v1
```

负向标准：

```text
production source 禁止导入 old Framework facade
production output 不包含旧业务污染
domain-app 不拥有 core implementation
new-framework-core 不依赖旧 framework package
```
