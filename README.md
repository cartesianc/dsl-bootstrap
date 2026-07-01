# mytest

Haskell 架构 DSL demo。项目把应用拆成三条可跳转的前台链路：

```text
currentAst
currentEffects
currentInterpreter
```

目标：用 Haskell declaration 承载架构文档，保持 IDE 左键路径稳定。

当前工程分成两个 package：

```text
framework-core   框架核心、runtime、validation、constraint IR、SMT、import graph checker
domain-app       当前业务蓝图、plugins、effect 声明、main 和 smoke
```

依赖方向：

```text
domain-app -> framework-core
framework-core -> domain-app  禁止
```

`stack build` 负责强制 package 依赖方向，`core-boundary-smoke` 会读取真实 import graph 补充检查。

## 入口

[domain-app/app/Main.hs](domain-app/app/Main.hs)

```haskell
main :: IO ()
main =
  currentInterpreter currentAst currentEffects
```

入口含义：

```text
currentAst          workflow AST
currentEffects      fact / transform / external boundary 声明
currentInterpreter  app 构建、effect 语义接入、runtime 执行
```

## 包边界

业务前台导入：

```text
Blueprint          当前 domain 的 workflow DSL：chain / parallel / fact / wait / hanging
Framework.Effect   effect DSL：effect / needs / uses / transform / externalMake
Framework.Hylo     seed / unfold algebra / hylo 入口
```

后台框架代码导入：

```text
Framework.Background core app build / recursion / constraint / runtime
Core.*               AST 核心、AppPlan、effect semantics、constraint IR
Interpreter.*        runtime/view interpreter 和 algebra
```

`Framework.Workflow` 是 framework 级 workflow facade。当前业务为了保留具体 `WorkflowFact`、`WorkflowName`、`Interceptor` 的简洁写法，使用 `domain-app/src/Blueprint.hs`。

前台语法契约由 `Core.Language.defaultLanguageSpec` 描述。它记录 keyword、参数形状、父上下文、结果类型和 lowering target。
`Core.Language.defaultElaborationContract` 记录每个 lowering target 对应的实现入口，例如 `LowerToCallback -> Framework.Workflow.callback`。

自举前的 core 分层由 `Core.Bootstrap.defaultCoreBoundary` 描述：

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

边界检查项：未知依赖、环依赖、pure core 反向依赖 runtime、package 反向 import、真实 import 越过 slice 依赖闭包。

领域词汇位置：`framework-core/src/AST` 和 `framework-core/src/Effects/Names.hs`。当前 vocabulary 仍属于 core 语言层，具体业务蓝图放在 `domain-app`。

详细边界见 [docs/PACKAGE_BOUNDARY.zh.md](docs/PACKAGE_BOUNDARY.zh.md)。

外部 JSON、RPC 或 fixture 通过 `Framework.Hylo` 下的 effectful unfold algebra 进入 `AppBlueprint + EffectTheory`。

## 左键路径

AST 路径：

```text
main
  -> currentAst
  -> blueprint
  -> app / hooks
  -> plugins / workflow nodes
```

Effect 路径：

```text
main
  -> currentEffects
  -> effectTheory
  -> systemEffect / userEffect / reportEffect / ...
  -> fact / transform / externalMake / externalTake
```

Interpreter 路径：

```text
main
  -> currentInterpreter
  -> Interpreter.Runtime.runBlueprintWithEffects
  -> app build / runtime interpreter
```

## AST

[framework-core/src/AST/AppBlueprint.hs](framework-core/src/AST/AppBlueprint.hs) 定义蓝图类型。
[domain-app/src/Domain/AppBlueprint.hs](domain-app/src/Domain/AppBlueprint.hs) 定义当前业务蓝图。

```haskell
data AppBlueprint = AppBlueprint
  { blueprintApp :: App
  , blueprintHanging :: AppHanging
  }
```

`blueprintApp` 是主 workflow：

```haskell
app :: App
app =
  chain AppFlow
    [ lifecycleStart
    , userModule
    , reportModule
    , lifecycleEnd
    ]
```

`blueprintHanging` 是外挂 workflow：

```haskell
hooks :: AppHanging
hooks =
  hanging
    [ configurationHook
    , bootHook
    , runtimeHook
    , loggingHook
    , userHook
    , reportHook
    , shutdownHook
    ]
```

## Workflow 节点

主 workflow 节点：

```text
chain
parallel
fact
wait
fallback
race
choice
```

`fact` 是 workflow 叶子：

```haskell
fact [UserKnownFact]
```

`wait` 等待 fact 条件：

```haskell
wait [UserKnownFact] reportModule
```

条件组合：

```haskell
wait (allOf [UserKnownFact, RuntimePreparedFact]) reportModule
wait (anyOf [UserKnownFact, ReportGeneratedFact]) reportModule
```

## Hanging 节点

`hanging` 节点：

```text
middleware
callback
suspense
loop
```

示例：

```haskell
hanging
  [ middleware ReportMiddleware reportModule
  , callback
      ShutdownFlow
      reportModule
  , suspense ReportModuleFlow
  , loop reportModule
  ]
```

语义：

```text
middleware body   给 body 叠加 middleware 效果
callback target b  进入 target 时并行启动 b
suspense target    记录对 target 的暂停请求
loop b            forever 执行 b
```

`callback` 已按 workflow target 注册。`suspense` 当前只记录请求和 target 状态，真正取消等 component registry 完整后再补。

自举范围：`blueprintApp` 与 `blueprintHanging`。前者覆盖主执行流；后者覆盖 middleware、callback、suspense、loop。

Hanging runtime 当前语义：

```text
middleware  作为 workflow 包装语义
callback    进入目标 workflow 时启动 body
suspense    记录暂停请求和 target 状态
loop        表达有意重复
```

Middleware runtime 当前语义：进入 active stack，执行 body，退出 active stack。component identity 匹配由 scheduler/registry 处理。
Middleware event：enter/exit 写入 `RuntimeState`；target 失败时仍执行 exit，并合并失败分支 event。

## Plugin

业务 workflow 组件放在 [domain-app/src/Plugins](domain-app/src/Plugins)。

插件用 `-- plugin:` 注册：

```haskell
module Plugins.Lifecycle where

import Blueprint

-- plugin: lifecycleStart
lifecycleStart :: Chain
lifecycleStart =
  chain LifecycleStartFlow
    [ configurationModule
    , bootModule
    ]
```

`Setup.hs` 生成统一出口：

```text
domain-app/src/Plugins.hs
```

插件之间的 import 区块由 `Setup.hs` 维护：

```haskell
-- plugin imports: begin
import Plugins.Boot
import Plugins.Configuration
-- plugin imports: end
```

业务代码导入统一出口：

```haskell
import Blueprint
import Plugins
```

## EffectTheory

Effect 声明放在 [domain-app/src/Effects](domain-app/src/Effects)。

Effect 用 `-- effect:` 注册：

```haskell
module Effects.Report where

import Effects.EffectTheory

-- effect: reportEffect
reportEffect :: EffectUnit
reportEffect =
  effect ReportEffect
    [ fact CalculationSectionOpenedFact
        [ needs UserKnownFact
        ]
    , fact ReportGeneratedFact
        [ needs AddCalculatedFact
        , needs FactorialCalculatedFact
        , needs SquaresCalculatedFact
        , uses GenerateReport
        ]
    , externalMake GenerateReport ReportInput ReportOutput
    ]
```

Effect DSL：

```text
fact x              声明 x 可被系统给出
fact x [needs y]    声明 x 依赖 y
fact x [uses s]     声明 x 需要 externalMake s
transform i o t     声明 i -> o 的纯接口适配
externalMake s i o  声明系统调用外部能力 s
externalTake x      声明外部输入 fact x
```

`Setup.hs` 生成：

```text
domain-app/src/Effects/Theory.hs
```

生成结果形状：

```haskell
effectTheory :: EffectTheory
effectTheory =
  theory
    [ Effects.Demo.demoEffect
    , Effects.Logging.loggingEffect
    , Effects.Report.reportEffect
    , Effects.System.systemEffect
    , Effects.User.userEffect
    ]
```

## App 构建

[framework-core/src/Core/App.hs](framework-core/src/Core/App.hs) 在 runtime 前构建 `AppPlan`：

```text
validateAst
effectSemantics
fact dependency closure
send boundary check
transform contract check
take/make rule check
```

检查项：

```text
重复 fact producer
重复 externalMake boundary
缺失 fact producer
fact dependency cycle
缺失 externalMake boundary
缺失 transform source
缺失 take/make rule
```

检查通过后进入 interpreter：

```text
currentInterpreter currentAst currentEffects
  -> Interpreter.Runtime.runBlueprintWithEffects
```

## Runtime

Runtime 链路：

```text
AppBlueprint
  -> compileWorkflowEff
  -> contextwareWithEffectEnvironment environment effects algebra
  -> RuntimeM
  -> runBlueprintWithAlgebra
```

`RuntimeM` 形状：

```text
Reader  RuntimeEnv
State   RuntimeState
Except  RuntimeError
IO      handler execution
Writer  runtimeTrace
```

`RuntimeEnv`：

```text
RuntimeEnv
  -> EffectSemantics
  -> RuntimeEffectEnvironment
       -> handler registry
       -> transform registry
```

`RuntimeState`：

```text
availableFacts
availablePipeTypes
runtimeValues
runtimeTypedValues
runtimeFactClaims
runtimeTrace
runtimeMiddlewareStack
runtimeMiddlewareEvents
```

`contextware` 用 `effectSemantics` 包装 `onProduceEff`，并注入对应 `RuntimeEnv`：

```haskell
contextwareWithEffectEnvironment environment effects algebra =
  algebra
    { onProduceEff =
        \currentFact ->
          withRuntimeEnv
            (runtimeEnv environment (effectSemantics effects))
            (resolveFactClaim (onProduceEff algebra) currentFact)
    }
```

Runtime 边界：

```text
fact claim 会自动推进依赖解析
runtime error 通过 RuntimeError 表达
externalMake 通过 handler registry 找到 RuntimeHandler
send contract 固定 handler input/output
transform 通过 transform registry 执行纯 value interface 适配
RuntimeTypedValue 保留 handler pipeline 的类型标签
RuntimeEffectEnvironment 选择 handler registry 和 transform registry
HandlerRegistry dispatch 到 RuntimeHandler
trace 写入 RuntimeState.runtimeTrace，并保留控制台输出
```

## 目录

```text
framework-core/      framework-core package
  src/Framework/     前台/后台 facade
  src/AST/           AppBlueprint 类型和当前 core vocabulary
  src/Core/          AST 核心、LanguageSpec、ElaborationContract、AppPlan、effect semantics、workflow lowering
  src/Interpreter/   runtime algebra、contextware、recursion model
domain-app/          domain-app package
  app/               入口、AST、EffectTheory、解释配置、smoke
  src/Domain/        当前业务蓝图
  src/Plugins/       workflow 插件
  src/Effects/       effect claim、fact producer、transform、external boundary
docs/                DSL 使用说明
TODO.md              后续路线
```

最小核心验收入口：

```text
Core.App.Boundary.checkMinimalCore
  -> AppPlan
  -> ConstraintFact
  -> ConstraintError
  -> MinimalCoreReport
```

SMT 入口：

```text
Core.Effect.Constraint.SMT.proveMinimalCore
  -> SmtResult

Core.Effect.Constraint.SMT.proveMinimalCoreWithAvailableSolver
  -> IO [SmtResult]
```

默认入口保留 Haskell evidence。真实 solver backend 会生成 SMT-LIB，自动查找 `z3` 或 `cvc5`；本机没有 solver 时返回 skipped，不影响 app build。

最小 effect handler dispatch：

```text
uses externalMake
  -> RuntimeEffectEnvironment
  -> HandlerRegistry
  -> RuntimeHandler
```

自举规则：使用同一套 DSL、AppPlan、Constraint IR 和 handler dispatch；不得新增 core 专用语义。

## 构建

```powershell
stack build
stack exec mytest
```

HLS 检查：

```powershell
D:\ghcup\bin\haskell-language-server-9.6.7.exe typecheck domain-app\app\Main.hs
```

Workflow run report：

```powershell
stack exec ghc -- -package framework-core -package domain-app -e "Interpreter.Runtime.WorkflowRunReport.printBlueprintRunReport Domain.AppBlueprint.blueprint"
```

Runtime boundary smoke：

```powershell
stack exec runtime-smoke
```

覆盖 runtime core。JSON fixture 先解析成 `AppSeed + EffectTheorySeed`，再经 `Framework.Hylo` 进入 app build / runtime / SMT。

Frontend boundary smoke：

```powershell
stack exec frontend-boundary-smoke
```

扫描前台 import，禁止业务前台绕过 `Blueprint` / `Framework.Effect` / `Framework.Hylo` 直接依赖 `Core.*`、`Interpreter.*`、`Framework.Background` 或 `Effects.EffectTheory`。规则来源：`FrontendBoundaryPolicy`。
纯检查层：`FrontendBoundaryRules + [FrontendImport] -> [FrontendBoundaryError]`。当前命令通过文件扫描生成 import IR。

Core bootstrap boundary smoke：

```powershell
stack exec core-boundary-smoke
```

检查 package import graph 和 `Core.Bootstrap.defaultCoreBoundary`：`framework-core` 不反向依赖 `domain-app`，core slice 无环、无未知依赖，并且真实 import 落在声明的 slice 依赖闭包内。

## 阶段状态

已完成：

```text
AST DSL
Plugin 自动注册
EffectTheory 自动注册
EffectSemantics
canonical effect boundary IR
send/transform contracts
pure transform contracts
AppPlan 构建检查
contextware fact resolution
minimal effect handler dispatch
RuntimeM minimal shape
runtime trace state
runtime typed value pipeline
runtime pure transform pipeline
core bootstrap boundary map
two-package build boundary
package import graph smoke
frontend language spec
frontend elaboration contract
```

待完成：

```text
runtime environment override/layer composition
flatMap / dynamic effect composition
callback target dispatch polish
suspense real cancellation
loop lifecycle control
effect validation report
```

详细路线见 [TODO.md](TODO.md)。
