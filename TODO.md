# TODO

本文档记录下一阶段的架构路线。README 保留项目概览，实施顺序以本文档为准。

## 当前路线结论

当前顺序：先完成 workflow 控制流接口，再接入轻量 effect 边界，最后按需扩展完整 effect system。

- `AppBlueprint` 描述“程序怎么走”：顺序、并发、分支、等待、回调、循环和 hanging 外挂节点。
- workflow 可以用 effectful carrier 运行；业务 effect system 单独定义。
- workflow 遇到 `fact` 叶子时，只调用抽象 fact/effect 边界，不直接写 IO、数据库、日志、HTTP 或 mock。
- `EffectTheory` 负责 fact 来源：producer、externalMake/externalTake 边界、implementation、profile、失败策略和校验。
- `Core.App.app` 负责从 AST 出发构建 app plan：收集 fact，展开 producer 闭包，检查 externalMake boundary 和 implementation。
- 实施顺序：`WorkflowModel` -> `Core.App` -> `Progressive EffectBoundary` -> recursion scheme 扩展。

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

将 workflow 控制流语义从业务 effect implementation 中解耦出来，形成独立的 `WorkflowModel` 或 `WorkflowSemantics`。

这一阶段实现控制流结构，不接入真实业务副作用。控制流负责进入 AST、组合分支、调度子 workflow；fact 生产交给后续 fact/effect 边界和 `EffectTheory`。

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

## 3. 定义轻量 Fact / Effect Boundary

### 前置条件

完成 Workflow 控制流模型的最小运行语义。

### 目标

在 workflow 和 effect system 之间定义稳定边界。workflow 只声明当前需要给出某个 fact；producer 和 implementation 由 effect system 管理。

边界采用渐进式配置：

- 直接 fact：`fact currentFact`
- fact 依赖：`fact currentFact [needs otherFact]`
- 出站边界：`fact currentFact [needs otherFact, uses sendName]`
- profile implementation：只有 `uses sendName` 时才需要

概念方向：

```haskell
onFact :: Fact -> carrier FactResult
```

或：

```haskell
produceFact :: Fact -> carrier FactResult
```

范围：抽象 workflow 叶子节点；完整 effect system 另行定义。

### 边界规则

- `fact` 是 workflow 的叶子节点。
- workflow 控制流只调用 fact 边界。
- `wait` 仍然表示 fact gate：它检查 fact 条件，不主动生产 fact。
- `externalMake` 只声明系统可调用的出站能力边界，用于 implementation/profile 检查。
- `externalTake` 声明外界直接给出的入站 fact，不需要 implementation。
- 内部 producer 和纯推导 producer 不需要 externalMake boundary。

### 输出物

- 定义 `FactBoundary`、`FactAlgebra` 或同等概念。
- 明确 `fact` 叶子的统一调用形状。
- 让 runtime/render/check carrier 都通过同一个 fact 边界处理 fact。
- 避免 `recordFact` 这种实现细节直接成为架构语义。
- 为后续 `EffectTheory` 接入保留稳定接口。

### 3.1 新建 Effect 单元

本节定义新增 effect 单元时需要写的前台声明。具体类型、校验和 implementation 实现放到后续 `EffectTheory` 章节。

#### 前台左键路径

effect system 的前台入口保持可跳转路径：

```text
main
  -> currentEffects
  -> effectTheory
  -> paymentEffect
  -> paymentFacts
  -> paymentSends
  -> paymentProducers
  -> paymentImplementations
```

路径含义：

- `currentEffects`：当前程序选择哪一套 effect theory。
- `effectTheory`：当前 effect theory 由哪些 effect 单元组成。
- `paymentEffect`：Payment 模块作为一个 effect 单元，对外暴露什么副作用语义。
- `paymentFacts`：Payment 模块能提供哪些 workflow 可见的 fact。
- `paymentSends`：Payment 模块需要哪些出站能力签名。
- `paymentProducers`：哪些 producer 负责把出站调用结果转化为 fact。
- `paymentImplementations`：不同 profile 下，externalMake boundary 由哪个 implementation 解释。

示例形状：

```haskell
paymentEffect :: EffectUnit
paymentEffect =
  effect PaymentEffect
    [ paymentFacts
    , paymentSends
    , paymentProducers
    , paymentImplementations
    ]
```

需要业务用户选择或赋值的 effect 组件都应当能单独跳转。`EffectTheory` 可以在 core 层归一化为 record、registry 或 map；前台入口保持 DSL 结构。

前台文件结构采用“一个 effect 一个 claim 文件”。例如 `Effects.User` 里只声明 `userEffect`，内部按需写 `fact`、`externalMake`、`externalTake` 和 `profile`。需要复用某段声明时再起局部名字。

effect 注册由构建器根据标记生成：

```haskell
-- effect: paymentEffect
paymentEffect :: EffectUnit
paymentEffect =
  effect PaymentEffect
    [ paymentFacts
    , paymentSends
    , paymentProducers
    , paymentImplementations
    ]
```

`Effects.Theory` 由 `Setup.hs` 收集 `-- effect:` 标记后生成。

#### 与 Interpreter 的耦合边界

effect 前台路径与 interpreter 的耦合集中在一条边界上：

```text
currentEffects
  -> contextware
  -> fact/effect boundary
  -> fAlgebra
  -> recursion model
  -> currentAst
```

约束如下：

- `currentAst` 只依赖 fact 名字，不直接依赖 effect externalMake boundary、producer 或 implementation。
- `currentEffects` 不直接依赖 `cata / para / hylo` 等 recursion model。
- `contextware` 是 effect theory 接入 interpreter 的边界；它负责把 `EffectTheory` 转成 fact 叶子可调用的解释能力。
- `fAlgebra` 可以接收已经被 `contextware` 装配过的 fact 解释能力，但不应该要求业务 effect 模块理解 workflow 控制流。
- workflow 控制流负责“怎么进入 AST”，effect system 负责“fact 从哪里来以及由谁解释”。

最终前台形成两条链路：

```text
main -> currentAst     -> app / plugins / workflow
main -> currentEffects -> effectTheory / effect units
```

interpreter 汇合两条链路：

```haskell
currentInterpreter currentAst currentEffects
```

拼装模块流程时只写 `AppBlueprint`：

```haskell
paymentModule =
  wait [UserKnownFact] $
    chain PaymentFlow
      [ fact [PaymentRequestedFact]
      , fact [PaymentFinishedFact]
      ]
```

如果 `PaymentFinishedFact` 需要由系统生产，补充以下 effect 声明。

1. 声明模块对外给出的 fact

```haskell
PaymentRequestedFact
PaymentFinishedFact
PaymentFailedFact
```

这些 fact 是 workflow 可见的公共语义，不包含 IO、数据库、HTTP 或 mock。

2. 按需声明 externalMake boundary

```haskell
ChargePayment :: PaymentRequest -> PaymentEffect PaymentResult
QueryPayment  :: PaymentId -> PaymentEffect PaymentStatus
```

`externalMake` 只用于系统主动调用外界能力的出站边界。内部推导或 runtime 内部 producer 不需要 externalMake boundary。

3. 声明 fact producer

```haskell
fact PaymentFinishedFact
  [ needs UserKnownFact
  , needs PaymentRequestedFact
  , uses ChargePayment
  , onFailure PaymentFailedFact
  ]
```

producer 必须回答：

- 谁生产这个 fact？
- 生产前依赖哪些 fact？
- 是否需要出站能力？
- 生产失败时给出什么失败 fact 或失败策略？

4. 为被 `uses` 的 externalMake boundary 声明 implementation

```haskell
productionProfile
  [ implement ChargePayment prodChargePayment ]

testProfile
  [ implement ChargePayment mockChargePayment ]
```

implementation 连接 IO、数据库、HTTP、日志、mock 或 benchmark。

5. 通过统一校验

系统需要检查：

- workflow 中出现的 fact 是否有 producer，或者被声明为 externalTake fact。
- producer 依赖的 fact 是否闭合。
- producer 使用的 externalMake boundary 是否存在于 signature。
- 当前 profile 是否有对应 implementation。
- 失败路径是否声明。
- 模块是否越权使用不属于自己的 externalMake boundary。

渐进式声明集合：

```text
workflow fact
+ producer
+ externalMake          仅出站边界需要
+ externalTake       仅入站 fact 需要
+ profile       仅 externalMake boundary 需要
+ app build     自动检查闭包
```

这些声明用于命名、追踪、mock 和校验副作用边界。

## 4. 定义统一 EffectTheory

### 前置条件

完成递归边界、Workflow 控制流模型和 Fact / Effect Boundary 设计。

### 目标

新增第二棵前台 DSL 树 `EffectTheory`，专门管理副作用能力、fact 来源、implementation 完备性和 profile 切换。

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

`AppBlueprint` 描述 workflow；`EffectTheory` 描述 fact 来源和副作用解释方式。

### 背景约束

- AST 前台不再提供 `effect` 节点，只保留 `fact`。
- `fact` 是 workflow 的叶子节点。
- `fact` 只声明“某个事实被给出”，不包含 IO、数据库、日志、网络请求等执行细节。
- `require` 不作为 AST 节点存在。
- `wait facts body` 表示等待 fact 条件满足，不主动生产 fact。
- 当前 `fact` 来源尚未规范化，后续由 `EffectTheory` 处理。
- 保留现有 `WorkflowAlgebra`，在 fact 叶子位置接入 `EffectTheory`。

### 当前架构已经满足的条件

- workflow 已经可描述：`chain / parallel / fallback / race / choice / wait / fact`。
- 副作用候选位置已经可定位：`fact` 是稳定叶子节点。
- 控制流和解释实现已经分离：同一棵 AST 可以用 view/runtime/check 不同 algebra 解释。
- 递归过程已经组合化：`cataWorkflow algebra ast` 已经可用。
- interpreter 配置已有雏形：`InterpretConfig` 已经把当前解释配置单独放出来。
- 运行检测已有雏形：`WorkflowRunReport` 可以报告 workflow 成功/失败和 trace。

### 还缺的条件

- Effect externalMake signature：有哪些出站能力，每个能力输入/输出是什么。
- Fact producer registry：哪个 producer 负责生产哪个 fact。
- Fact dependency closure：生产某个 fact 之前需要哪些 fact，依赖链是否闭合。
- Implementation registry：每个 profile 下哪些 externalMake boundary 有 implementation。
- Implementation completeness validation：用了某个 externalMake boundary，但 prod/test/mock 是否都有解释。
- Failure policy：producer 或 implementation 失败时如何进入 fallback、错误 fact 或报告。
- Permission boundary：模块是否越权使用了不属于自己的 effect。

### 4.1 定义 Effect Signature

定义 effect externalMake boundary 的统一签名。

示例方向：

```haskell
data UserEffect a where
  AskUserName :: UserEffect UserName
  SaveUser    :: User -> UserEffect ()
```

出站能力签名：

```text
externalMake boundary = 输入类型 -> 输出类型
```

不在这里写真实 IO、数据库、HTTP 或 mock。

输出物：

- 定义最小 `EffectSignature` 或 `EffectOp` 表达方式。
- 明确 externalMake boundary constructor 是否直接暴露给业务模块。
- 为 externalMake boundary 提供代码即文档的 smart constructor 或 DSL 名字。

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

FactProducer 需要回答：

```text
谁生产 UserKnownFact？
生产它之前需要哪些 fact？
生产它会使用哪些 externalMake boundary？
```

输出物：

- 定义 `FactProducer`。
- 定义 `producerFact`。
- 定义 `producerNeeds`。
- 定义 `producerUses`。
- 定义 fact 是否允许自动生产，还是只能由 `wait` 等外部事件给出。

### 4.3 定义 EffectTheory

把 signature、producer、profile、implementation 声明统一放进一棵前台 DSL。

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
        [ implement userEffect prodUserImplementation ]
    , profile test
        [ implement userEffect mockUserImplementation ]
    ]
```

输出物：

- 定义 `EffectTheory`。
- 定义 `effect` DSL。
- 定义 `producer` DSL。
- 定义 `profile` DSL。
- 定义 `implement` DSL。
- 保持前台只读结构，不暴露 registry/map/validation 实现。

### 4.4 定义 Implementation Registry 和 Profile

profile 负责选择生产、测试、mock、benchmark 等解释方式。

输出物：

- `productionProfile`
- `testProfile`
- `mockProfile`
- `benchmarkProfile`
- implementation completeness check：每个 profile 是否覆盖当前 workflow 实际会用到的 externalMake boundary。

### 4.5 定义 App Build

`validate` 不作为业务用户手写入口。检查提升到 app 构建阶段：

```haskell
app currentAst currentEffects Production
```

`app` 从 AST 出发自动倒推依赖闭包。

检查项：

- workflow 中出现的每个 `fact` 是否有 producer，或者被声明为 externalTake fact。
- producer 的 `needs` 是否闭合。
- producer 使用的 externalMake boundary 是否存在于 signature。
- 当前 profile 是否有对应 implementation。
- effect externalMake boundary 是否越权。
- producer 之间是否形成非法循环。
- `wait` 等外部 fact gate 是否被误当成可自动生产。

输出物：

- `Core.App.app`
- `AppPlan`
- `AppError`
- render/check 报告，把缺失项打印成可读 trace。

### 4.6 接入 Interpreter

现有 workflow 解释流程保持：

```haskell
cataWorkflow workflowAlgebra ast
```

fact 叶子后续通过 `EffectTheory` 查询 producer/implementation。

目标方向：

```haskell
onFact = produceFactWith currentEffectTheory currentProfile
```

输出物：

- 定义 `FactAlgebra` 或 `FactInterpreter`。
- 让 `RuntimeAlgebra` 在 `onFact` 处调用 `EffectTheory`。
- 让 `WorkflowRunReport` 可以展示 fact 生产链。
- 保持 `WorkflowAlgebra` 不依赖具体业务 externalMake boundary。

### 4.7 结构约束

目标性质：

- Initiality：业务程序先写成自由结构，不提前解释。
- Compositionality：小 signature、producer、implementation 可以组合成大 theory。
- Homomorphism：implementation 必须保持 effect program 的组合结构。
- Naturality：production/test/mock profile 替换时，workflow AST 不变。
- Totality / Closure：当前 workflow 需要的 fact 和 externalMake boundary 必须能被完整解释。

工程含义：

- 可插件化组合。
- 可静态/启动时校验。
- 可统一切换 profile。
- 可定位缺失 producer/implementation。
- 可把复杂实现藏进 core。

### 4.8 预期收益

现在：

- `fact` 是规范 AST 节点，但 fact 来源没有规范。
- `recordFact` 可以直接把 fact 记进去，缺少来源证明。
- implementation 是否齐全无法统一检查。
- prod/test/mock 切换只能靠解释器约定。
- 缺少“为什么这个 fact 能产生”的可读报告。

完成后：

- 每个 fact 都能追踪到 producer。
- 每个 producer 都能说明依赖哪些 fact、使用哪些 externalMake boundary。
- 每个 externalMake boundary 都能检查 implementation 是否存在。
- prod/test/mock 可以只换 profile，不改 workflow。
- 缺失 producer、缺失 implementation、依赖不闭合可以提前报错。
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

## 8. Constraint IR / SMT Solver 接入路线

### 当前结论

先抽取纯 Haskell 约束事实，再接 SMT solver。输入包括 `AppPlan`、`EffectTheory`、take/make rule、profile implementation 和 wait gate。

这层约束事实先服务于解释、检查和错误报告；等 effect system 语义稳定后，再选择是否把它翻译成 SBV、Z3 或其他 solver 后端。

### 目标

定义不依赖 runtime handler 的 `Core.Effect.Constraint`。内容包括当前 app 的 fact、rule、externalMake、externalTake、implementation 和 wait 条件；不执行 IO，不调用具体 handler。

示例形状：

```haskell
data ConstraintFact
  = Makes RuleId WorkflowFact
  | Takes RuleId WorkflowFact
  | UsesExternalMake RuleId SendName
  | Implements ProfileName SendName
  | ExternalTake WorkflowFact
  | WaitsFor WorkflowName WorkflowFact
```

### 第一阶段输出物

- `Core.Effect.Constraint`
- `constraintsFromAppPlan :: AppPlan -> [ConstraintFact]`
- `renderConstraintFacts :: [ConstraintFact] -> Text`
- `checkConstraintFacts :: [ConstraintFact] -> [ConstraintError]`

### 第一阶段检查项

- 某个 fact 能否从已有 take/make rule 倒推出来源。
- 某个 producer 依赖的 take fact 是否都有来源。
- 某个 `uses externalMake` 是否存在对应 externalMake signature。
- 当前 profile 是否实现了所有会被使用的 externalMake。
- `externalTake` fact 是否被错误地当成可自动生产。
- `wait` 等待的 fact 是否存在明显永远不会出现的情况。
- 是否存在多个 rule 同时生产同一个 fact，并且语义没有声明冲突处理方式。
- 是否存在 take/make rule 的依赖环。

### 直接收益

- app 构建阶段输出缺失依赖解释。
- profile 完备性从约束事实中统一检查。
- runtime 执行前解释 fact 产生路径。
- mock / benchmark 自动计算最小 externalMake implementation 集合。
- JSON、RPC、插件注册表或 ana coalgebra 复用同一套检查。

### 后续 SMT 用途

solver 输入：

- fact reachability：某个目标 fact 是否一定可达。
- counterexample：如果不可达，给出缺失的最短依赖链。
- minimal implementation set：某个 profile 至少要实现哪些 externalMake。
- dead wait candidate：哪些 wait 条件在当前 app 中没有可行来源。
- recursive/template legality：自引用、模板展开和 loop 是否有合法停止标记。
- conflicting producer：多个 producer 同时 make 同一 fact 时是否违反唯一性约束。

### 边界

- Constraint IR 只依赖声明，不依赖具体 runtime handler。
- Solver 后端是可选层，不成为 core app 构建的硬依赖。
- core 先保证普通 Haskell 检查可读、可测、可解释。
- SMT 只用于更强的证明、反例和最小集合计算，不替代当前 DSL 语义。
