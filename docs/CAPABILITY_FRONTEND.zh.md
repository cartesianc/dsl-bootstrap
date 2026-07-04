# Capability Frontend

本文介绍 `Framework.Business` 的业务写法。业务开发者用 capability 描述业务能力，
框架再把 capability lowering 成 effect theory。

## 默认模块

普通业务代码使用：

```text
Framework.Ast
Framework.Business
Framework.Handler
Framework.App
```

职责：

```text
Framework.Ast
  workflow / AppBlueprint / facts / names

Framework.Business
  capability / pipeline / policy / handler binding / transform binding

Framework.Handler
  handler / transform implementation API

Framework.App
  AppBlueprint + EffectTheory + RuntimeEffectEnvironment 的 runner
```

`Framework.Effect` 适合 normalized IR、兼容代码、框架内部实现和 witness。
新业务代码从 `Framework.Business` 开始。

维护、验收和发布流程使用这些入口：

```text
Framework.TrustBase
Framework.SelfArtifact
Framework.FixedPoint
Framework.Runtime.Evidence*
Bootstrap.*
witness executables
```

## Capability 词汇

业务能力由 `Framework.Business` 里的词汇声明：

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

`needs`、`take`、`make`、`externalMake` 由 capability lowering 生成。

## Lowering

Capability 到 effect IR 的对应关系：

```text
requires F         -> needs F
input T            -> take T
output T           -> make T
uses S I O         -> uses S + externalMake S I O
onError S I O      -> error S + externalMake S I O
privateFact F      -> private FactProducer F + private boundary fact
produces F         -> FactProducer F
retryOnce S        -> retry S
idempotentPolicy S -> idempotent S
transform A B N    -> transform A B N
```

`pipeline` 描述 artifact 数据流：

```text
UserName -> ReportInput -> ReportOutput
```

相邻节点形成 transform candidate。业务 fact 通过 `requires`、`privateFact`
和 `produces` 声明。

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

`business-syntax-witness` 检查：

```text
ordinary authoring imports use Framework.Ast / Framework.Business / Framework.Handler / Framework.App
Domain.Runtime uses Framework.Handler
app runner uses Framework.App
Effects.* and Domain.Business stay on capability authoring
Bootstrap.* stays out of ordinary business authoring
```

验收和报告层：

```text
SelfDomainApp
Domain.SemanticEvidence
runtime diagnosis witness
domain-app-report
business-syntax-witness itself
```

这些文件可以接触 reporting/evidence API。

## Diagnostics

`Framework.Business.Diagnostics` 把已有的 `RuntimeError` 和 `BusinessShapeIssue`
渲染成业务修复建议。事实来源仍是 runtime、constraint 和 business-shape 结果。

覆盖的常见问题：

```text
declared uses with no registered handler
declared transform with no TransformBinding
missing send boundary
pipeline edge without adjacency
handler binding shape mismatch
capability with no producer or send boundary
```

## Witness

最小业务前台验证：

```powershell
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec domain-app-report -- --json
```

这些命令进入 `check-semantic`。`check-fast` 保持轻量。
