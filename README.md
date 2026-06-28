# dsl设计模式

这是一个 Haskell 架构 demo。项目目标不是先写执行细节，而是把应用架构写成一棵可以左键跳转、可以插件化组装的 AST eDSL。

## 文档引用

DSL 前台写法和插件扩展流程见：[AST DSL 使用说明](docs/AST_SPEC.zh.md)。

## 核心思想

前台代码只描述结构，复杂实现藏在 `src/Core/` 和 `src/Interpreter/`。

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

开发时点进 `userModule`、`reportModule`，看到的仍然是 DSL 节点，而不是一坨执行实现。这就是本项目里的“代码即文档”。

## 运行入口

`app/Main.hs` 是当前程序装配页：

```haskell
main :: IO ()
main =
  currentInterpreter currentAst
```

`currentAst` 单独放在 `app/CurrentAst.hs`，只负责给出当前业务 AST：

```haskell
currentAst :: AppBlueprint
currentAst =
  blueprint
```

`currentInterpreter` 单独放在 `app/InterpretConfig.hs`，只负责给出当前解释配置：

```haskell
interpretConfig :: InterpretConfig
interpretConfig =
  InterpretConfig
    { interpretRecursionModel = cataModel
    , interpretContextware = contextware
    , interpretFAlgebra = fAlgebra
    }
```

这样从 `main` 左键进去，可以分别看到当前 AST 和当前 interpreter 配置；继续点进去，才进入抽象的 recursion model、contextware 和 f-algebra。

## Blueprint 结构

一个 blueprint 分成两块：

```haskell
data AppBlueprint = AppBlueprint
  { blueprintApp :: App
  , blueprintHanging :: AppHanging
  }
```

`app` 只写主 workflow。

`hanging` 写外挂逻辑。它不属于主 workflow，不会被塞进 `chain` / `parallel` / `fallback` 里面。

## 节点分类

### WorkflowComponent

主执行流组件，可以写：

```haskell
chain
parallel
fact
wait
fallback
race
choice
```

`fact` 是 workflow 的叶子节点。当前 AST 里没有 `effect`；我们只声明“这个位置给出了哪些 fact”。

```haskell
fact [UserKnownFact]
```

`wait` 也是 workflow 节点。它表示当前分支等待某些 fact 出现：

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

`hanging` 里面放外挂节点：

```haskell
middleware
callback
suspense
loop
```

`middleware` 是效果叠加器。它接收一个 workflow body，但它本身挂在 `hanging` 里：

```haskell
middleware ReportMiddleware reportModule
```

读法是：`reportModule` 这整个 workflow 被叠加了 `ReportMiddleware` 效果。这个视角符合 monoid：多层 middleware 可以继续叠加，空 middleware 可以看成 identity，叠加满足结合律。当前 DSL 进一步把 middleware 看成顺序无关的效果集合：开发者只声明“这个 workflow 叠加了哪些 middleware 效果”，不依赖 middleware 的书写顺序。底层 `FreeMonoid` 提供的是可组合的叠加骨架；顺序无关是 middleware interpreter 的语义约定。

`callback facts body` 表示：当 facts 满足时，把 `body` 作为新的并行分支启动。

`suspense facts runningComponent` 表示：当 facts 满足时，如果 `runningComponent` 正在运行，后续 runtime interpreter 可以 suspend 或 kill 它。

`loop workflowComponent` 表示：`forever` 后面接一个 workflow component，并重复执行这个 workflow。retry、压测、次数控制等能力不属于 `loop` 节点本身，由 `fallback`、`middleware`、profile、测试 runner 或后续 scheduler 表达。

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

`middleware`、`callback`、`suspense` 和 `loop` 不能成为 workflow component。它们只属于 `hanging`。

## 插件化

业务组件放在 `src/Plugins/`。组件只声明 AST 形状，并用 `-- plugin:` 注册到统一的 `Plugins` 出口。

标准插件文件只需要写模块名、`Blueprint` 和插件声明：

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

这段区块由生成器管理，不需要手写。开发插件时不要导入 `Plugins`，也不要手写 `Plugins.Dependencies.X` 或 `Plugins.Scope.X`。

`AST.AppBlueprint` 只需要导入：

```haskell
import Blueprint
import Plugins
```

这样主 workflow 不直接依赖具体插件文件。

## 项目结构

```text
app/             当前入口、当前 AST、当前解释配置
src/AST/         前台 AST 蓝图和词汇
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

`stack exec mytest` 运行当前代码即文档视图。临时查看 runtime 控制流和 middleware 效果，可以执行：

```powershell
stack exec ghc -- -package mytest -e "Interpreter.Runtime.runBlueprint AST.AppBlueprint.blueprint"
```

更多 AST 写法见 `docs/AST_SPEC.zh.md`。
