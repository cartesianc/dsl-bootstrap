# Effect IR 与 Capability Lowering

本文记录 capability 前台如何 lower 到 normalized effect IR。

业务作者从 `Framework.Business` 开始。`Framework.Effect` 用于 lowering 后的 normalized semantic IR、compatibility layer、framework/internal source 和 witness/test IR。

底层 IR 仍然是 proof、diagnosis、report、runtime closure 和自举表达的语义来源。Capability 前台只改变作者入口，不改变 runtime 语义。

## 1. 分层

```text
Domain.Business
  业务声明入口。只描述 capability、输入输出、外部能力、业务状态和绑定关系。

Effects.*
  lowering 薄层。调用 Framework.Business.capabilitiesEffect，把 capability group lower 成 EffectUnit。
  lowering 后的 EffectUnit 保留 imports、exports、pipeline 和 handler metadata。

Bootstrap.Business / Framework.Business
  业务编写入口。提供 capability DSL、pipeline DSL、lowering、handler/transform/business-shape checker。

Bootstrap.Effect / Framework.Effect
  normalized effect IR。保留 effect/fact/needs/take/make/uses/externalMake/transform/retry/idempotent。
  system-level authoring 使用 effectSystem/imports/privateFacts/exports 表达 scope boundary。
```

## 2. Capability 源码

业务能力使用这些词：

```text
capability
requires
input
output
uses
privateFact
produces
policy
pipeline
handler
transform
```

示例源码：

```haskell
generateReportCapability =
  capability "GenerateReport"
    [ requires AddCalculatedFact
    , requires FactorialCalculatedFact
    , requires SquaresCalculatedFact
    , requires UserNameAskedFact
    , input UserName
    , pipeline "GenerateReportPipeline" [UserName, ReportInput, ReportOutput]
    , transform (transformBinding UserNameToReportInput UserName ReportInput)
    , uses GenerateReport ReportInput ReportOutput
    , output ReportOutput
    , produces ReportGeneratedFact
    , handler (handlerBinding RuntimeGenerateReport "GenerateReport" [ReportInput] [ReportOutput] [ReportGeneratedFact])
    ]
```

业务作者在 capability 层声明业务意图。`needs/take/make/externalMake` 由 lowering 进入 normalized IR。

## 3. Lowering

```text
requires F        -> needs F
input T           -> take T
output T          -> make T
uses S I O        -> uses S + externalMake S I O
privateFact F     -> private FactProducer F + EffectSystemBoundary private fact
produces F        -> FactProducer F
policy retry      -> retry S
policy idempotent -> idempotent S
transform A B N   -> transform A B N, only when A -> B is an adjacent pipeline edge
```

`pipeline` 只表达 artifact 数据流：

```text
pipeline GenerateReportPipeline
  UserName -> ReportInput -> ReportOutput
```

Pipeline 会生成相邻 transform candidate。业务 fact 通过 `requires`、`privateFact` 和 `produces` 显式声明。`ReportOutput` 是 runtime data，`ReportGeneratedFact` 是业务状态。

## 4. Normalized IR

Lowering 后的 effect IR 继续使用这些语义构件：

```text
effect        effect theory 分组
effectSystem  带 imports/privateFacts/exports/pipeline/handler 的 system-level effect 分组
imports       system 需要外部已经导出的 fact
privateFacts  system 内部 fact
exports       system 对外承诺的 fact
pipeline      system 内声明的 artifact flow
handler       system 内 send 到 handler 的绑定声明
fact          可观察 fact producer
needs         fact 依赖
take          artifact 输入类型
make          artifact 输出类型
uses          外部 send boundary 使用
externalMake  send boundary 输入输出签名
transform     typed value 转换
retry         retry policy
idempotent    replay policy
error         error handler 分发
```

可以直接写 effect IR 的位置：

```text
framework/internal source
compatibility layer
proof / report / diagnosis 支撑代码
witness 或 test IR
需要规范化语义的 bootstrap / self-expression 代码
```

普通业务前台保留给 capability：

```text
effect/fact/needs/take/make/uses/externalMake
```

`effect name sections` 仍然兼容旧 IR：默认 exports 为本 unit 里声明的 producer fact，imports、private facts、pipelines 和 handlers 为空。需要显式 system scope 时使用：

```haskell
effectSystem Name
  [ imports [InputReadyFact]
  , privateFacts [InternalPreparedFact]
  , exports [OutputReadyFact]
  , pipeline "OutputPipeline" [InputValue, OutputValue]
  , handler BuildOutput RuntimeBuildOutput
  ]
  [ fact InternalPreparedFact [needs InputReadyFact]
  , fact OutputReadyFact [needs InternalPreparedFact, uses BuildOutput]
  , externalMake BuildOutput InputValue OutputValue
  ]
```

`effectUnitBoundary` 和 `effectUnitSystem` 把这层 IR lower 到 `Workflow.EffectSystemBoundary` / `Workflow.EffectSystem`，供 runtime boundary checker、report 和 witness 使用。

EffectRow is a value-level semantic IR for algebraic boundary composition / diff / evidence; row polymorphism remains a future backend encoding and is not business syntax in this round.

## 5. Fact / Artifact / Internal

Fact 是业务世界的可观察状态：

```text
被 workflow wait/fact 使用
被 capability requires/produces 使用
需要进入 report、evidence、diagnosis
表示业务阶段完成
需要审计、补偿或跨流程引用
```

Artifact 是 runtime 数据：

```text
handler 输入或输出
transform 输入或输出
下一个 handler 的参数
包含 payload/value
业务人员通常只使用公开的 capability 名和 fact 名
```

Internal 留在 handler/transform 内：

```text
临时变量
字段清洗
格式化细节
单个算法步骤
不被其他 capability 依赖
失败时定位到上层 fact 已足够
```

`checkBusinessShape` 会做保守提示：

```text
fact 名应看起来像业务事实
artifact type 不应伪装成 fact
fact 和 artifact type 不应同名或去掉 Fact 后同名
handler consumes/emits/claims 必须和 capability 对齐
transform binding 必须是 pipeline 相邻边
```

checker 只提示，不自动改名，不自动拆 fact。

## 6. Binding Semantics

Handler 绑定 capability：

```text
handlerBinding RuntimeGenerateReport "GenerateReport" [ReportInput] [ReportOutput] [ReportGeneratedFact]
```

检查规则：

```text
consumes 匹配 capability uses 的 send input
emits 匹配 capability uses 的 send output
claims 必须属于 capability produces
```

Transform 只做数据形状转换：

```text
transformBinding UserNameToReportInput UserName ReportInput
```

检查规则：

```text
transform 不产生业务 fact
transform 不调用外部 send
transform 必须能在 pipeline 相邻边中找到
```

## 7. Witness

Capability lowering 的最小 witness：

```powershell
stack exec business-syntax-witness
stack exec business-syntax-witness -- --json
```

它验证：

```text
GenerateReport capability lowering 生成 needs/take/make/uses/externalMake/transform
GenerateReport pipeline 生成 UserName -> ReportInput 和 ReportInput -> ReportOutput candidate
Effects.* 等于对应 Domain.Business capability group lowering
Effects.* 的 EffectUnit metadata 保留 capability group 的 imports/exports/pipeline/handler
Effects.* facade 导入 Framework.Business 且不导入 Framework.Effect
Domain.Business 导入 Framework.Business 且不导入 Framework.Effect
allDomainCapabilities 通过 business-shape checker
runtime pipeline adapter 可以执行 transform 链
effectSystem/imports/privateFacts/exports/pipeline/handler lower 到 Workflow.EffectSystemBoundary
effectSystem privateFacts 保持内部 scope，exports 定义 public boundary
```

期望输出：

```text
[witness] ok business syntax evidence 18 payload claims
```

日常 capability/lowering 语法改动使用 `business-syntax-witness`。高危 `self-artifact-witness` artifact gate 内部也包含这项检查；语法文档和 README/docs-only 变更走轻量文档检查。
