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
  -> Core.App.app
  -> recursionScheme
  -> cata / contextware / algebra
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

`callback`、`suspense`、`loop` 的完整 scheduler / component registry 仍在 TODO 阶段。

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

当前生成结果形状：

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

```haskell
recursionScheme cata contextware algebra ast effects
```

## Runtime

当前 runtime 链路：

```text
AppBlueprint
  -> compileWorkflowEff
  -> contextware effects algebra
  -> runBlueprintWithAlgebra
```

`contextware` 使用 `EffectTheory` 生成的 `effectSemantics` 包装 `onProduceEff`：

```haskell
contextware effects algebra =
  algebra
    { onProduceEff =
        ensureFact (effectSemantics effects) (onProduceEff algebra)
    }
```

当前边界：

```text
fact 依赖会自动 ensure
externalMake 当前输出 trace
profile implementation 当前用于完备性检查
真实 IO handler dispatch 后续接入
```

## 目录

```text
app/                 当前入口、当前 AST、当前 EffectTheory、当前解释配置
src/AST/             前台 AppBlueprint 和业务词汇
src/Plugins/         workflow 插件
src/Effects/         effect claim、fact producer、external boundary、profile
src/Core/            AST 核心、AppPlan、effect semantics、workflow lowering
src/Interpreter/     runtime algebra、contextware、recursion model
docs/                DSL 使用说明
TODO.md              后续路线
```

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

## 当前阶段

已完成：

```text
AST DSL
Plugin 自动注册
EffectTheory 自动注册
EffectSemantics
AppPlan 构建检查
contextware fact ensure
runtime trace
```

待完成：

```text
真实 handler dispatch
profile runtime switching
callback 实时 scheduler
suspense component registry
loop lifecycle control
effect validation report
```

详细路线见 [TODO.md](TODO.md)。
