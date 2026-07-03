# Runtime Architecture

本文记录当前 runtime 在框架里的表达方式。这里的重点不是引入第二套运行时，而是把同一套 workflow/effect 语义分成两个 backend adapter 来验证。

## 1. 一个语义，两个 backend

当前框架只有一套语义来源：

```text
Workflow AST
  + EffectTheory
  + NativeAppPlan
  + runtime fact closure
```

代码里有两个执行 backend：

```text
Bootstrap backend
  模块入口: Bootstrap.Runtime
  用途: framework-core 自举、边界检查、报告、fixed-point Stage 0。

Typed runtime backend
  模块入口: Framework.Runtime
  用途: public facade/domain 使用 RuntimeM、typed value、handler/transform registry 运行同一套 plan。
```

它们不是两套互相竞争的 runtime。`Bootstrap.Runtime` 是自举和证据 backend，`Framework.Runtime` 是 typed facade backend。两者都从同一个 `AppBlueprint` 和 `EffectTheory` 构建 `NativeAppPlan`，并由 fixed-point witness 比较 Stage 0/Stage 1 证据。

`Framework.Domain.DomainRuntimeBackend` 的主构造器命名为：

```text
DomainBootstrapBackend
DomainTypedRuntimeBackend
```

旧的 `DomainNativeRuntime` / `DomainFrameworkRuntime` 保留为 pattern synonym，用于兼容已有调用。

## 2. Runtime 在 AST 上的表达

framework-core 的 runtime 分支已经不是单个大事实。当前 AST 分支是：

```text
RuntimeBranchExpressionFlow
  parallel ValidateRuntimeFlow
    RuntimeTypesExpressedFact
    RuntimePlanBuildExpressedFact
    RuntimeValidationExpressedFact
    RuntimeExecutionSemanticsExpressedFact
    RuntimeConcurrencySemanticsExpressedFact
    RuntimeDiagnosisExpressedFact
    RuntimeBackendAdapterExpressedFact
    RuntimeBackendParityExpressedFact
  RuntimeInterpreterExpressedFact
  RuntimeFactClosureExpressedFact
```

汇总事实仍然保留：

```text
RuntimeInterpreterExpressedFact
RuntimeFactClosureExpressedFact
```

这样做的目的，是让旧报告和 fixed-point 比较保持稳定，同时让 runtime 分支的内部能力可以被 core expression 层更细粒度地追踪。

## 3. Effect closure

`CoreExpressionEffect` 描述这些 runtime facts 的依赖：

```text
RuntimeTypesExpressedFact
  needs CoreSurfaceFormalizedFact

RuntimePlanBuildExpressedFact
  needs MinimalCoreReportBuiltFact
  needs RuntimePlanBuiltFact
  needs RuntimeFactRuleClosureValidatedFact
  needs RuntimeArtifactClosureValidatedFact
  needs RuntimeSendBoundaryCoveredFact
  needs RuntimePlanBuildEvidencePassedFact

RuntimeValidationExpressedFact
  needs MinimalCoreReportBuiltFact
  needs ConstraintIRBuiltFact
  needs SmtProofPassedFact
  needs RuntimeFactRuleClosureValidatedFact
  needs RuntimeArtifactClosureValidatedFact
  needs RuntimeValidationEvidencePassedFact

RuntimeExecutionSemanticsExpressedFact
RuntimeConcurrencySemanticsExpressedFact
  needs Runtime*EvidencePassedFact

RuntimeDiagnosisExpressedFact
  needs RuntimeErrorDispatchValidatedFact
  needs RuntimeRetryPolicyValidatedFact
  needs RuntimeIdempotencyPolicyValidatedFact
  needs RuntimeDiagnosisEvidencePassedFact

RuntimeBackendAdapterExpressedFact
  needs CoreSurfaceFormalizedFact
  needs RuntimeHandlerRegistryValidatedFact
  needs RuntimeTransformRegistryValidatedFact
  needs RuntimeExecutionEvidencePassedFact

RuntimeBackendParityExpressedFact
  needs CoreSurfaceFormalizedFact
  needs RuntimeBackendParityEvidencePassedFact

RuntimeFactClosureExpressedFact
  needs RuntimeArtifactClosureValidatedFact
  needs RuntimeSendBoundaryCoveredFact
  needs RuntimeEvidencePassedFact
```

这说明 runtime 的自表达不是源码文件清单本身，而是由 AST facts、effect dependencies、core surface catalog 和 witness evidence 共同闭合。

## 4. Runtime 模块边界

`Bootstrap.Runtime` 现在保留为兼容 facade 和 bootstrap backend 入口。已拆出的子模块：

```text
Bootstrap.Runtime.Types
  HandlerRegistry
  RuntimeArtifact
  NativeRuntime
  NativeAppPlan
  SendContract
  NativeFactRule
  NativeConstraint

Bootstrap.Runtime.SourceGraph
  SourceImportGraph
  SourceModule
  readSourceImportGraph

Bootstrap.Runtime.Boundary
  core/frontend boundary policy
  language spec check
  elaboration contract check
  source root declarations

Bootstrap.Runtime.Build
  Workflow AST + EffectTheory -> NativeAppPlan
  fact rule / send contract / native constraint build

Bootstrap.Runtime.Contract
  plan built / fact rule closure / artifact closure
  send boundary coverage
  handler registry / transform registry validation

Bootstrap.Runtime.Interpreter
  native workflow/fact closure interpreter

Bootstrap.Runtime.BootstrapHandlers
  bootstrap send boundary dispatcher
```

后续继续拆分时，建议保持这个方向：

```text
Bootstrap.Runtime.Concurrent
Bootstrap.Runtime.EvidencePayload
Bootstrap.Runtime.Policy
```

每一步都应只搬移职责，不改变 `Workflow` 语义和 `EffectTheory` 闭包。

## 5. Artifact gate

当前 artifact gate 会复制 framework/code artifact inputs 到：

```text
.generated/stage1-framework
```

并在隔离 artifact 中运行：

```text
stack build
stack exec bootstrap-report
stack exec fixed-point-smoke
stack exec constraint-proof-witness -- --smt=auto
stack exec workflow-semantics-witness
stack exec domain-app-report
stack exec registry-codegen-witness
stack exec business-syntax-witness
```

通过标准：

```text
bootstrap report passed
fixed-point diffs: 0
workflow semantics witness passed
domain-app report passed
registry codegen witness passed
business syntax witness passed
```

如果本机 HLS 占用默认 `.stack-work` 的 build lock，可以在当前工作树中用隔离目录验证：

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec fixed-point-smoke
```

artifact gate 仍然使用 artifact 内部自己的默认 `.stack-work`，不会依赖当前工作树的 `.stack-work-codex`。

说明性文档和维护笔记保留在 repo 中，不进入 Stage 1 framework artifact；artifact gate 不应该因为 README/docs 变更而反复运行。
