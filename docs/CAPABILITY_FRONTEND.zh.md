# Capability Frontend

本文描述当前业务作者的默认写法。这个前台仍处在 candidate default business frontend 阶段；它是推荐入口，但还不是强兼容 SDK 承诺。

## 默认模块

普通业务作者默认只接触：

```text
Framework.Ast
Framework.Business
Framework.Handler
Framework.App
```

职责划分：

```text
Framework.Ast
  workflow / AppBlueprint / facts / names

Framework.Business
  capability / pipeline / policy / handler binding / transform binding

Framework.Handler
  handler / transform implementation API

Framework.App
  thin app runner: AppBlueprint + EffectTheory + RuntimeEffectEnvironment
```

`Framework.Effect` 仍然 exposed，但它是 lowering 后的 normalized IR / compatibility / framework-internal surface，不是普通业务默认写法。

`Framework.TrustBase`、`Framework.SelfArtifact`、`Framework.FixedPoint`、`Framework.Runtime.Evidence*`、`Bootstrap.*` 和 witness executables 属于框架维护、自举、验收、报告或 promotion gate，不属于普通业务 authoring surface。

## Capability 词汇

业务能力用 `Framework.Business` 里的词汇声明：

```text
capability
requires
input
output
uses
onError
privateFact
produces
policy
retryOnce
idempotentPolicy
pipeline
handler
handlerBinding
transform
transformBinding
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

业务作者不需要手写 `needs`、`take`、`make`、`externalMake`。这些由 capability lowering 生成。

## Lowering Contract

Capability 前台 lower 到 effect IR 的关系：

```text
requires F        -> needs F
input T           -> take T
output T          -> make T
uses S I O        -> uses S + externalMake S I O
onError S I O     -> error S + externalMake S I O
privateFact F     -> private FactProducer F + private boundary fact
produces F        -> FactProducer F
retryOnce S       -> retry S
idempotentPolicy S -> idempotent S
transform A B N   -> transform A B N
```

`pipeline` 只描述 artifact 数据流，例如：

```text
UserName -> ReportInput -> ReportOutput
```

相邻节点会形成 transform candidate。业务 fact 仍然必须通过 `requires`、`privateFact`、`produces` 明确声明。

## Import Boundary

严格 authoring 区域：

```text
Domain.Business
Domain.AppBlueprint
Domain.Runtime
Domain.Vocabulary
Domain.EffectVocabulary
Effects.*
Plugins.*
```

这些文件应只使用默认业务前台模块。`business-syntax-witness` 会检查：

```text
ordinary authoring imports stay on Framework.Ast / Framework.Business / Framework.Handler / Framework.App
Domain.Runtime uses Framework.Handler rather than Framework.Runtime
app runner imports Framework.App rather than Framework.TrustBase
Effects.* and Domain.Business do not import Framework.Effect directly
Bootstrap.* is absent from ordinary business authoring
```

验收和报告层不是普通 authoring：

```text
SelfDomainApp
Domain.SemanticEvidence
runtime diagnosis witness
domain-app-report
business-syntax-witness itself
```

这些可以接触 reporting/evidence API，因为它们负责验收和证据输出。

## Diagnostics

友好错误不重新实现校验规则。`Framework.Business.Diagnostics` 只把已有的 `RuntimeError` 和 `BusinessShapeIssue` 映射成业务修复动作，例如：

```text
declared uses but no handler registered
declared transform but no TransformBinding registered
send boundary missing
pipeline edge not adjacent
handler binding shape does not match capability uses/input/output
```

底层 runtime、constraint、business-shape 结果仍然是事实源。

## Witness

最小业务前台验证：

```powershell
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec domain-app-report -- --json
```

这些命令进入 `check-semantic`，但不进入 `check-fast`。
