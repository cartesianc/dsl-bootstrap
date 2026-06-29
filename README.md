# mytest

Haskell 架构 DSL demo。项目把应用拆成三条可跳转的前台链路：

```text
currentAst
currentEffects
currentInterpreter
```

目标：用 Haskell declaration 承载架构文档，保持 IDE 左键路径稳定。

## 入口

[app/Main.hs](app/Main.hs)

```haskell
main :: IO ()
main =
  currentInterpreter currentAst currentEffects
```

入口含义：

```text
currentAst          workflow AST
currentEffects      fact / external boundary / profile 声明
currentInterpreter  app 构建、effect 语义接入、runtime 执行
```

## 包边界

前台业务代码导入 facade 模块：

```text
Framework.Workflow   workflow DSL：chain / parallel / fact / wait / hanging
Framework.Effect     effect DSL：effect / needs / uses / externalMake / profile
Framework.Hylo       seed / unfold algebra / hylo 入口
```

后台框架代码导入：

```text
Framework.Background core app build / recursion / constraint / runtime
Core.*               AST 核心、AppPlan、effect semantics、constraint IR
Interpreter.*        runtime/view interpreter 和 algebra
```

自举前的 core 分层由 `Core.Bootstrap.defaultCoreBoundary` 描述：

```text
syntax
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

后台 IR 检查项：未知依赖、环依赖、pure core 反向依赖 runtime。

领域词汇位置：`src/AST` 和 `src/Effects/Names.hs`。拆包时迁入 domain package。

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
  -> fact / externalMake / externalTake / profile
```

Interpreter 路径：

```text
main
  -> currentInterpreter
  -> Interpreter.Runtime.runBlueprintWithEffects
  -> app build / runtime interpreter
```

## AST

[src/AST/AppBlueprint.hs](src/AST/AppBlueprint.hs)

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
      (allOf [UserKnownFact, RuntimePreparedFact])
      reportModule
  , suspense
      (anyOf [UserKnownFact, ReportGeneratedFact])
      reportModule
  , loop reportModule
  ]
```

语义：

```text
middleware body   给 body 叠加 middleware 效果
callback facts b  facts 满足后并行启动 b
suspense facts b  facts 满足后请求暂停或终止 b
loop b            forever 执行 b
```

`callback`、`suspense`、`loop` 的完整 scheduler / component registry 见 TODO。

自举范围：`blueprintApp` 与 `blueprintHanging`。前者覆盖主执行流；后者覆盖 middleware、callback、suspense、loop。

Hanging runtime v0：

```text
middleware  作为 workflow 包装语义
callback    条件满足后启动 body
suspense    记录暂停请求，精细 component registry 后续补
loop        表达有意重复
```

Middleware runtime v0：进入 active stack，执行 body，退出 active stack。component identity 匹配由 scheduler/registry 处理。
Middleware event：enter/exit 写入 `RuntimeState`；target 失败时仍执行 exit，并合并失败分支 event。

## Plugin

业务 workflow 组件放在 [src/Plugins](src/Plugins)。

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
src/Core/Plugins.hs
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

Effect 声明放在 [src/Effects](src/Effects)。

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
    , profile Production
        [ implement GenerateReport RuntimeGenerateReport
        ]
    , profile Test
        [ implement GenerateReport MockReportHandler
        ]
    ]
```

Effect DSL：

```text
fact x              声明 x 可被系统给出
fact x [needs y]    声明 x 依赖 y
fact x [uses s]     声明 x 需要 externalMake s
externalMake s i o  声明系统调用外部能力 s
externalTake x      声明外部输入 fact x
profile p [...]     声明 p 环境下的 implementation
implement s h       声明 s 由 h 解释
```

`Setup.hs` 生成：

```text
src/Effects/Theory.hs
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

[src/Core/App.hs](src/Core/App.hs) 在 runtime 前构建 `AppPlan`：

```text
validateAst
effectSemantics
fact dependency closure
send boundary check
profile check
implementation check
```

检查项：

```text
重复 fact producer
重复 externalMake boundary
重复 profile implementation
缺失 fact producer
fact dependency cycle
缺失 externalMake boundary
缺失 profile
缺失 implementation
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
       -> profile
       -> handler registry
```

`RuntimeState`：

```text
availableFacts
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
            (ensureFact (onProduceEff algebra) currentFact)
    }
```

Runtime 边界：

```text
fact 依赖会自动 ensure
runtime error 通过 RuntimeError 表达
externalMake 通过 profile 找到 implementation
RuntimeEffectEnvironment 选择 profile 和 handler registry
HandlerRegistry dispatch 到 RuntimeHandler
trace 写入 RuntimeState.runtimeTrace，并保留控制台输出
```

## 目录

```text
app/                 入口、AST、EffectTheory、解释配置
src/Framework/       前台/后台 facade
src/AST/             AppBlueprint 和业务词汇
src/Plugins/         workflow 插件
src/Effects/         effect claim、fact producer、external boundary、profile
src/Core/            AST 核心、AppPlan、effect semantics、workflow lowering
src/Interpreter/     runtime algebra、contextware、recursion model
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

SMT v0 入口：

```text
Core.Effect.Constraint.SMT.proveMinimalCore
  -> SmtResult
```

SMT v0 使用 `ConstraintError` 作为 Haskell evidence，尚未接外部 solver。

最小 effect handler dispatch：

```text
uses externalMake
  -> profile implement
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
D:\ghcup\bin\haskell-language-server-9.6.7.exe typecheck app\Main.hs
```

Workflow run report：

```powershell
stack exec ghc -- -package mytest -e "Interpreter.Runtime.WorkflowRunReport.printBlueprintRunReport AST.AppBlueprint.blueprint"
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

扫描前台 import，禁止业务前台绕过 `Framework.Workflow` / `Framework.Effect` / `Framework.Hylo` 直接依赖 `Core.*`、`Interpreter.*`、`Framework.Background`、`Blueprint` 或 `Effects.EffectTheory`。规则来源：`FrontendBoundaryPolicy`。
纯检查层：`FrontendBoundaryRules + [FrontendImport] -> [FrontendBoundaryError]`。当前命令通过文件扫描生成 import IR。

Core bootstrap boundary smoke：

```powershell
stack exec core-boundary-smoke
```

检查 `Core.Bootstrap.defaultCoreBoundary`：无环、无未知依赖、pure core 不反向依赖 runtime adapter。

## 阶段状态

已完成：

```text
AST DSL
Plugin 自动注册
EffectTheory 自动注册
EffectSemantics
AppPlan 构建检查
contextware fact ensure
minimal effect handler dispatch
RuntimeM minimal shape
runtime trace state
core bootstrap boundary map
```

待完成：

```text
profile runtime switching
callback 实时 scheduler
suspense component registry
loop lifecycle control
effect validation report
```

详细路线见 [TODO.md](TODO.md)。
