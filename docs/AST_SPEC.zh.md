# AST DSL 使用说明

前台 AST 写法规格。free 结构、cata 和 runtime 实现属于 core/interpreter。

## 1. 蓝图形状

主蓝图由 `app` 和 `hooks` 组成：

```haskell
blueprint :: AppBlueprint
blueprint =
  AppBlueprint
    { blueprintApp = app
    , blueprintHanging = hooks
    }
```

`app` 写 workflow：

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

`hooks` 写 hanging 外挂逻辑：

```haskell
hooks :: AppHanging
hooks =
  hanging
    [ middleware ReportMiddleware reportModule
    , callback ShutdownFlow reportModule
    , suspense ReportModuleFlow
    , loop reportModule
    ]
```

## 2. 节点类型

### WorkflowComponent

主执行流节点属于 `WorkflowComponent`。

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

基本写法：

```haskell
[UserKnownFact]
```

`allOf` 表示全部满足：

```haskell
allOf [UserKnownFact, RuntimePreparedFact]
```

`anyOf` 表示任意满足：

```haskell
anyOf [UserKnownFact, ReportGeneratedFact]
```

`wait` 接收 `FactComponent`。`callback` 和 `suspense` 接收 workflow target。

### HangingComponent

`hanging` 里的节点属于 `HangingComponent`。

可用节点：

```haskell
middleware
callback
suspense
loop
```

`middleware`、`callback`、`suspense` 和 `loop` 属于 `hanging`，不能写进 `chain`、`parallel`、`fallback`。

## 3. 节点语义

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

作用域：`hanging`。

结构：

```haskell
middleware SomeMiddleware body
```

语义：给 workflow body 叠加 middleware。

```haskell
middleware ReportMiddleware
  (chain ReportFlow
    [ fact [CalculationSectionOpenedFact]
    , fact [ReportGeneratedFact]
    ])
```

组合规则：

- 多层 middleware 支持叠加。
- 空 middleware 为 identity。
- 叠加满足结合律。
- runtime 在执行 body 前把 middleware 放入 active stack，body 结束后退出。
- middleware enter/exit 留下结构化 runtime event；target 失败时也退出 stack。
- middleware 只包住声明中的 body。主 workflow component identity 改写由 scheduler/registry 处理。
- `FreeMonoid` 提供组合结构，顺序语义由 interpreter 决定。

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

作用域：`hanging`。

```haskell
callback SomeFlow body
```

语义：运行进入 `SomeFlow` 时，`body` 作为并行分支启动。

### Suspense

作用域：`hanging`。

```haskell
suspense SomeFlow
```

语义：记录对 `SomeFlow` 的暂停请求和当前状态。当前版本不执行真实取消。

### Loop

作用域：`hanging`。

```haskell
loop workflowComponent
```

语义：按 `forever` 重复执行一个 workflow component。retry、压测、次数控制由其他组件或 scheduler 表达。

## 4. 新增插件流程

示例：新增 `Payment` 组件。

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

组件类型标记最外层节点。

最外层为 `wait`：

```haskell
type PaymentModule = Wait
```

middleware hook：

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

结构说明：

- `paymentModule` 是一个 `Wait` workflow component。
- 它等待 `PaymentConfirmedFact`。
- fact 满足后进入 `PaymentFlow`。
- `PaymentFlow` 里声明两个 fact。
- `paymentHook` 是 hanging component，声明 `paymentModule` 整体叠加 `PaymentMiddleware`。

### 第四步：注册插件出口

在需要导出的定义上方写：

```haskell
-- plugin: paymentModule
-- plugin: paymentHook
```

构建时 `Setup.hs` 会扫描这个声明，并生成统一出口：

```text
src/Core/Plugins.hs
```

新增 `src/Plugins/Payment.hs` 后，把模块名加入 `mytest.cabal` 的 `exposed-modules`：

```cabal
                     , Plugins.Payment
```

### 第五步：插入 main workflow

打开：

```text
src/AST/AppBlueprint.hs
```

文件头导入统一入口：

```haskell
import Blueprint
import Plugins
```

插入 workflow 和 hook：

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

`AST.AppBlueprint` 通过 `Plugins` 统一出口引用插件。

## 5. AST 只写结构

组件里不写：

- IO
- 数据库查询
- HTTP 请求
- 文件读写
- 真实日志逻辑
- implementation 查找
- service 注入
- runtime state 修改

这些由 interpreter 或后续 effect system 处理。
