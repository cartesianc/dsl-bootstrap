# Runtime Architecture

本文记录当前 runtime 在框架里的表达方式。核心目标：用两个 backend adapter 验证同一套 workflow/effect 语义，避免形成第二套运行时。

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

两者属于同一 runtime 语义的两个 backend adapter。`Bootstrap.Runtime` 承担自举和证据 backend，`Framework.Runtime` 承担 typed facade backend。两者都从同一个 `AppBlueprint` 和 `EffectTheory` 构建 `NativeAppPlan`，并由 fixed-point witness 比较 Stage 0/Stage 1 证据。

`Framework.Domain.DomainRuntimeBackend` 的主构造器命名为：

```text
DomainBootstrapBackend
DomainTypedRuntimeBackend
```

旧的 `DomainNativeRuntime` / `DomainFrameworkRuntime` 保留为 pattern synonym，用于兼容已有调用。

## 2. Runtime 在 AST 上的表达

framework-core 的 runtime 分支已经拆成多个事实。当前 AST 分支是：

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

fixed-point-smoke backend parity payloads
  runtime-backend-parity-plan
  runtime-backend-parity-fact-closure
  runtime-backend-parity-artifact
  runtime-backend-parity-report
  runtime-backend-parity-claim-manifest

fixed-point-smoke diff evidence payloads
  fixed-point-diff-status
  fixed-point-diff-surface-modules
  fixed-point-diff-surface-capabilities
  fixed-point-diff-constraint-total
  fixed-point-diff-constraint-failed
  fixed-point-diff-declared-facts
  fixed-point-diff-root-facts
  fixed-point-diff-planned-runtime-facts
  fixed-point-diff-final-runtime-facts
  fixed-point-diff-missing-final-facts
  fixed-point-diff-extra-final-facts
  fixed-point-diff-handler-coverage
  fixed-point-diff-artifact-types
  fixed-point-diff-failures
  fixed-point-diff-claim-manifest

RuntimeFactClosureExpressedFact
  needs RuntimeArtifactClosureValidatedFact
  needs RuntimeSendBoundaryCoveredFact
  needs RuntimeEvidencePassedFact
```

runtime 的自表达由 AST facts、effect dependencies、core surface catalog 和 witness evidence 共同闭合。源码文件清单只作为实现输入。

`framework-core-frontend-witness` 检查 AST claim、CoreSurface module、以及 cabal `exposed-modules` 三者同步：

```text
AstStructureExpressedFact -> Framework.Ast
EffectTheoryDslExpressedFact -> Framework.Effect
RuntimeConcurrencySemanticsExpressedFact -> Framework.Runtime.Concurrency
RuntimeDiagnosisExpressedFact -> Framework.Runtime.Diagnosis
RuntimeBackendParityExpressedFact -> Framework.FixedPoint
RuntimeFactClosureExpressedFact -> Framework.Runtime.Evidence
RegistryCodegenExpressedFact -> Framework.RegistryCodegen
SelfArtifactManifestExpressedFact -> Framework.SelfArtifact
```

`framework-core-frontend-witness -- --json` 输出 `framework-core-frontend-evidence.v1`，把 generated source、claim-module link、source-backed CoreSurface module exposed coverage 和 `Framework.Runtime.Diagnosis` implementation boundary 检查写成 payload。

## 4. Runtime 模块边界

`Framework.Runtime` 现在保留为 typed runtime compatibility facade。已拆出的 framework runtime 子模块：

```text
Framework.Runtime.Interpreter
  typed RuntimeM interpreter implementation and app execution entrypoints

Framework.Runtime.State
  runtime state seed and snapshot projection helpers

Framework.Runtime.Types
  shared runtime records, RuntimeError, fact claims, typed values, context events, and diagnosis data types

Framework.Runtime.Diagnosis
  diagnosis builder, RuntimeError attribution, probe completion, payload rendering, and failure diagnosis rendering

Framework.Runtime.Evidence
  top-level runtime evidence payloads over framework-core report facts and artifacts

Framework.Runtime.HotPath
  typed runtime hot-path import and execution guard payloads

Framework.Runtime.Policy
  runtime policy evidence payloads for error dispatch, retry, and idempotency
```

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

## 5. AST context listener

AST layout 和 live cursor 使用同一套 runtime 语义，不引入第三套运行时。

```text
hanging context
  RecursionContextName
  RecursionSchemeModel
  RecursionContextAlgebra
```

`RecursionContextAlgebra` 中的 `EffectSystem` 进入 `NativeAppPlan` validation。带 `listen-during-run` mode 的 context 会让 typed runtime 记录：

```text
RuntimeContextStarted
RuntimeContextCompleted
RuntimeContextNodeEntered
RuntimeContextNodeExited
```

`Framework.Ast.Layout` 把这些 event 投影成 `AstRuntimeCursor`，再用 path 对齐运行前生成的 `AstLayoutModel`。默认 framework-core AST 不自动挂 layout context。

## 6. Artifact gate

当前 artifact gate 会复制 framework/code artifact inputs 到：

```text
.generated/stage1-framework
```

并在隔离 artifact 中运行：

```text
stack build
stack exec core-self-interpret -- --json
stack exec trust-base-manifest-witness -- --evidence-json
stack exec architecture-concern-witness -- --json
```

通过标准：

```text
core-self-interpret-report.v1 passed
core_0/core_1 exchangeability passed
TrustBase manifest evidence passed
architecture concern evidence passed
```

如果本机 HLS 占用默认 `.stack-work` 的 build lock，可以在当前工作树中用隔离目录验证：

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
```

artifact gate 仍然使用 artifact 内部自己的默认 `.stack-work`，不会依赖当前工作树的 `.stack-work-codex`。

说明性文档和维护笔记保留在 repo 中，不进入 Stage 1 framework artifact；artifact gate 不应该因为 README/docs 变更而反复运行。
