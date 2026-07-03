# Trust Base

本文定义当前自举系统的最小外部信任基。

目标不是消灭 trust base，而是把它缩小、命名、报告化，并让它之外的语义责任进入 AST / effect / fact / evidence。

## 1. 分层

```text
Host Trust Base
  GHC / Stack / OS / 文件系统 / process / 终端编码

Bootstrap Kernel
  最小 AST/effect/fact closure 解释器
  NativeAppPlan 构建
  external boundary 调用
  evidence artifact 带回语义层

Semantic World
  workflow 语义
  runtime execution/concurrency/diagnosis/parity
  registry codegen
  self artifact gate
  reports 和 fixed-point evidence
```

## 2. 当前最小 Kernel

当前 kernel 位于 `Bootstrap.Runtime` facade 下，并由子模块表达职责：

```text
Bootstrap.Runtime.Types
  NativeAppPlan、NativeRuntime、NativeFactRule、SendContract、RuntimeArtifact

Bootstrap.Runtime.Build
  Workflow AST + EffectTheory -> NativeAppPlan
  fact rule / send contract / native constraint 构建

Bootstrap.Runtime.Contract
  runtime contract layer
  plan built / fact rule closure / artifact closure / send coverage
  handler registry / transform registry validation

Bootstrap.Runtime.Interpreter
  最小 native workflow/fact closure 解释器
  chain / parallel / fallback / race / choice / wait
  needs / take / make / uses closure

Bootstrap.Runtime.BootstrapHandlers
  framework-core bootstrap send boundaries
  host IO boundary
  evidence artifact producer
```

这些模块是当前 Stage 0 点火器。它们可以在 AST 外，但必须被 core surface、boundary check、report、fixed-point gate 追踪。

## 3. 语义责任规则

实现代码可以在 AST 外。

语义责任不能无名地留在 AST 外。

每个影响框架承诺的能力必须至少有一个 semantic handle：

```text
fact
effect dependency
send boundary
evidence artifact
witness/report gate
```

例如 runtime 不是只用一个粗事实表达。当前拆为：

```text
RuntimePlanBuiltFact
RuntimeFactRuleClosureValidatedFact
RuntimeArtifactClosureValidatedFact
RuntimeSendBoundaryCoveredFact
RuntimeHandlerRegistryValidatedFact
RuntimeTransformRegistryValidatedFact
RuntimePlanBuildEvidencePassedFact
RuntimeValidationEvidencePassedFact
RuntimeExecutionEvidencePassedFact
RuntimeConcurrencyEvidencePassedFact
RuntimeErrorDispatchValidatedFact
RuntimeRetryPolicyValidatedFact
RuntimeIdempotencyPolicyValidatedFact
RuntimeDiagnosisEvidencePassedFact
RuntimeBackendParityEvidencePassedFact
RuntimeEvidencePassedFact
```

`RuntimeEvidencePassedFact` 是兼容聚合事实。细粒度事实用于定位哪一片 runtime 语义没有闭合。

## 4. 性能边界

业务 runtime 热路径不运行自举 evidence。

以下入口可以运行 evidence：

```text
bootstrap-report
fixed-point-smoke
self-artifact-witness
workflow-semantics-witness
runtime-diagnosis-witness
domain-app-report
```

编译期、报告和 gate 可以重复验证。业务执行只运行当前 workflow/effect plan。

## 5. 后续收缩方向

优先收缩 kernel，而不是扩大 runtime。

后续可以继续把以下能力移出 trust base：

```text
workflow semantics witness payload
runtime diagnosis evidence payload
backend parity evidence payload
machine-readable fixed-point diff
artifact runner manifest validation
```

每次收缩都必须保持：

```powershell
stack build
stack exec bootstrap-report
stack exec fixed-point-smoke
stack exec workflow-semantics-witness
stack exec runtime-diagnosis-witness
stack exec self-artifact-witness
```
## 6. Facade 化后的 Trust Base 入口

当前 trust base 不再要求业务或 handler 直接碰 `Framework.Runtime` / `Framework.Background`。

```text
Framework.Ast       业务 AST 前台
Framework.Effect    effect theory 前台
Framework.Business  capability / pipeline 前台
Framework.Handler   handler / transform 实现前台
Framework.TrustBase 架构自我迭代、证据、诊断、fixed point、artifact gate
```

`Framework.TrustBase` 是“允许框架自我迭代触碰的额外组件”，承接 bootstrap runtime、native runner、typed runtime evidence、diagnosis、constraint proof、registry codegen、fixed point 和 self artifact gate。业务热路径不运行这些 evidence；它们只在 witness/report/gate 中运行。

这条边界的目标是把 trust base 命名并缩小：

```text
业务声明不碰 runtime internals
handler 实现不碰 report/proof/codegen
自举证据集中到 Framework.TrustBase
Bootstrap.Runtime.* 继续作为 Stage 0 kernel
Framework.Runtime 继续作为 internal/devtools typed interpreter
```
