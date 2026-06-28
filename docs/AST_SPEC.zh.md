# AST DSL 使用说明

这份文档只说明前台 AST 怎么写，不解释背后的 free 结构、cata 或 runtime 实现。

## 1. 先看最终形状

主蓝图由 `app` 和 `hooks` 组成：

```haskell
blueprint :: AppBlueprint
blueprint =
  AppBlueprint
    { blueprintApp = app
    , blueprintHanging = hooks
    }
```

`app` 只写 workflow：

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

`hooks` 只写 hanging 外挂逻辑：

```haskell
hooks :: AppHanging
hooks =
  hanging
    [ middleware ReportMiddleware reportModule
    , callback [UserKnownFact] reportModule
    , suspense [ReportGeneratedFact] reportModule
    , loop reportModule
    ]
```

## 2. 节点类型

### WorkflowComponent

主执行流里的节点都属于 `WorkflowComponent`。

可用节点：

```haskell
chain
parallel
fact
wait
fallback
race
choice
```

### FactComponent

`FactComponent` 表示 fact 条件。

最简单的写法是一个 fact 或一组 fact：

```haskell
[UserKnownFact]
```

可以用 `allOf` 表示“全部满足”：

```haskell
allOf [UserKnownFact, RuntimePreparedFact]
```

可以用 `anyOf` 表示“任意满足”：

```haskell
anyOf [UserKnownFact, ReportGeneratedFact]
```

`wait`、`callback`、`suspense` 都接收 `FactComponent`。

### HangingComponent

`hanging` 里的节点属于 `HangingComponent`。

可用节点：

```haskell
middleware
callback
suspense
loop
```

`middleware`、`callback`、`suspense` 和 `loop` 不是 workflow 节点，不能写进 `chain`、`parallel`、`fallback`。

## 3. 各节点怎么看

### Chain

顺序结构：

```haskell
chain SomeFlow
  [ firstStep
  , secondStep
  ]
```

### Parallel

并行结构：

```haskell
parallel SomeFlow
  [ branchA
  , branchB
  ]
```

### Middleware

只属于 `hanging`。

效果叠加结构，表达 interceptor / middleware 视角：

```haskell
middleware SomeMiddleware body
```

`middleware` 接收一个 workflow body，但它本身挂在 `hanging` 里。读法是：`body` 这整个 workflow 都被叠加了这一层 middleware 效果。

```haskell
middleware ReportMiddleware
  (chain ReportFlow
    [ fact [CalculationSectionOpenedFact]
    , fact [ReportGeneratedFact]
    ])
```

这个节点可以按 monoid 来理解：

- 多层 middleware 可以继续叠加。
- 空 middleware 可以看成 identity。
- 叠加满足结合律，所以可以稳定组合。
- 当前 DSL 约定 middleware 是顺序无关的效果集合。
- 开发者只声明 body 叠加了哪些 middleware 效果，不依赖 middleware 的书写顺序。
- 底层 `FreeMonoid` 提供可组合的叠加骨架；顺序无关是 middleware interpreter 的语义约定。

### Fact

workflow 叶子节点，声明这里给出哪些 fact：

```haskell
fact [SomeFact]
```

### Wait

等待 fact 条件满足，然后继续执行 body：

```haskell
wait [SomeFact] body
```

组合条件：

```haskell
wait
  (allOf [UserKnownFact, RuntimePreparedFact])
  body
```

### Fallback

备用 workflow 分支：

```haskell
fallback [primaryWorkflow, backupWorkflow]
```

`fallback` 只能接收 workflow，不能接收 `middleware`、`callback`、`suspense` 或 fact 条件。

### Race

竞争分支：

```haskell
race [branchA, branchB]
```

### Choice

按 key 选择分支：

```haskell
choice
  (ChoiceKey "sms")
  [ (ChoiceKey "sms", smsBranch)
  , (ChoiceKey "email", emailBranch)
  ]
```

### Callback

只属于 `hanging`。

```haskell
callback [SomeFact] body
```

语义：当 fact 条件满足时，`body` 作为新的并行分支启动。

### Suspense

只属于 `hanging`。

```haskell
suspense [SomeFact] runningComponent
```

语义：当 fact 条件满足时，如果 `runningComponent` 正在运行，后续 runtime interpreter 可以 suspend 或 kill 它。

### Loop

只属于 `hanging`。

```haskell
loop workflowComponent
```

语义：`forever` 后面接一个 workflow component，并重复执行这个 workflow。retry、压测、次数控制等能力不属于 `loop` 节点本身，由 `fallback`、`middleware`、profile、测试 runner 或后续 scheduler 表达。

## 4. 新增插件流程

以下以新增 `Payment` 组件为例。

### 第一步：新建插件文件

新建：

```text
src/Plugins/Payment.hs
```

### 第二步：声明模块导出

```haskell
{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Plugins.Payment where

import Blueprint
```

### 第三步：写组件形状

组件类型说明这个组件最外层是什么节点。

如果最外层是 `wait`：

```haskell
type PaymentModule = Wait
```

如果这个组件还要叠加 middleware，就再写一个 hanging hook 类型：

```haskell
type PaymentHook = Middleware
```

完整示例：

```haskell
type PaymentModule = Wait

type PaymentHook = Middleware

-- plugin: paymentModule
paymentModule :: PaymentModule
paymentModule =
  wait
    [ PaymentConfirmedFact ]
    ( chain PaymentFlow
        [ fact [PaymentCheckedFact]
        , fact [PaymentFinishedFact]
        ]
    )

-- plugin: paymentHook
paymentHook :: PaymentHook
paymentHook =
  middleware PaymentMiddleware paymentModule
```

这个组件读法是：

- `paymentModule` 是一个 `Wait` workflow component。
- 它等待 `PaymentConfirmedFact`。
- fact 满足后进入 `PaymentFlow`。
- `PaymentFlow` 里声明两个 fact。
- `paymentHook` 是 hanging component。
- 它声明 `paymentModule` 整体叠加 `PaymentMiddleware`。

### 第四步：注册插件出口

分别在组件上方写：

```haskell
-- plugin: paymentModule
-- plugin: paymentHook
```

构建时 `Setup.hs` 会扫描这个声明，并生成统一出口：

```text
src/Core/Plugins.hs
```

如果新增了 `src/Plugins/Payment.hs` 文件，还需要把模块名加入 `mytest.cabal` 的 `exposed-modules`：

```cabal
                     , Plugins.Payment
```

### 第五步：插入 main workflow

打开：

```text
src/AST/AppBlueprint.hs
```

文件头保持统一入口：

```haskell
import Blueprint
import Plugins
```

然后直接插入：

```haskell
app :: App
app =
  chain AppFlow
    [ lifecycleStart
    , userModule
    , paymentModule
    , reportModule
    , lifecycleEnd
    ]

hooks :: AppHanging
hooks =
  hanging
    [ paymentHook
    ]
```

`AST.AppBlueprint` 不需要单独导入 `Plugins.Payment`，因为 `Plugins` 已经统一导出注册过的插件。

## 5. 不要在 AST 里写实现

AST 只描述结构，不写执行实现。

不要在组件里写：

- IO
- 数据库查询
- HTTP 请求
- 文件读写
- 真实日志逻辑
- handler 查找
- service 注入
- runtime state 修改

这些以后交给 interpreter。
