# Project Layout

## 0. 仓库定位

本仓库当前服务框架维护和自举验证。面向业务用户的 SDK 包装会单独设计。Git 发布物是 trustbase-gated self-iteration snapshot：源码本身必须能描述当前 core、验证当前 core，并物化下一阶段 framework artifact。

三种“框架自身”的写法会同时存在：

```text
new-framework-core/src/Domain
  core-as-domain self expression。这里把 framework-core 当作 domain，用 facade style 表达当前 core 的 AST/effect/fact/evidence。

new-framework-core/src/FrameworkCore
  readable current core frontend。这里把当前 core 组织成 currentTrustBase / currentAst / currentEffects / currentInterpreter / currentApp。

domain-app
  domain-side acceptance app。它验证 facade、handler、semantic evidence、runtime diagnosis、registry codegen 在真实 domain 侧能闭合。
```

这三者并存用于自举系统的多视角验证：core 要能解释自己，也要能像 domain 一样被使用，还要能通过 TrustBase 点火生成下一阶段。

当前项目按“内核、facade、自表达 domain、外部 domain”分层。

Domain framework 晋升 core framework 的操作流程见 `docs/CORE_PROMOTION_SOP.zh.md`。

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
  public facade。外部 domain 默认只接触这里。Framework.Business 是 primary capability authoring surface。

new-framework-core/src/Domain
  framework-core 自己的 self-domain expression。它通过 facade style 表达 framework-core。

new-framework-core/src/FrameworkCore
  readable framework-core frontend: baseApp currentTrustBase currentInterpreter currentAst currentEffects.
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
  稳定命名层。只放 facts、workflow names、send names、type names、handler names，并通过 Framework.Business 获取 capability authoring 所需的 name 类型。

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
前台保持声明式；算法、搜索、格式化、计算和 IO 放在 handler 或 runtime 层。
算法进入 Domain.Runtime handler/transform。
业务能力进入 Domain.Business，底层 effect IR 由 Framework.Business 自动生成。
可验证结论进入 Domain.SemanticEvidence。
```

## 4. Runtime 命名

推荐说法：

```text
one runtime semantics
two backend adapters
```

```text
Bootstrap.Runtime
  bootstrap backend。用于自举、报告、fixed-point Stage 0。

Framework.Runtime
  typed runtime backend。用于 RuntimeM interpreter 入口和兼容 re-export。

Framework.Runtime.Interpreter
  typed RuntimeM interpreter implementation。

Framework.Runtime.Types
Framework.Runtime.State
Framework.Runtime.Values
Framework.Runtime.Handlers
  typed runtime 的数据、state/snapshot、value conversion、handler/transform registry implementation。
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
self-artifact-witness passed (仅高危 artifact gate 轮次需要)
```
## 6. Public Facade 边界（当前规范）

业务前台只碰声明式入口：

```text
Framework.Ast
Framework.Business
```

其中 `Framework.Business` 是 primary capability authoring surface，负责 capability / pipeline / policy / handler binding / transform binding 的声明，并 re-export `NoInput` / `Unit` / `ErrorInput` 这类 authoring token、`EffectUnit` lowering result type，以及 `SendName` / `TypeName` / `HandlerName` / `TransformName` / `EffectName` 这类 authoring name；`Framework.Effect` 是 normalized effect/fact IR / compatibility API；`Framework.Ast` 是 AppBlueprint / workflow AST 的前台名字。业务前台不导入 `Framework.Effect`、`Framework.Runtime`、`Framework.Background`、`Bootstrap.*`。

handler implementation 只碰：

```text
Framework.Handler
```

算法、IO、typed value conversion、具体 handler/transform 实现放在 `Domain.Runtime` 或等价 handler 模块中。

框架维护、证据、diagnosis、fixed point 和 artifact gate 使用：

```text
Framework.TrustBase
```

当前分层没有把 runtime 全暴露到前台；边界如下：

```text
business frontend -> Framework.Ast / Framework.Business
handler implementation -> Framework.Handler
self-iteration / evidence -> Framework.TrustBase
lowering IR / compatibility -> Framework.Effect
runtime internals -> Framework.Runtime / Framework.Runtime.* / Bootstrap.Runtime.*
```
