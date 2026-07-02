# Core 自举设计

本文档描述 `framework-core` 如何用本项目自己的 AST / EffectTheory / AppPlan / ConstraintIR 描述和检查自身。

目标不是用 v0 自举替换现有模块。目标是先把现有模块纳入同一套架构图，再逐步让 core 的构建、校验、证明和 runtime 边界由同一套 DSL 表达。

## 1. 当前模块盘点

当前工程是两个 Stack/Cabal package：

```text
framework-core
domain-app
```

依赖方向：

```text
domain-app -> framework-core
framework-core -> domain-app  禁止
```

当前 Haskell 文件数量：

```text
framework-core/src   70
domain-app/src       17
domain-app/app        7
total                94
```

### 1.1 framework-core 模块分组

| 分组 | 数量 | 责任 |
| --- | ---: | --- |
| AST | 5 | AppBlueprint、generic fact/name/interceptor carrier |
| Core.Workflow / Core.Architecture | 8 | AST 数据结构、free 结构、recursion、workflow lowering |
| Core.App | 4 | AppPlan build、ana/hylo seed、minimal core report、claim scope |
| Core.Effect | 5 | EffectTheory、effect semantics、constraint IR、SMT backend |
| Core.Language | 5 | 前台语言规范、keyword contract、elaboration contract |
| Core.Boundary / Bootstrap | 4 | core slice map、frontend boundary、import graph、AST validation |
| Framework facade | 4 | 前台可导入 facade：Workflow / Effect / Hylo / Background |
| Interpreter facade / view | 15 | legacy interpreter facade、view interpreter、workflow report |
| Runtime interpreter | 20 | RuntimeM、contextware、handler dispatch、middleware、diagnosis、workflow runtime |

当前 `framework-core` 的主要模块：

```text
AST.AppBlueprint
AST.Facts
AST.Interceptors
AST.Names
AST.Vocabulary

Core.Architecture
Core.Architecture.Internal
Core.Architecture.Cata
Core.Architecture.Cata.Types
Core.Architecture.Recursion
Core.Workflow.Eff
Core.Workflow.Semantics
Core.Workflow.Semantics.Render

Core.App
Core.App.Ana
Core.App.Boundary
Core.App.ClaimScope

Effects.EffectTheory
Effects.Names
Core.Effect.Semantics
Core.Effect.Constraint
Core.Effect.Constraint.SMT

Core.Language
Core.Language.Spec
Core.Language.Constraint
Core.Language.Validation
Core.Language.Elaboration

Core.Bootstrap
Core.Boundary.Frontend
Core.ImportGraph
Core.Validation

Framework.Workflow
Framework.Effect
Framework.Hylo
Framework.Background

Interpreter.Runtime.*
Interpreter.View.*
Interpreter.*
```

### 1.2 domain-app 模块分组

| 分组 | 数量 | 责任 |
| --- | ---: | --- |
| Domain facade | 1 | `Blueprint`，业务 workflow 前台 facade |
| Domain modules | 4 | 当前业务蓝图、workflow/effect vocabulary、runtime binding |
| Effects | 6 | 当前业务 effect claim 和 effect registry |
| Plugins | 8 | 当前业务 workflow 插件和插件 registry |
| app executables | 8 | main、当前 AST/effects/interpreter、smoke executable、runtime smoke module |

当前 `domain-app/src` 模块：

```text
Blueprint
Domain.AppBlueprint
Domain.EffectVocabulary
Domain.Runtime
Domain.Vocabulary

Effects.Demo
Effects.Logging
Effects.Report
Effects.System
Effects.Theory
Effects.User

Plugins
Plugins.Boot
Plugins.Configuration
Plugins.Handle
Plugins.Lifecycle
Plugins.Logging
Plugins.Report
Plugins.Shutdown
```

当前 `domain-app/app` executable 入口：

```text
Main
CurrentAst
CurrentEffects
InterpretConfig
RuntimeSmoke
FrontendBoundarySmoke
Runtime.Smoke
CoreBoundarySmoke
```

## 2. 自举定义

本项目里的 core 自举指：

```text
framework-core 用自己的 AST / EffectTheory / AppPlan / ConstraintIR
描述 framework-core 自身的模块结构、依赖边界、校验流程、证明流程和 runtime 适配边界。
```

它不是单纯的 code generator。它也不是把 `domain-app` 替换成 JSON。

自举对象是 `framework-core` 的核心结构：

```text
Core.Bootstrap.defaultCoreBoundary
Core.ImportGraph
Core.Boundary.Frontend
Core.Language.defaultLanguageSpec
Core.Language.defaultElaborationContract
Core.App.Boundary.MinimalCoreReport
Core.Effect.Constraint
Core.Effect.Constraint.SMT
Interpreter.Runtime.*
```

自举产物应当包括：

```text
coreBootstrapBlueprint
coreBootstrapEffects
coreBootstrapAppPlan
coreBootstrapConstraintIR
coreBootstrapProofReport
coreBootstrapRuntimeReport
```

## 3. 设计约束

### 3.1 保留现有模块

v0 自举不得删除、合并或替代现有 94 个 Haskell 文件。

第一阶段只新增自举描述层：

```text
Core.Bootstrap.Blueprint     建议新增
Core.Bootstrap.Effects       建议新增
Core.Bootstrap.Report        建议新增
Core.Bootstrap.Runtime       可选
```

现有模块继续作为被描述对象。

### 3.2 保留代码即文档

Canonical documentation 仍然是 Haskell declaration。

自举可以生成或读取 seed，但最终需要回到可跳转的 Haskell 前台：

```text
Haskell declaration
  -> HLS symbol graph
  -> 左键路径
  -> AppPlan / ConstraintIR / Runtime
```

禁止把核心文档退化成匿名 JSON map 或运行时 registry。

### 3.3 Core 和 runtime 分离

`PureCore` 不依赖 `RuntimeBackend`。

当前 `Core.Bootstrap.defaultCoreBoundary` 已经表达了这个约束：

```text
PureCore          syntax / recursion / effect-theory / app-build / constraint-ir
Verification      proof-boundary / smt-backend / frontend-boundary
RuntimeBackend    runtime-adapter
FrontendFacade    Framework.Workflow / Framework.Effect / Framework.Hylo
```

自举设计必须继续满足：

```text
pure core -> runtime 禁止
runtime -> pure core 允许
domain-app -> framework-core 允许
framework-core -> domain-app 禁止
```

## 4. 用 AST 统一 core 模块关系

### 4.1 CoreBootstrapBlueprint

建议新增概念入口：

```haskell
coreBootstrapBlueprint :: AppBlueprint
coreBootstrapBlueprint =
  AppBlueprint
    { blueprintApp = coreBootstrapApp
    , blueprintHanging = coreBootstrapHanging
    }
```

`coreBootstrapApp` 描述 core 自检主流程：

```haskell
coreBootstrapApp :: App
coreBootstrapApp =
  chain CoreBootstrapFlow
    [ discoverPackages
    , classifyModules
    , buildImportGraph
    , validateCoreBoundary
    , validateFrontendBoundary
    , validateLanguageContract
    , buildMinimalCoreReport
    , buildConstraintIR
    , runSmtProof
    , validateRuntimeAdapter
    , publishBootstrapReport
    ]
```

这是概念形状。`WorkflowFact` / `WorkflowName` 已经是 generic carrier。core bootstrap 需要自己的 vocabulary 模块：

```text
Core.Bootstrap.Vocabulary
```

该模块用 pattern synonym 给 core bootstrap fact/name 命名，不把自举词汇塞回 `AST.Facts` / `AST.Names`。

### 4.2 主流程分支

可以把 core 自检拆成几个 workflow 组件：

```text
discoverPackages
  读取 framework-core / domain-app package 信息。

classifyModules
  按 AST、Core.Workflow、Core.Effect、Core.App、Validator、Runtime、Facade、Domain 分组。

buildImportGraph
  调用 Core.ImportGraph，生成真实 import graph。

validateCoreBoundary
  调用 Core.Bootstrap.checkCoreBoundaryWithImportGraph。

validateFrontendBoundary
  调用 Core.Boundary.Frontend，检查业务前台是否绕过 facade。

validateLanguageContract
  检查 Core.Language.defaultLanguageSpec 和 defaultElaborationContract。

buildMinimalCoreReport
  调用 Core.App.Boundary.checkMinimalCore / checkMinimalCoreModel。

buildConstraintIR
  从 AppPlan 生成 Core.Effect.Constraint。

runSmtProof
  调用 Core.Effect.Constraint.SMT。

validateRuntimeAdapter
  执行 runtime-smoke 覆盖 handler dispatch、pending claim、middleware、callback、suspense。

publishBootstrapReport
  汇总模块表、边界结果、SMT evidence、runtime smoke。
```

### 4.3 并行结构

可并行的部分用 `parallel` 表达：

```haskell
validateStaticContracts :: Parallel
validateStaticContracts =
  parallel StaticContractChecks
    [ validateCoreBoundary
    , validateFrontendBoundary
    , validateLanguageContract
    ]
```

```haskell
validateBackends :: Parallel
validateBackends =
  parallel BackendChecks
    [ runSmtProof
    , validateRuntimeAdapter
    ]
```

### 4.4 Hanging 结构

自举 v0 的 hanging 保持保守：

```haskell
coreBootstrapHanging :: AppHanging
coreBootstrapHanging =
  hanging
    [ middleware BootstrapTrace coreBootstrapApp
    , callback BootstrapFailedFact publishFailureReport
    ]
```

`loop` 和 `suspense` 暂不作为自举 v0 的核心能力。

原因：

```text
core 自检是收敛流程，不是常驻服务。
loop / suspense 属于 runtime scheduler 能力，先不要污染 core bootstrap 主线。
```

## 5. 用 EffectTheory 统一 core 依赖

### 5.1 CoreBootstrapEffects

建议新增概念入口：

```haskell
coreBootstrapEffects :: EffectTheory
coreBootstrapEffects =
  theory
    [ coreModuleEffect
    , coreBoundaryEffect
    , coreLanguageEffect
    , coreProofEffect
    , coreRuntimeEffect
    ]
```

每个 effect unit 用现有前台 DSL：

```haskell
effect CoreBoundaryEffect
  [ fact ImportGraphBuiltFact
      [ uses ExtractImportGraph
      ]
  , fact CoreBoundaryValidatedFact
      [ needs ImportGraphBuiltFact
      , uses CheckCoreBoundary
      ]
  , externalMake ExtractImportGraph SourceTreeInput ImportGraphOutput
  , externalMake CheckCoreBoundary BoundaryInput BoundaryResult
  , profile Production
      [ implement ExtractImportGraph RuntimeExtractImportGraph
      , implement CheckCoreBoundary RuntimeCheckCoreBoundary
      ]
  ]
```

### 5.2 Fact 分类

Core 自举 facts 可以按层分类：

```text
模块发现 facts
  PackageModulesDiscoveredFact
  FrameworkCoreModulesClassifiedFact
  DomainAppModulesClassifiedFact

边界 facts
  ImportGraphBuiltFact
  CoreBoundaryDeclaredFact
  CoreBoundaryValidatedFact
  FrontendBoundaryValidatedFact

语言 facts
  LanguageSpecValidatedFact
  ElaborationContractValidatedFact

AppPlan / Constraint facts
  MinimalCoreReportBuiltFact
  ConstraintIRBuiltFact
  ConstraintIRValidatedFact

证明 facts
  SmtLibGeneratedFact
  SmtProofPassedFact

Runtime facts
  RuntimeHandlerDispatchPassedFact
  RuntimeMiddlewarePassedFact
  RuntimeCallbackPassedFact
  RuntimeSuspensePassedFact

发布 facts
  BootstrapReportGeneratedFact
  MinimalCoreFrozenFact
```

这些 facts 不一定一次性加入 `AST.Facts`。v0 可以先挑最小闭包。

### 5.3 externalMake 分类

需要外部世界或运行环境参与的能力才写 `externalMake`：

```text
ReadPackageFiles
ExtractRealImportGraph
RunStackBuild
RunFrontendBoundarySmoke
RunCoreBoundarySmoke
RunRuntimeSmoke
RunSmtSolver
WriteBootstrapReport
```

纯函数转换不写 `externalMake`，应写 `transform` 或留在 core 纯模块：

```text
EffectTheory -> EffectSemantics
AppPlan -> ConstraintIR
ConstraintIR -> SMT-LIB
CoreBoundary + ImportGraph -> BoundaryErrors
```

### 5.4 Validator 组件

Validator 不应该散落在 runtime。

当前 validators 包括：

```text
Core.Validation
Core.Bootstrap.checkCoreBoundary
Core.Bootstrap.checkCoreBoundaryWithImportGraph
Core.Boundary.Frontend
Core.Language.Validation
Core.Language.Constraint
Core.Language.Elaboration
Core.Effect.Constraint
Core.Effect.Constraint.SMT
Core.App.Boundary
domain-app/app/*Smoke
```

自举时统一看成：

```text
validator workflow component
  + validator effect claim
  + validator proof/report output
```

例如：

```text
validateCoreBoundary
  workflow component

CoreBoundaryValidatedFact
  effect fact

CheckCoreBoundary
  externalMake 或 pure transform

CoreBoundaryReport
  report output
```

## 6. 自举模块分类

自举文档中建议使用以下组件类别。

### 6.1 Core Component

稳定核心组件：

```text
syntax
language-spec
recursion
hylo
effect-theory
app-build
constraint-ir
proof-boundary
```

这些组件应尽量保持 pure。

### 6.2 Validator Component

检查组件：

```text
ast-validator
frontend-boundary-validator
package-boundary-validator
core-slice-validator
language-spec-validator
elaboration-validator
effect-constraint-validator
smt-validator
runtime-smoke-validator
```

Validator 产生 report / evidence，不直接修改 core。

### 6.3 Runtime Component

运行组件：

```text
runtime-adapter
runtime-contextware
handler-registry
fact-resolution
middleware-runtime
diagnosis-runtime
workflow-runtime
```

Runtime 可以依赖 pure core；pure core 不依赖 runtime。

### 6.4 Frontend Component

前台 facade：

```text
Framework.Workflow
Framework.Effect
Framework.Hylo
Blueprint
Effects.*
Plugins.*
Domain.AppBlueprint
```

它们负责代码即文档路径。

### 6.5 Domain Component

当前业务应用：

```text
domain-app/src/Domain.AppBlueprint
domain-app/src/Plugins
domain-app/src/Effects
domain-app/app/Main
```

Domain 是 framework 的使用者，不是 framework 自举的核心。

## 7. 分阶段实施

### Phase 0：冻结当前边界

状态：基本完成。

验收命令：

```powershell
stack build
stack exec mytest
stack exec frontend-boundary-smoke
stack exec core-boundary-smoke
stack exec runtime-smoke
```

当前结果：已通过。

本阶段产物：

```text
framework-core / domain-app package split
Core.Bootstrap.defaultCoreBoundary
docs/PACKAGE_BOUNDARY.zh.md
README 当前架构说明
```

### Phase 1：新增 CoreBootstrap vocabulary

目标：为 core 自举准备最小词汇。

建议新增：

```text
CoreBootstrapFlow
DiscoverPackagesFlow
ValidateBoundariesFlow
BuildProofFlow
ValidateRuntimeFlow

PackageModulesDiscoveredFact
ImportGraphBuiltFact
CoreBoundaryValidatedFact
FrontendBoundaryValidatedFact
LanguageSpecValidatedFact
ElaborationContractValidatedFact
MinimalCoreReportBuiltFact
ConstraintIRBuiltFact
SmtProofPassedFact
RuntimeSmokePassedFact
BootstrapReportGeneratedFact
```

实现位置：

```text
framework-core/src/Core/Bootstrap/Vocabulary.hs
```

写法：

```text
pattern CoreBootstrapFlow = WorkflowName "CoreBootstrapFlow"
pattern ImportGraphBuiltFact = WorkflowFact "ImportGraphBuiltFact"
```

### Phase 2：新增 CoreBootstrapBlueprint

建议新增：

```text
framework-core/src/Core/Bootstrap/Blueprint.hs
```

内容：

```haskell
coreBootstrapBlueprint :: AppBlueprint
coreBootstrapApp :: App
coreBootstrapHanging :: AppHanging
```

这一阶段只写结构，不接真实 effect。

验收：

```text
能左键进入 coreBootstrapApp
能看到 chain / parallel / fact / wait
不依赖 domain-app
不改 runtime
```

### Phase 3：新增 CoreBootstrapEffects

建议新增：

```text
framework-core/src/Core/Bootstrap/Effects.hs
```

内容：

```haskell
coreBootstrapEffects :: EffectTheory
```

声明：

```text
core 自举 facts
core validator dependencies
externalMake for file system / stack / SMT
profile implementation
```

验收：

```text
Core.App.app coreBootstrapBlueprint coreBootstrapEffects 通过
MinimalCoreReport 可生成
ConstraintIR 可生成
```

### Phase 4：把现有 smoke 纳入 AST

当前 smoke：

```text
frontend-boundary-smoke
core-boundary-smoke
runtime-smoke
```

目标：

```text
把 smoke executable 的语义映射成 coreBootstrap facts。
```

不要删除现有 smoke executable。

v0 可以先让 bootstrap workflow 调用它们，之后再把部分检查下沉为纯 validator。

### Phase 5：生成 CoreBootstrapReport

建议新增：

```text
Core.Bootstrap.Report
```

报告内容：

```text
模块数量
模块分组
package import direction
Core.Bootstrap slice validation
frontend boundary validation
language spec validation
elaboration contract validation
minimal core report
SMT result
runtime smoke result
```

验收：

```text
一个 report 能回答“framework-core 当前是否可自举”
失败时能定位到 slice / module / fact / externalMake / validator
```

### Phase 6：Haskell facade 生成器

这一阶段才考虑生成 Haskell 前台文件。

生成目标：

```text
Core.Bootstrap.Blueprint
Core.Bootstrap.Effects
```

要求：

```text
生成结果仍是 Haskell declaration
每个关键节点有稳定名字
HLS 左键路径保留
不直接生成 runtime AST
```

### Phase 7：自举闭环

目标：

```text
core bootstrap workflow 能检查并报告 framework-core 自身。
core boundary 变化能被 bootstrap workflow 发现。
frontend facade 违规能被 bootstrap workflow 发现。
runtime adapter 失败能被 bootstrap workflow 发现。
```

完成后再讨论：

```text
是否让部分 core module 由 seed 生成
是否用 hylo 加速外部 fixture 到 core report
是否把 Core.Bootstrap.defaultCoreBoundary 也转为 DSL 前台 claim
```

## 8. 不做事项

v0 自举不做：

```text
不删除现有模块
不把 domain-app 替换成 JSON
不把 Haskell 前台替换成匿名 registry
不让 pure core import runtime
不把 smoke executable 一次性移除
不重写 callback / suspense / loop scheduler
不强行一次性参数化整个 AST vocabulary
```

## 9. 成功标准

第一阶段成功标准：

```text
coreBootstrapBlueprint 存在
coreBootstrapEffects 存在
Core.App.app 能构建 core bootstrap AppPlan
ConstraintIR 能从 core bootstrap AppPlan 生成
SMT backend 能证明核心闭包
runtime smoke 仍通过
frontend-boundary-smoke 仍通过
core-boundary-smoke 仍通过
```

第二阶段成功标准：

```text
coreBootstrapReport 能输出模块清单和边界状态
新增 core module 时，报告能指出它属于哪个 slice
非法 import 时，报告能定位 source module / target module / slice
缺失 effect implementation 时，报告能定位 externalMake 和 profile
```

第三阶段成功标准：

```text
bootstrap seed 能生成 Haskell facade
生成的 Haskell facade 能左键跳转
生成的 facade 能通过 Setup / cabal / HLS
自举不破坏当前 domain-app 的代码即文档路径
```

## 10. 当前判断

当前状态已经适合进入：

```text
Phase 1：CoreBootstrap vocabulary
Phase 2：CoreBootstrapBlueprint
```

不建议直接进入：

```text
Phase 6：Haskell facade 生成器
Phase 7：完整自举闭环
```

原因：

```text
现有 core 模块已经分层，但 core 自举 AST 还不存在。
现有 validator 很强，但还没有被统一成 coreBootstrap workflow。
现有 EffectTheory 能表达 take/make/transform/externalMake，但 core bootstrap vocabulary 还没写出来。
```

推荐下一步：

```text
1. 新增 core bootstrap facts / workflow names。
2. 新增 Core.Bootstrap.Blueprint，只描述结构。
3. 新增 Core.Bootstrap.Effects，只声明依赖。
4. 用 Core.App.app 构建 core bootstrap AppPlan。
5. 再把现有 smoke 和 SMT 纳入该 AppPlan。
```
