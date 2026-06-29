# dsl设计模式

这是一个 Haskell 架构 demo。项目把应用结构写成可跳转、可组合的 AST eDSL。执行细节由 interpreter 负责。

## 文档引用

DSL 前台写法和插件扩展流程见：[AST DSL 使用说明](docs/AST_SPEC.zh.md)。

## 设计目标

前台代码只描述结构：

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

开发时点进 `userModule`、`reportModule`，看到的仍然是 DSL 节点。模块的执行方式、渲染方式、runtime 行为由 interpreter 决定。

## 运行入口

`app/Main.hs` 是当前程序装配页：

```haskell
main :: IO ()
main =
  currentInterpreter currentAst currentEffects
```

`currentAst` 放在 `app/CurrentAst.hs`：

```haskell
currentAst :: AppBlueprint
currentAst =
  blueprint
```

`currentEffects` 放在 `app/CurrentEffects.hs`：

```haskell
currentEffects :: EffectTheory
currentEffects =
  effectTheory
```

`currentInterpreter` 放在 `app/InterpretConfig.hs`：

```haskell
interpretConfig :: InterpretConfig
interpretConfig =
  InterpretConfig
    { interpretRecursionModel = cata
    , interpretContextware = contextware
    , interpretFAlgebra = algebra
    }
```

当前解释链：

```haskell
app currentAst currentEffects Production
recursionScheme cata contextware algebra ast effects
```

`app` 阶段从 AST 收集 fact，沿 `EffectTheory` 展开 producer 依赖，检查 `uses` 的 send boundary 是否声明、当前 profile 是否有 implementation。检查通过后再进入 recursion model。

## Blueprint 结构

一个 blueprint 分成两块：

```haskell
data AppBlueprint = AppBlueprint
  { blueprintApp :: App
  , blueprintHanging :: AppHanging
  }
```

`app` 写主 workflow。

`hanging` 写外挂逻辑。它不属于主 workflow，不会被塞进 `chain` / `parallel` / `fallback` 里面。

## 节点分类

### WorkflowComponent

主执行流组件：

```haskell
chain
parallel
fact
wait
fallback
race
choice
```

`fact` 是 workflow 的叶子节点，用来声明当前位置给出的 fact。

```haskell
fact [UserKnownFact]
```

`wait` 表示当前分支等待某些 fact：

```haskell
wait [UserKnownFact] reportModule
```

fact 条件可以组合：

```haskell
wait
  (allOf [UserKnownFact, RuntimePreparedFact])
  reportModule
```

```haskell
wait
  (anyOf [UserKnownFact, ReportGeneratedFact])
  reportModule
```

`fallback` 只能写 workflow 分支：

```haskell
fallback [primaryWorkflow, backupWorkflow]
```

### HangingComponent

`hanging` 里放外挂节点：

```haskell
middleware
callback
suspense
loop
```

`middleware` 是效果叠加器。它接收一个 workflow body，本身挂在 `hanging` 里：

```haskell
middleware ReportMiddleware reportModule
```

含义：`reportModule` 整体叠加 `ReportMiddleware`。多层 middleware 按 `FreeMonoid` 组合；当前 interpreter 把它解释为顺序无关的效果集合。

`callback facts body`：当 facts 满足时，把 `body` 作为新的并行分支启动。

`suspense facts runningComponent`：当 facts 满足时，请求暂停或终止正在运行的 `runningComponent`。精确匹配需要后续 component registry。

`loop workflowComponent`：按 `forever` 语义重复执行一个 workflow component。retry、压测、次数控制由其他组件或 scheduler 表达。

```haskell
hooks :: AppHanging
hooks =
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

`middleware`、`callback`、`suspense` 和 `loop` 只属于 `hanging`，不能写进主 workflow。

## 插件化

业务组件放在 `src/Plugins/`。组件声明 AST 形状，并用 `-- plugin:` 注册到统一的 `Plugins` 出口。

标准插件文件包含模块声明、`Blueprint` 导入和插件声明：

```haskell
{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Payment where

import Blueprint

type PaymentModule = Wait

type PaymentHook = Middleware

-- plugin: paymentModule
paymentModule :: PaymentModule
paymentModule =
  wait
    [ UserKnownFact ]
    reportModule

-- plugin: paymentHook
paymentHook :: PaymentHook
paymentHook =
  middleware PaymentMiddleware paymentModule
```

如果插件里引用了其它插件，例如上面的 `reportModule`，构建前 `Setup.hs` 会自动维护 import 区块：

```haskell
-- plugin imports: begin
import Plugins.Report
-- plugin imports: end
```

这段区块由生成器管理。插件文件不要导入 `Plugins`，也不要手写 `Plugins.Dependencies.X` 或 `Plugins.Scope.X`。

`AST.AppBlueprint` 导入统一出口：

```haskell
import Blueprint
import Plugins
```

主 workflow 通过统一出口引用插件。

## Effect 声明

Effect 声明是可选治理层。只写 workflow 时不需要 effect；需要运行时闭包检查、profile implementation 或外部边界时，再写 effect unit。

没有前置依赖时，直接声明 fact：

```haskell
fact AppConfiguredFact
```

只有 fact 依赖时，只写 `needs`：

```haskell
fact AddCalculatedFact
  [ needs CalculationSectionOpenedFact
  ]
```

跨外部边界时声明出站能力：

```haskell
send GenerateReport ReportInput ReportOutput

fact ReportGeneratedFact
  [ needs AddCalculatedFact
  , needs FactorialCalculatedFact
  , needs SquaresCalculatedFact
  , uses GenerateReport
  ]
```

`needs` 指 fact 依赖，`uses` 指出站能力。只有被 `uses` 的 send boundary 需要在当前 profile 下有 implementation：

```haskell
profile Production
  [ implement GenerateReport RuntimeGenerateReport
  ]
```

入站事实用 `receive`：

```haskell
receive LoginRequestFact
```

`receive` 表示外界把 fact 给系统；`send` 表示系统可以调用外界能力。两者都是边界，但方向相反。

## 项目结构

```text
app/             当前入口、当前 AST、当前解释配置
src/AST/         前台 AST 蓝图和词汇
src/Effects/     effect theory、producer、send/receive boundary 和 profile 声明
src/Core/        DSL 核心结构、cata、插件出口和生成器产物
src/Interpreter/ 解释器 algebra 和 runtime
src/Plugins/     插件式业务组件
docs/            中文 DSL 使用说明
```

## TODO

后续路线已经单独整理到 [TODO.md](TODO.md)。

## 构建

```powershell
stack build
stack exec mytest
```

`stack exec mytest` 运行当前 interpreter 输出。临时查看 workflow run report，可以执行：

```powershell
stack exec ghc -- -package mytest -e "Interpreter.Runtime.WorkflowRunReport.printBlueprintRunReport AST.AppBlueprint.blueprint"
```

更多 AST 写法见 `docs/AST_SPEC.zh.md`。
