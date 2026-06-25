# AST 树构建流程

本文档只讲一件事：开发者如何把一个新组件接入当前 AST 树。

整个流程分三步：

1. 注册插件
2. 写节点形状
3. 插入 main workflow

## 第一步：注册插件

注册插件的目的是把组件统一导出到 `Plugins`。

注册后，使用方只需要：

```haskell
import Plugins
```

即可使用所有注册过的组件。

以下以新增 `Payment` 模块为例。

### 演示目标

目标是在 `AppBlueprint.app` 中插入 `paymentModule`：

```haskell
app :: App
app =
  chain AppFlow
    [ lifecycleStart
    , userModule
    , paymentModule      -- 新增：直接插入 Payment 插件组件
    , reportModule
    , lifecycleEnd
    ]
```

### 注册流程

#### 1.1 新建插件模块文件

先新建文件：

```text
src/Payment.hs
```

#### 1.2 写插件模块导出

```haskell
module Payment
  ( PaymentModule
  , paymentModule
  ) where

import Blueprint          -- 新增：导入 AST DSL
```

这一段只负责说明 `Payment` 模块对外暴露什么：

- `module Payment ... where`：这个文件声明为 `Payment` 模块。
- `PaymentModule`：对外导出支付组件的类型别名。
- `paymentModule`：对外导出真正可插入 AST 的组件。
- `import Blueprint`：获得 `Chain / Callback / chain / callback / effect / middleware` 等 DSL。

#### 1.3 在模块里写插件组件

```haskell
type PaymentModule = Callback -- 新增：声明支付模块是 Callback 组件

-- plugin: paymentModule      -- 新增：声明 paymentModule 是插件出口
paymentModule :: PaymentModule
paymentModule =
  callback
    [ UserKnownFact ]          -- 拿到这个 fact 后继续执行
    ( middleware
        PaymentMiddleware      -- middleware 标签
        ( chain PaymentFlow
            [ effect [PaymentCheckedFact]
            , effect [PaymentFinishedFact]
            ]
        )
    )
```

上面这个组件已经是一个合法 AST 组件。

`-- plugin: paymentModule` 是给自动构建器看的声明。

它表示：

```text
Payment.paymentModule 要进入全局 Plugins 出口
```

#### 1.4 在 `mytest.cabal` 中登记新模块

如果 `Payment.hs` 是新文件，需要把模块名加入 `mytest.cabal` 的 `exposed-modules`。

添加位置：

```cabal
library
  exposed-modules:     Architecture
                     , AppBlueprint
                     , Blueprint
                     , Boot
                     , Configuration
                     , Payment        -- 新增：登记 Payment 模块
                     , Plugins
                     , Report
                     , Shutdown
```

新增位置就是这一行：

```cabal
, Payment        -- 新增：登记 Payment 模块
```

#### 1.5 自动构建器生成 `Plugins.hs`

项目构建时，`Setup.hs` 会扫描源码里的插件声明：

```haskell
-- plugin: paymentModule
```

然后自动生成：

```text
src/Plugins.hs
```

生成结果类似：

```haskell
module Plugins
  where

import qualified Payment

paymentModule = Payment.paymentModule
```

所以使用方导入 `Plugins` 后，可以直接使用：

```haskell
paymentModule
```

#### 1.6 在 `AppBlueprint.app` 使用插件

打开：

```text
src/AppBlueprint.hs
```

文件头已经有：

```haskell
import Blueprint
import Plugins
```

直接把 `paymentModule` 插入 main workflow：

```haskell
app :: App
app =
  chain AppFlow
    [ lifecycleStart
    , userModule
    , paymentModule         -- 新增：插入 Payment 插件
    , reportModule
    , lifecycleEnd
    ]
```

#### 1.7 注册后的依赖对比

注册完成后，`AppBlueprint` 只保留统一入口依赖：

```haskell
import Blueprint
import Plugins
```

`AppBlueprint` 不需要直接导入具体插件模块：

```haskell
import Payment
```

原因是 `Payment` 的组件已经由 `Plugins` 统一导出。

#### 1.8 这套注册流程说明什么

- `Payment` 仍写在自己的模块里。
- `Payment.hs` 负责定义插件组件。
- `-- plugin: paymentModule` 负责声明插件出口。
- `Setup.hs` 负责扫描插件声明并生成 `Plugins.hs`。
- `AppBlueprint.hs` 只需要 `import Plugins`。

当前流程是：

```text
新增 Payment.hs
-> 在 Payment.hs 写 -- plugin: paymentModule
-> 在 mytest.cabal 加 Payment
-> 构建时自动生成 Plugins.hs
-> 在 AppBlueprint.app 插入 paymentModule
```

这样注册表保持显式，可读，可审查。

## 第二步：写节点形状

组件本身要写成 AST 节点形状。

组件签名必须直接使用这八种类型之一。

目前这些节点类型首先是一套 AST 书写规范。

也就是说，`Chain / Parallel / Middleware / Effect / Callback / Fallback / Race / Choice` 的作用是让开发者在 AST 前台直接看懂一个组件的最外层形状。

当前规则是：

```text
组件类型签名 = 这个组件暴露给外部时的最外层节点类型
```

当前 `Blueprint` 前台公开的节点类型可以理解为：

```haskell
type Component = Workflow WorkflowFact Interceptor

type Chain = Component
type Parallel = Component
type Middleware = Component
type Effect = Component
type Callback = Component
type Fallback = Component
type Race = Component
type Choice = Component
```

所以这些名字目前不是强类型证明，而是 AST DSL 的前台规范。

节点的语义由两部分共同决定：

```text
类型签名 + 最外层构造函数
```

例如：

```haskell
type PaymentModule = Callback

paymentModule :: PaymentModule
paymentModule =
  callback
    [ UserKnownFact ]
    paymentFlow
```

这表示 `paymentModule` 暴露出来的最外层节点是 `callback`。

如果一个组件写成：

```haskell
type PaymentModule = Parallel
```

那么它的定义最外层就应该是：

```haskell
paymentModule =
  parallel PaymentFlow [...]
```

这条规则先作为 DSL 规范存在。以后可以由自动构建器或检查器进一步验证。

### 节点类型清单

#### `Chain`

```haskell
type SomeModule = Chain

someModule :: SomeModule
someModule =
  chain SomeFlow
    [ firstStep
    , secondStep
    , thirdStep
    ]
```

`Chain` 表示顺序结构。

我们的看法是：`Chain` 用来描述“这些事情必须按这个顺序出现”。它适合表达启动流程、业务步骤、收尾流程等有先后关系的结构。

#### `Parallel`

```haskell
type SomeModule = Parallel

someModule :: SomeModule
someModule =
  parallel SomeFlow
    [ branchA
    , branchB
    , branchC
    ]
```

`Parallel` 表示并列结构。

我们的看法是：`Parallel` 用来描述“这些分支在结构上互相独立”。它不承诺一定真的开线程并发执行，但它告诉 interpreter：这些分支没有书写顺序上的依赖。

#### `Middleware`

```haskell
type SomeModule = Middleware

someModule :: SomeModule
someModule =
  middleware SomeMiddleware body
```

`Middleware` 表示包装结构。

我们的看法是：`Middleware` 用来描述横切逻辑，例如日志、拦截、前后置动作、监控等。它不是业务主流程本身，而是包在一个 workflow 外面的结构。

#### `Effect`

```haskell
type SomeModule = Effect

someModule :: SomeModule
someModule =
  effect [SomeFact]
```

`Effect` 表示最小动作节点。

我们的看法是：`Effect` 是 AST 递归到底之后的叶子节点。AST 不在这里写 IO 或实现，只声明“这里产生或代表哪些 fact”。真正怎么执行，交给 interpreter。

#### `Callback`

```haskell
type SomeModule = Callback

someModule :: SomeModule
someModule =
  callback
    [ SomeReadyFact ]
    body
```

`Callback` 表示拿到某些 fact 后继续执行后面的 workflow。

我们的看法是：`Callback` 是 workflow 节点。它表达的是一种 continuation 视角：某些条件已经被给出，然后进入后续结构。

`Callback` 不等于静态依赖注册。静态依赖检查可以由构建器或检查器完成，但不应该再伪装成 AST 里的 `Require` 节点。

#### `Fallback`

```haskell
type SomeModule = Fallback

someModule :: SomeModule
someModule =
  fallback
    [ primaryBranch
    , backupBranch
    , lastBranch
    ]
```

`Fallback` 表示备用分支。

我们的看法是：`Fallback` 用来描述“优先尝试前面的分支，不行再尝试后面的分支”。它适合表达降级策略、备选流程、容错路径。

#### `Race`

```haskell
type SomeModule = Race

someModule :: SomeModule
someModule =
  race
    [ branchA
    , branchB
    ]
```

`Race` 表示竞争分支。

我们的看法是：`Race` 用来描述“多个分支竞争出一个结果”。AST 只说明存在竞争关系，具体怎么判断胜出由 interpreter 决定。

#### `Choice`

```haskell
type SomeModule = Choice

someModule :: SomeModule
someModule =
  choice
    (ChoiceKey "sms")
    [ (ChoiceKey "sms", smsBranch)
    , (ChoiceKey "email", emailBranch)
    ]
```

`Choice` 表示按 key 选择分支。

我们的看法是：`Choice` 用来描述“根据某个选择进入对应分支”。它适合表达配置选择、用户选择、策略选择。

### 组件文件模板

例如新增 `Payment.hs`：

```haskell
module Payment
  ( PaymentModule
  , paymentModule
  ) where

import Blueprint

type PaymentModule = Callback

-- plugin: paymentModule
paymentModule :: PaymentModule
paymentModule =
  callback
    [ UserKnownFact
    ]
    ( middleware
        PaymentMiddleware
        ( chain PaymentFlow
            [ effect [PaymentCheckedFact]
            , effect [PaymentFinishedFact]
            ]
        )
    )
```

这段代码可以直接读成：

> `paymentModule` 是一个 `Callback` 组件。  
> 它拿到 `UserKnownFact` 后继续。  
> 它挂了 `PaymentMiddleware`。  
> 它内部是 `PaymentFlow` 顺序流程。  
> 顺序是支付检查，然后支付完成。

### 写节点前要补哪些名字

如果组件里用了新的 workflow 名字，要在：

```text
src/AST/Names.hs
```

添加：

```haskell
data WorkflowName
  = ...
  | PaymentFlow
```

如果组件里用了新的 fact，要在：

```text
src/AST/Facts.hs
```

添加：

```haskell
data WorkflowFact
  = ...
  | PaymentCheckedFact
  | PaymentFinishedFact
```

如果组件里用了新的 middleware 标签，要在：

```text
src/AST/Interceptors.hs
```

添加：

```haskell
data Interceptor
  = ...
  | PaymentMiddleware
```

### 当前项目里的例子

`Report.hs`：

```haskell
type ReportModule = Parallel

reportModule :: ReportModule
reportModule =
  parallel ReportModuleFlow
    [ calculationReport
    ]
```

读法：

> `reportModule` 是一个并列组件，里面挂了 `calculationReport`。

`calculationReport`：

```haskell
type CalculationReport = Callback

calculationReport :: CalculationReport
calculationReport =
  callback
    [ UserKnownFact
    ]
    ( middleware
        ReportMiddleware
        ( chain CalculationReportFlow
            [ effect [CalculationSectionOpenedFact]
            , parallel CalculationsFlow
                [ effect [AddCalculatedFact]
                , effect [FactorialCalculatedFact]
                , effect [SquaresCalculatedFact]
                ]
            , effect [ReportGeneratedFact]
            ]
        )
    )
```

读法：

> 生成计算报告需要用户已知。  
> 整段报告流程挂了 `ReportMiddleware`。  
> 报告流程按顺序执行：打开计算区域，并列计算，生成报告。

## 第三步：插入 main workflow

main workflow 在：

```text
src/AppBlueprint.hs
```

入口名字保留为：

```haskell
app :: App
app =
  ...
```

当前写法：

```haskell
module AppBlueprint
  ( App
  , app
  ) where

import Blueprint
import Plugins

type App = Chain

app :: App
app =
  chain AppFlow
    [ lifecycleStart
    , userModule
    , reportModule
    , lifecycleEnd
    , abc
    , foo1
    , foo2
    , foo3
    , foo4
    , foo5
    , foo6
    ]
```

如果新增了 `paymentModule`，并且已经注册到 `Plugins`，可直接插入：

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
```

`AppBlueprint` 不需要单独导入：

```haskell
import Payment
```

因为 `Setup.hs` 会根据 `-- plugin: paymentModule` 生成 `Plugins` 出口。

## 完整新增组件流程

新增一个组件时，按这个顺序做：

1. 在 `AST.Names` 添加 workflow 名字。
2. 在 `AST.Facts` 添加需要声明或依赖的 fact。
3. 如需要，在 `AST.Interceptors` 添加 middleware 标签。
4. 新建组件模块，用 `Chain / Parallel / Middleware / Effect / Callback / Fallback / Race / Choice` 写清楚节点形状。
5. 在组件模块里写 `-- plugin: paymentModule`。
6. 如果是新文件，在 `mytest.cabal` 里登记模块。
7. 构建时由 `Setup.hs` 生成 `Plugins.hs`。
8. 在 `AppBlueprint.app` 的 main workflow 里插入组件。

## 合法组件检查

一个组件能被插入其它组件，至少要满足：

- 它是顶层定义。
- 它有明确类型签名，例如 `paymentModule :: Callback`。
- 它使用 AST DSL 构建。
- 它所在模块导出了这个组件。
- 它上方或附近有 `-- plugin: paymentModule` 插件声明。

例如：

```haskell
-- plugin: paymentModule
paymentModule :: Callback
paymentModule =
  callback
    [ UserKnownFact ]
    ( middleware
        PaymentMiddleware
        ( chain PaymentFlow
            [ effect [PaymentCheckedFact]
            , effect [PaymentFinishedFact]
            ]
        )
    )
```

## 不要在 AST 里写实现

AST 只描述结构，不写实现。

不要在组件里写：

- IO
- 数据库查询
- HTTP 请求
- 文件读写
- 真实日志逻辑
- 复杂业务计算
- handler 查找
- service 注入
- runtime state 修改

这些以后交给 interpreter。

## 一句话总结

构建 AST 树就是三步：

```text
注册插件 -> 写节点形状 -> 插入 main workflow
```

也就是：

```text
Setup.hs 扫描插件声明
Setup.hs 生成 Plugins.hs
组件模块描述结构
AppBlueprint.app 组装整棵树
```

## 附录：`Blueprint` 提供什么

`Blueprint` 是前台 AST DSL 入口。

它只负责提供写组件需要的接口，不负责插件注册，也不负责执行。

### 组件类型

组件签名使用这些类型：

```haskell
Chain
Parallel
Middleware
Effect
Callback
Fallback
Race
Choice
```

示例：

```haskell
app :: Chain
userModule :: Parallel
paymentModule :: Callback
```

### 构造函数

组件内容使用这些函数构建：

```haskell
chain
parallel
middleware
effect
callback
fallback
race
choice
```

示例：

```haskell
paymentModule :: Callback
paymentModule =
  callback
    [ UserKnownFact ]
    ( middleware
        PaymentMiddleware
        ( chain PaymentFlow
            [ effect [PaymentCheckedFact]
            , effect [PaymentFinishedFact]
            ]
        )
    )
```

### 词汇表

组件里使用的 workflow 名称、fact、中间件标签也从 `Blueprint` 入口获得：

```haskell
WorkflowName
WorkflowFact
Interceptor
ChoiceKey
```

示例：

```haskell
PaymentFlow
UserKnownFact
PaymentMiddleware
ChoiceKey "sms"
```

### 边界

`Blueprint` 的职责：

- 提供 AST 组件类型。
- 提供 AST 构造函数。
- 提供 AST 词汇表。

`Blueprint` 不负责：

- 插件注册。
- 自动生成 `Plugins.hs`。
- 解释执行 AST。
- IO、数据库、HTTP、日志等实现细节。
