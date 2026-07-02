# Effect Frontend Syntax

本文记录业务侧 effect 前台语法。目标是让业务作者写 capability、pipeline、policy、handler binding 和 transform binding；框架再 lower 到底层 effect IR。

底层 IR 仍然是 proof、diagnosis、report 和 runtime closure 的语义来源。前台语法只改变作者入口，不改变 runtime 语义。

## 1. 分层

```text
Domain.Business
  业务 source of truth。只描述能力、输入输出、外部能力、业务状态和绑定关系。

Effects.*
  薄 facade。调用 Framework.Business.capabilitiesEffect，把业务能力 lower 成 EffectUnit。

Bootstrap.Business / Framework.Business
  capability DSL、pipeline DSL、lowering、handler/transform/business-shape checker。

Bootstrap.Effect / Framework.Effect
  normalized effect IR。保留 needs/take/make/uses/externalMake/transform/retry/idempotent。
```

## 2. Capability DSL

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
    , handler (handlerBinding RuntimeGenerateReport "GenerateReport" [ReportInput] [ReportOutput] [ReportGeneratedFact])
    ]
```

业务作者不需要在这里手写 `take/make/externalMake`。这些仍然存在，只是进入 normalized IR。

## 3. Lowering

```text
requires F        -> needs F
input T           -> take T
output T          -> make T
uses S I O        -> uses S + externalMake S I O
produces F        -> FactProducer F
policy retry      -> retry S
policy idempotent -> idempotent S
transform A B N   -> transform A B N, only when A -> B is an adjacent pipeline edge
```

Pipeline 只表达 artifact 数据流：

```text
pipeline GenerateReportPipeline
  UserName -> ReportInput -> ReportOutput
```

Pipeline 会生成相邻 transform candidate，但不会自动生成业务 fact。`ReportOutput` 是 runtime data，`ReportGeneratedFact` 是业务状态，二者必须显式区分。

## 4. Fact / Artifact / Internal

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
业务人员不需要直接关心这个状态名
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

## 5. Handler 和 Transform Binding

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

## 6. Witness

新增 witness：

```powershell
stack exec business-syntax-witness
```

它验证三件事：

```text
GenerateReport capability lowering 生成 needs/take/make/uses/externalMake/transform
GenerateReport pipeline 生成 UserName -> ReportInput 和 ReportInput -> ReportOutput candidate
allDomainCapabilities 通过 business-shape checker
```

`self-artifact-witness` 的 artifact gate 已包含 `business-syntax-witness`。

