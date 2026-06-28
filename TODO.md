# TODO

本文档记录项目下一阶段的架构路线。README 只保留项目概览，具体实施顺序以本文档为准。

## 当前路线结论

先完成 workflow 控制流，但只写到抽象接口层；再定义 fact/effect 边界；最后实现完整 effect system。

- `AppBlueprint` 描述“程序怎么走”：顺序、并发、分支、等待、回调、循环和 hanging 外挂节点。
- workflow 可以用 effectful carrier 运行，但 workflow 本身不是业务 effect system。
- workflow 遇到 `fact` 叶子时，只调用抽象 fact/effect 边界，不直接写 IO、数据库、日志、HTTP 或 mock。
- `EffectTheory` 负责“事实从哪里来”：producer、operation signature、handler、profile、失败策略和校验。
- 因此当前实施顺序是：`WorkflowModel` -> `FactBoundary` -> `EffectTheory` -> recursion scheme 扩展。

## 1. 定义递归边界 / Eliminator 形状

### 目标

先明确 AST 被解释时的递归边界，确定 `cata` 或等价 eliminator 需要暴露什么类型形状。

### 背景约束

- AST 前台只负责描述 workflow 结构。
- 递归层只负责进入 AST、递归子结构、组合递归结果。
- 递归层不负责具体 fact 的业务副作用。
- 当前阶段可以继续使用 `cata`，但需要把它视为可替换的 recursion scheme 之一。
- 后续可以根据 graph、loop、外部 seed 等需求替换为 `para / zygo / histo / hylo / graph-aware fold`。

### 输出物

- 明确 `Workflow` 被 fold 成什么 carrier/result。
- 明确 workflow 节点递归后的结果如何传给中间层。
- 明确 fact 叶子节点在递归边界处需要暴露什么接口。
- 保留当前 `cataWorkflow` 作为最小 eliminator 实现。
- 避免在递归层写入具体业务 effect 逻辑。

## 2. 定义 Workflow 控制流模型

### 前置条件

完成递归边界 / eliminator 形状设计。

### 目标

将 workflow 控制流语义从业务 effect handler 中解耦出来，形成独立的 `WorkflowModel` 或 `WorkflowSemantics`。

这一阶段优先实现控制流结构本身，但不实现真实业务副作用。控制流只决定如何进入 AST、如何组合分支、如何调度子 workflow；具体 fact 的生产留给后续 fact/effect 边界和 `EffectTheory`。

### 控制流语义

- `chain`：对应 free monad，表示顺序进入。
- `parallel`：对应 free applicative，表示并列或并行进入。
- `middleware`：对应 free monoid，表示顺序无关的效果叠加集合；作为 hanging 节点接收一个 workflow component。
- `fallback`：对应 alternative，表示备用分支。
- `race`：对应 alternative，表示竞争分支。
- `choice`：表示按 key 选择分支。
- `callback`：对应 continuation / async hook。
- `suspense`：对应外部挂载的控制 hook。
- `loop`：对应 `forever`，作为 hanging 节点接收一个 workflow component，并重复执行这个 workflow；retry、压测、次数控制等能力由其他组件表达。
- `wait`：对应 fact gate，不主动生产 fact。

### 输出物

- 定义 `WorkflowModel` 或 `WorkflowSemantics`。
- 明确 workflow 控制流如何组合递归结果。
- 明确 workflow 控制流如何调用 fact 叶子接口。
- 为 `fact` 叶子预留抽象接口，例如 `askFact` / `produceFact` / `runFactBoundary`。
- 确保业务层只解释 fact，不解释 workflow 控制结构。
- 确保 `hanging` 只包含 `middleware / callback / suspense / loop`，不进入主 workflow。
- 确保 `fallback` 只接收 workflow component，不接收 hanging component 或 fact condition。
- 为控制流模型实现最小运行时 demo；demo 可以使用 mock/render carrier，不接入真实 effect system。

## 3. 定义 Fact / Effect Boundary

### 前置条件

完成 Workflow 控制流模型的最小运行语义。

### 目标

在 workflow 和 effect system 之间定义一个稳定边界。workflow 不知道某个 fact 由谁生产，也不知道 handler 怎么运行；它只知道“我现在需要这个 fact 被给出”。

概念方向：

```haskell
onFact :: Fact -> carrier FactResult
```

或：

```haskell
produceFact :: Fact -> carrier FactResult
```

这一步不是完整 effect system，只是把 workflow 的叶子节点从当前 runtime/render 里抽象出来。

### 边界规则

- `fact` 是 workflow 的叶子节点。
- workflow 控制流只调用 fact 边界，不直接生产真实业务 fact。
- `wait` 仍然表示 fact gate：它检查 fact 条件，不主动生产 fact。
- fact 边界可以先有多个简单实现：render、smoke test、mock runtime。
- 后续 `EffectTheory` 会成为 fact 边界的正式实现来源。

### 输出物

- 定义 `FactBoundary`、`FactAlgebra` 或同等概念。
- 明确 `fact` 叶子的统一调用形状。
- 让 runtime/render/check carrier 都通过同一个 fact 边界处理 fact。
- 避免 `recordFact` 这种实现细节直接成为架构语义。
- 为后续 `EffectTheory` 接入保留稳定接口。

### 3.1 用户新建 Effect 单元的标准动作

这一步描述生产程序员在这套架构里新增一个规范 effect 单元时，预期要写哪些前台声明。这里先定义用户面对的工作量；具体类型、校验和 handler 实现放到后续 `EffectTheory` 章节。

如果用户只是拼装模块流程，只需要写 `AppBlueprint`：

```haskell
paymentModule =
  wait [UserKnownFact] $
    chain PaymentFlow
      [ fact [PaymentRequestedFact]
      , fact [PaymentFinishedFact]
      ]
```

如果用户要让 `PaymentFinishedFact` 真正可被生产，就需要进入 effect system，并完成以下声明。

1. 声明模块对外给出的 fact

```haskell
PaymentRequestedFact
PaymentFinishedFact
PaymentFailedFact
```

这些 fact 是 workflow 能看见的公共语义，不包含 IO、数据库、HTTP 或 mock。

2. 声明 effect operation signature

```haskell
ChargePayment :: PaymentRequest -> PaymentEffect PaymentResult
QueryPayment  :: PaymentId -> PaymentEffect PaymentStatus
```

这一步只描述需要什么外部能力，以及每个 operation 的输入和输出。

3. 声明 fact producer

```haskell
producer PaymentFinishedFact
  [ needs UserKnownFact
  , needs PaymentRequestedFact
  , uses ChargePayment
  , onFailure PaymentFailedFact
  ]
```

producer 必须回答：

- 谁生产这个 fact？
- 生产前依赖哪些 fact？
- 生产时使用哪些 effect operation？
- 生产失败时给出什么失败 fact 或失败策略？

4. 为 profile 声明 handler

```haskell
productionProfile
  [ handle ChargePayment prodChargePayment ]

testProfile
  [ handle ChargePayment mockChargePayment ]
```

handler 是真正连接 IO、数据库、HTTP、日志、mock 或 benchmark 的位置。

5. 通过统一校验

系统需要检查：

- workflow 中出现的 fact 是否有 producer，或者被声明为 external fact。
- producer 依赖的 fact 是否闭合。
- producer 使用的 operation 是否存在于 signature。
- 当前 profile 是否有对应 handler。
- 失败路径是否声明。
- 模块是否越权使用不属于自己的 operation。

最小规范工作量可以概括为：

```text
fact
+ effect operation signature
+ producer
+ profile handler
+ validation
```

这套规则的目的不是增加样板代码，而是把副作用从“随手写 IO”升级为可命名、可追踪、可 mock、可校验的 effect 单元。

## 4. 定义统一 EffectTheory

### 前置条件

完成递归边界、Workflow 控制流模型和 Fact / Effect Boundary 设计。

### 目标

新增第二棵前台 DSL 树 `EffectTheory`，专门管理副作用能力、fact 来源、handler 完备性和 profile 切换。

`AppBlueprint` 继续只描述 workflow：

```haskell
currentAst :: AppBlueprint
```

`EffectTheory` 描述 effect system：

```haskell
currentEffectTheory :: EffectTheory
```

未来完整入口可以演进为：

```haskell
currentInterpreter currentAst currentEffectTheory
```

也就是说，`AppBlueprint` 管“程序怎么走”，`EffectTheory` 管“事实从哪里来、副作用由谁解释”。

### 背景约束

- AST 前台不再提供 `effect` 节点，只保留 `fact`。
- `fact` 是 workflow 的叶子节点。
- `fact` 只声明“某个事实被给出”，不包含 IO、数据库、日志、网络请求等执行细节。
- `require` 不作为 AST 节点存在。
- `wait facts body` 表示等待 fact 条件满足，不主动生产 fact。
- 当前 `fact` 的来源还没有规范化；这是 `EffectTheory` 要解决的问题。
- 不推翻现有 `WorkflowAlgebra`，而是在 fact 叶子位置接入 `EffectTheory`。

### 当前架构已经满足的条件

- workflow 已经可描述：`chain / parallel / fallback / race / choice / wait / fact`。
- 副作用候选位置已经可定位：`fact` 是稳定叶子节点。
- 控制流和解释实现已经分离：同一棵 AST 可以用 view/runtime/check 不同 algebra 解释。
- 递归过程已经组合化：`cataWorkflow algebra ast` 已经可用。
- interpreter 配置已有雏形：`InterpretConfig` 已经把当前解释配置单独放出来。
- 运行检测已有雏形：`WorkflowRunReport` 可以报告 workflow 成功/失败和 trace。

### 还缺的条件

- Effect operation signature：有哪些副作用操作，每个操作输入/输出是什么。
- Fact producer registry：哪个 producer 负责生产哪个 fact。
- Fact dependency closure：生产某个 fact 之前需要哪些 fact，依赖链是否闭合。
- Handler registry：每个 profile 下哪些 effect 有 handler。
- Handler completeness validation：用了某个 operation，但 prod/test/mock 是否都有解释。
- Failure policy：producer 或 handler 失败时如何进入 fallback、错误 fact 或报告。
- Permission boundary：模块是否越权使用了不属于自己的 effect。

### 4.1 定义 Effect Signature

定义 effect operation 的统一签名。

示例方向：

```haskell
data UserEffect a where
  AskUserName :: UserEffect UserName
  SaveUser    :: User -> UserEffect ()
```

这一步只描述 operation profile：

```text
operation = 输入类型 -> 输出类型
```

不在这里写真实 IO、数据库、HTTP 或 mock。

输出物：

- 定义最小 `EffectSignature` 或 `EffectOp` 表达方式。
- 明确 operation constructor 是否直接暴露给业务模块。
- 为 operation 提供代码即文档的 smart constructor 或 DSL 名字。

### 4.2 定义 FactProducer

定义 fact 的来源。

示例方向：

```haskell
producer UserKnownFact
  [ needs UserNameAskedFact
  , uses AskUserName
  , uses SaveUser
  ]
```

这一步回答：

```text
谁生产 UserKnownFact？
生产它之前需要哪些 fact？
生产它会使用哪些 effect operation？
```

输出物：

- 定义 `FactProducer`。
- 定义 `producerFact`。
- 定义 `producerNeeds`。
- 定义 `producerUses`。
- 定义 fact 是否允许自动生产，还是只能由 `wait` 等外部事件给出。

### 4.3 定义 EffectTheory

把 signature、producer、profile、handler 声明统一放进一棵前台 DSL。

示例方向：

```haskell
effectTheory =
  theory
    [ effect userEffect
        [ askUserName
        , saveUser
        ]
    , producer UserKnownFact
        [ needs UserNameAskedFact
        , uses askUserName
        , uses saveUser
        ]
    , profile production
        [ handle userEffect prodUserHandler ]
    , profile test
        [ handle userEffect mockUserHandler ]
    ]
```

输出物：

- 定义 `EffectTheory`。
- 定义 `effect` DSL。
- 定义 `producer` DSL。
- 定义 `profile` DSL。
- 定义 `handle` DSL。
- 保持前台只读结构，不暴露 registry/map/validation 实现。

### 4.4 定义 Handler Registry 和 Profile

profile 负责选择生产、测试、mock、benchmark 等解释方式。

输出物：

- `productionProfile`
- `testProfile`
- `mockProfile`
- `benchmarkProfile`
- handler completeness check：每个 profile 是否覆盖当前 workflow 实际会用到的 effect operation。

### 4.5 定义 Validation

EffectTheory 必须能检查“写了 A 和 B 但漏了 C”的问题。

检查项：

- workflow 中出现的每个 `fact` 是否有 producer，或者被声明为 external fact。
- producer 的 `needs` 是否闭合。
- producer 使用的 operation 是否存在于 signature。
- 当前 profile 是否有对应 handler。
- effect operation 是否越权。
- producer 之间是否形成非法循环。
- `wait` 等外部 fact gate 是否被误当成可自动生产。

输出物：

- `validateEffectTheory`
- `validateWorkflowAgainstTheory`
- `EffectTheoryError`
- render/check 报告，把缺失项打印成可读 trace。

### 4.6 接入 Interpreter

现有 workflow 解释流程保持：

```haskell
cataWorkflow workflowAlgebra ast
```

但 fact 叶子不再直接随意 `recordFact`，而是通过 `EffectTheory` 查询 producer/handler。

目标方向：

```haskell
onFact = produceFactWith currentEffectTheory currentProfile
```

输出物：

- 定义 `FactAlgebra` 或 `FactInterpreter`。
- 让 `RuntimeAlgebra` 在 `onFact` 处调用 `EffectTheory`。
- 让 `WorkflowRunReport` 可以展示 fact 生产链。
- 保持 `WorkflowAlgebra` 不依赖具体业务 operation。

### 4.7 范畴论性质约束

这套结构的范畴论核心应该满足：

- Initiality：业务程序先写成自由结构，不提前解释。
- Compositionality：小 signature、producer、handler 可以组合成大 theory。
- Homomorphism：handler 必须保持 effect program 的组合结构。
- Naturality：production/test/mock profile 替换时，workflow AST 不变。
- Totality / Closure：当前 workflow 需要的 fact 和 operation 必须能被完整解释。

工程上对应：

- 可插件化组合。
- 可静态/启动时校验。
- 可统一切换 profile。
- 可定位缺失 producer/handler。
- 可把复杂实现藏进 core。

### 4.8 对比现在的收益

现在：

- `fact` 是规范 AST 节点，但 fact 来源没有规范。
- `recordFact` 可以直接把 fact 记进去，缺少来源证明。
- handler 是否齐全无法统一检查。
- prod/test/mock 切换只能靠解释器约定。
- 缺少“为什么这个 fact 能产生”的可读报告。

做完后：

- 每个 fact 都能追踪到 producer。
- 每个 producer 都能说明依赖哪些 fact、使用哪些 operation。
- 每个 operation 都能检查 handler 是否存在。
- prod/test/mock 可以只换 profile，不改 workflow。
- 缺失 producer、缺失 handler、依赖不闭合可以提前报错。
- workflow render/check 不只显示执行路径，还能显示 fact 生产链。
- 模块副作用边界更清楚，插件更安全。
- 代码即文档从 `AppBlueprint` 扩展到 `EffectTheory`。

## 5. 研究 Cata 的替代递归过程

### 前置条件

完成递归边界、Workflow 控制流模型、Fact / Effect Boundary 和 Effect / Fact Signature 的初步实现。

### 目标

评估普通 `cata` 是否足以承载后续 graph、loop、依赖分析和外部输入展开需求。

### 待研究对象

- `cata`：普通 fold，适合树状 AST。
- `para`：同时保留原始子树和 fold 结果。
- `zygo`：使用一个 fold 的结果辅助另一个 fold。
- `histo`：保留历史结果，适合依赖分析或动态规划。
- `hylo`：组合 `ana` 和 `cata`，适合从外部 seed 展开后直接解释。
- graph-aware fold：处理插件引用、自引用、loop 和共享子图。

### 输出物

- 明确当前阶段继续使用 `cata`，还是引入新的 recursion scheme。
- 明确替代方案的使用条件和边界。
- 避免在控制流模型尚未稳定时过早引入复杂递归方案。

## 6. Graph / Loop / 优化

### 目标

当 component 成为 first-class value 后，将 AST 从 tree 视角扩展到 workflow graph 视角。

### 待解决问题

- component identity / reference。
- plugin 引用和跨文件共享。
- self-reference 和 cycle 检测。
- 合法常驻 loop 与非法无限展开的区分。
- graph-aware render，避免循环结构无限打印。
- middleware 去重与合并。
- fact 依赖优化与自动生产。
- `parallel` / `chain` flatten。
- 从 workflow graph 编译到 runtime plan。

## 7. App 展开为 Ana / Coalgebra

### 前置条件

完成基本 workflow graph 设计，并明确当前系统是否需要支持外部输入作为 app 来源。

### 目标

将 `app` 的构造来源抽象为 `ana coalgebra seed`，使系统不只支持手写 Haskell AST，也支持从外部数据展开 workflow。

### 概念边界

- `ana`：从 seed 展开 AST。
- `coalgebra`：描述 seed 如何生成下一层 workflow 结构。
- `cata`：将已经存在的 AST 折叠成解释结果。
- `hylo`：组合 `ana` 与 `cata`，允许从 seed 展开并直接解释。

### 输出物

- 定义 app 的输入 seed，例如 JSON、RPC payload、配置文件或插件注册表。
- 定义 `AppCoalgebra`。
- 保留当前手写 `app` 作为最小 demo。
- 支持两种解释路径：
  - 直接解释手写 AST。
  - 先 `ana coalgebra seed` 展开 AST，再解释。
- 后续评估是否升级为 `hylo`，避免必须完整 materialize 中间 AST。
