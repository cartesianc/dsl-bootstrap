# Project Layout

当前项目按“内核、facade、自表达 domain、外部 domain”分层。

## 1. 顶层包

```text
new-framework-core
  framework/compiler core。拥有 bootstrap backend、public facade、self-domain expression、reports、proof、artifact gate。

domain-app
  外部使用者示例。只通过 Framework.* facade 写业务声明、effect theory、runtime handlers 和 semantic evidence。
```

## 2. new-framework-core

```text
new-framework-core/src/Bootstrap
  自举 kernel。禁止 import Framework.*。

new-framework-core/src/Bootstrap/Runtime
  Bootstrap runtime 的子职责模块。
  Types       公共 runtime/plan/handler/constraint 类型。
  SourceGraph 源码 import graph 读取。
  Boundary    core/frontend boundary policy 和语言契约检查。

new-framework-core/src/Framework
  public facade。外部 domain 默认只接触这里。Framework.Business 是 effect 前台语法入口。

new-framework-core/src/Domain
  framework-core 自己的 self-domain expression。它通过 facade style 表达 framework-core。

new-framework-core/src/Bootstrap/Effects
  framework-core 的 effect registration 和 fact declaration。

new-framework-core/app
  witness、report、smoke executable。
```

规范：

```text
Bootstrap.* 不 import Framework.*。
Framework.* 可以包装/暴露 Bootstrap.* 能力。
Domain.* 表达 framework-core 本身，不承载外部业务。
app/* 只放 executable glue 和 witness。
```

## 3. domain-app

```text
domain-app/src/Domain/AppBlueprint.hs
  前台配置入口。只组合 app flow 和 hanging hooks。

domain-app/src/Plugins
  前台 workflow fragments。只描述业务模块，不写算法。

domain-app/src/Effects
  effect theory lowering facade。只把 Domain.Business 的 capability group lower 成底层 EffectUnit。

domain-app/src/Domain/Business.hs
  effect 前台业务能力声明。只写 capability、pipeline、policy、handler binding、transform binding。

domain-app/src/Domain/Vocabulary.hs
domain-app/src/Domain/EffectVocabulary.hs
  稳定命名层。只放 facts、workflow names、send names、type names、handler names。

domain-app/src/Domain/Runtime.hs
  handler/transform 实现。算法、IO、typed value conversion 都放这里。

domain-app/src/Domain/SemanticEvidence.hs
  semantic evidence 和 generated-source checks。

domain-app/src/Domain/RegistryCodegenSpec.hs
  registry codegen 期望输出。

domain-app/src/SelfDomainApp.hs
  domain registration。
```

前台原则：

```text
AppBlueprint 和 Plugins.* 应该像配置文件。
Domain.Business 和 Effects.* 也应该像配置文件。
不要在前台写算法、搜索、格式化、计算、IO。
算法进入 Domain.Runtime handler/transform。
业务能力进入 Domain.Business，底层 effect IR 由 Framework.Business 自动生成。
可验证结论进入 Domain.SemanticEvidence。
```

## 4. Runtime 命名

不要把当前结构描述成“两套运行时”。准确说法是：

```text
one runtime semantics
two backend adapters
```

```text
Bootstrap.Runtime
  bootstrap backend。用于自举、报告、fixed-point Stage 0。

Framework.Runtime
  typed runtime backend。用于 facade/domain 侧 RuntimeM 和 typed handlers。
```

`Framework.Domain` 里的主构造器是：

```text
DomainBootstrapBackend
DomainTypedRuntimeBackend
```

旧名 `DomainNativeRuntime` / `DomainFrameworkRuntime` 只作为兼容 pattern synonym 保留。

## 5. 后续拆分顺序

已经完成：

```text
Bootstrap.Runtime.Types
Bootstrap.Runtime.SourceGraph
Bootstrap.Runtime.Boundary
```

建议继续：

```text
Bootstrap.Runtime.Build
Bootstrap.Runtime.Validation
Bootstrap.Runtime.Interpreter
Bootstrap.Runtime.Concurrent
Bootstrap.Runtime.BootstrapHandlers
```

每一步都必须保持：

```text
stack build
domain-app-report passed
fixed-point-smoke diffs: 0
workflow-semantics-witness passed
self-artifact-witness passed
```
