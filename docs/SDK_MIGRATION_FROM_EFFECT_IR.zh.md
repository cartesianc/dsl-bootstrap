# 从 Effect IR 迁移到 Capability 写法

旧代码可以直接写 `Framework.Effect` IR。新业务代码建议先写
`Framework.Business` capability，再由 lowering 生成 IR。

## 旧写法

```haskell
Effect.fact ReportGeneratedFact
  [ Effect.needs UserNameAskedFact
  , Effect.take UserName
  , Effect.transform UserName ReportInput UserNameToReportInput
  , Effect.uses GenerateReport
  , Effect.make ReportOutput
  ]
```

## Capability 写法

```haskell
capability "GenerateReport"
  [ requires UserNameAskedFact
  , input UserName
  , pipeline "GenerateReportPipeline" [UserName, ReportInput, ReportOutput]
  , transform (transformBinding UserNameToReportInput UserName ReportInput)
  , uses GenerateReport ReportInput ReportOutput
  , output ReportOutput
  , produces ReportGeneratedFact
  , handler
      (handlerBinding RuntimeGenerateReport "GenerateReport" [ReportInput] [ReportOutput] [ReportGeneratedFact])
  ]
```

## Mapping

```text
needs F             -> requires F
take T              -> input T
make T              -> output T
uses S              -> uses S I O
externalMake S I O  -> generated from uses S I O
transform A B N     -> transform (transformBinding N A B)
fact F              -> produces F or privateFact F
retry S             -> policy (retryOnce S)
idempotent S        -> policy (idempotentPolicy S)
```

## When to Use Each API

```text
Framework.Business
  ordinary business authoring

Framework.Effect
  normalized IR, compatibility code, framework internals, and witnesses
```

For new business modules, start with `Framework.Business`.
