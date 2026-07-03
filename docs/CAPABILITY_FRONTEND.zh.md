# Capability 前台

本文定义当前业务作者的 authoring surface。

在本仓库中，业务侧默认通过 `Framework.Business` 写 capability 前台。`Framework.Effect` 用于 lowering 后的 normalized semantic IR、compatibility layer、framework/internal 表达和 witness/test IR。

这条规则服务当前自迭代框架快照：先冻结业务写法，再让 report、proof、diagnosis、fixed-point 和 artifact gate 围绕稳定入口继续自证。

## 1. Authoring Surface

业务作者默认接触：

```text
Framework.Ast
  workflow / AppBlueprint 前台

Framework.Business
  capability / pipeline / policy / handler binding / transform binding 前台

Framework.Handler
  handler / transform 实现前台
```

业务自举、证据和架构迭代再接触：

```text
Framework.TrustBase
  report / proof / diagnosis / fixed point / artifact gate
```

`Framework.Effect` 的定位是：

```text
normalized semantic IR
compatibility layer
framework/internal source
witness / test IR
```

业务作者从 `Framework.Business` 开始；`Framework.Effect` 承接 lowering 后的语义层。

## 2. Capability 词汇

业务能力使用这些词：

```text
capability
requires
input
output
uses
produces
policy
pipeline
handler
transform
```

这些词描述业务能力、业务事实、artifact 数据流、外部 send boundary、handler binding 和 transform binding。业务作者不需要手写 `needs`、`take`、`make`、`externalMake`。

`NoInput`、`Unit`、`ErrorInput` 和 `SendName` / `TypeName` / `HandlerName` / `TransformName` / `EffectName` 这类 authoring name 也从 `Framework.Business` 暴露。业务前台不需要为了 send boundary sentinel values 或命名类型直接导入 `Framework.Effect`。

示例：

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
    , handler
        ( handlerBinding
            RuntimeGenerateReport
            "GenerateReport"
            [ReportInput]
            [ReportOutput]
            [ReportGeneratedFact]
        )
    ]
```

这段源码的业务来源在 `Domain.Business`。`Effects.*` 只负责调用 `capabilitiesEffect` lower 成 effect IR。

## 3. Lowering Contract

Capability 前台 lower 到 effect IR：

```text
requires F        -> needs F
input T           -> take T
output T          -> make T
uses S I O        -> uses S + externalMake S I O
produces F        -> FactProducer F
policy retry      -> retry S
policy idempotent -> idempotent S
transform A B N   -> transform A B N
```

`pipeline` 只表达 artifact 数据流：

```text
UserName -> ReportInput -> ReportOutput
```

它生成相邻 transform candidate，但不会自动生成业务 fact。业务 fact 必须通过 `requires` 和 `produces` 显式写出。

## 4. Fact 与 Artifact

Fact 是业务世界的可观察状态：

```text
workflow wait/fact 会读取
capability requires/produces 会声明
report、proof、diagnosis、semantic evidence 会追踪
跨 capability 或跨流程需要稳定命名
```

Artifact 是 runtime 数据：

```text
handler 输入或输出
transform 输入或输出
pipeline 相邻节点
typed runtime value
```

Internal 留在 handler/transform 内：

```text
临时变量
字段清洗
格式化细节
单个算法步骤
不需要跨 capability 引用的中间状态
```

## 5. domain-app 样板

`domain-app` 用来验证 facade 边界和业务侧声明链路：

```text
Domain.Business capability
  -> Effects.* lowering
  -> effect IR
  -> Domain.Runtime handler/transform
  -> domain-app-report / business-syntax-witness
```

边界规则：

```text
Domain.Business
  只写 capability / pipeline / policy / binding

Effects.*
  只做 lowering 薄层

Domain.Runtime
  放执行、IO、typed value conversion、handler 和 transform 实现

Domain.SemanticEvidence
  放可验证 evidence 和 generated-source checks
```

## 6. Witness

Capability 前台的最小验收：

```powershell
stack exec business-syntax-witness
stack exec business-syntax-witness -- --json
```

当前 witness 检查：

```text
GenerateReport capability lowering 生成 needs/take/make/uses/externalMake/transform
GenerateReport pipeline 生成 UserName -> ReportInput 和 ReportInput -> ReportOutput candidate
Effects.* 等于对应 Domain.Business capability group lowering
Domain.Business 导入 Framework.Business 且不导入 Framework.Effect
Domain.EffectVocabulary 导入 Framework.Business 且不导入 Framework.Effect
allDomainCapabilities 通过 business-shape checker
runtime pipeline adapter 可以执行 transform 链
```

期望输出：

```text
[witness] ok business syntax evidence 13 payload claims
```

`--json` 输出 `business-syntax-evidence.v1`，用于记录 capability lowering、facade boundary、pipeline adapter 和当前 EffectSystem boundary。
