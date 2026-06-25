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

## Blueprint 结构

一个 blueprint 分成两块：

```haskell
data AppBlueprint = AppBlueprint
  { blueprintApp :: App
  , blueprintHanging :: AppHanging
  }
```

`app` 只写主 workflow。

`hanging` 只写外挂 hook。它不属于主 workflow，不会被塞进 `chain` / `parallel` / `fallback` 里面。

## 节点分类

### WorkflowComponent

主执行流组件，可以写：

```haskell
chain
parallel
middleware
fact
wait
fallback
race
choice
```

`middleware` 是效果叠加器。它把一个 workflow 包起来，表示被包住的所有子组件都会叠加这一层 middleware 效果：

```haskell
middleware ReportMiddleware reportModule
```

这个视角符合 monoid：多层 middleware 可以继续叠加，空 middleware 可以看成 identity，叠加满足结合律。当前 DSL 进一步把 middleware 看成顺序无关的效果集合：开发者只声明“这个 workflow 叠加了哪些 middleware 效果”，不依赖 middleware 的书写顺序。底层 `FreeMonoid` 提供的是可组合的叠加骨架；顺序无关是我们给 middleware interpreter 约定的语义。

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

`hanging` 里面只放 hook：

```haskell
callback
suspense
```

`callback facts body` 表示：当 facts 满足时，把 `body` 作为新的并行分支启动。

`suspense facts runningComponent` 表示：当 facts 满足时，如果 `runningComponent` 正在运行，后续 runtime interpreter 可以 suspend 或 kill 它。

```haskell
hooks :: AppHanging
hooks =
  hanging
    [ callback
        (allOf [UserKnownFact, RuntimePreparedFact])
        reportModule
    , suspense
        (anyOf [UserKnownFact, ReportGeneratedFact])
        reportModule
    ]
```

`callback` 和 `suspense` 不能成为 workflow component。它们只属于 `hanging`。

## 插件化

业务组件放在 `src/Plugins/`。组件只声明 AST 形状，并用 `-- plugin:` 注册到统一的 `Plugins` 出口。

`AST.AppBlueprint` 只需要导入：

```haskell
import Blueprint
import Plugins
```

这样主 workflow 不直接依赖具体插件文件。

## 项目结构

```text
app/             可执行入口
src/AST/         前台 AST 蓝图和词汇
src/Core/        DSL 核心结构、cata、插件出口
src/Interpreter/ 解释器 algebra 和 runtime
src/Plugins/     插件式业务组件
docs/            中文 DSL 使用说明
```

## TODO

### Fact 自动生产

`require` 不再作为 AST 节点存在。后续 interpreter/cata 可以按工厂模式维护 fact 依赖：

- runtime 已有 fact 时直接复用。
- runtime 没有 fact 时，沿依赖链生产前置 fact。
- 前置 fact 还有依赖时，沿树路径继续展开。
- 不能主动生产的外部事件，前台显式写 `wait facts body`。

### First-Class Component Graph

插件组件可以作为 AST 值被引用、传递和组合，所以前台看起来像 tree，插件系统里实际可能升级成 workflow graph。

组件之间可能互相引用，甚至自引用：

```haskell
pluginA =
  chain A [pluginB]

pluginB =
  chain B [pluginA]
```

这种结构不一定非法。它可能表达常驻服务、event loop、subscription loop 或 retry loop。后续 cata/interpreter 需要处理 component identity、cycle 检测、guarded cycle、graph-aware cata，以及边 fold 边解释的 `interpretM`。

## 构建

```powershell
stack build
stack exec mytest
```

更多 AST 写法见 `docs/AST_SPEC.zh.md`。
