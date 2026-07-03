# Trust Base

## 0. Git 发布语义

本仓库的 Git 发布目标：self-iteration framework snapshot。面向业务用户裁剪后的 SDK 不从本仓库发布。一次可发布状态必须证明：

```text
current source
  -> framework-core self-domain expression
  -> TrustBase / Stage 0 bootstrap validation
  -> Stage 1 artifact materialization
  -> fixed-point parity
```

`TrustBase` 是点火和验证下一版 core 的组件：它承接 bootstrap runtime、native runner、typed runtime evidence、diagnosis、constraint proof、registry codegen、fixed point 和 self artifact gate。

关键 gate 的含义：

```text
fixed-point-smoke
  证明 Stage 0 bootstrap backend 和 Stage 1 framework facade 的报告没有语义分裂。

domain-app-report
  证明 framework facade 在 domain-side acceptance app 中可用，handler coverage、proof、semantic evidence 都闭合。

self-artifact-witness
  证明当前 framework/code inputs 能物化隔离的 Stage 1 artifact，并在 artifact 内部重新跑核心 gates。说明性文档保留在 repo，不进入 Stage 1 framework artifact。
```

`self-artifact-witness` 是高危/重型 gate：同一轮大构建完成后最多运行一次；第二次不允许继续跑；README/docs-only 变更不触发它。

本文定义当前自举系统的最小外部信任基。

目标：缩小、命名、报告化 trust base，并让外围语义责任进入 AST / effect / fact / evidence。

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

runtime 语义当前拆为多个 facts：

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
workflow-semantics-witness
runtime-diagnosis-witness
domain-app-report
```

编译期、报告和 gate 可以重复验证。业务执行只运行当前 workflow/effect plan。

## 5. Machine-readable manifest

`Framework.TrustBase.Manifest` 输出当前 trust base 的结构化边界：

```text
trust-base-manifest.v1
host boundary
kernel modules
facade modules
report executables
witness executables
artifact gate executable
artifact sources
artifact commands
```

轻量 witness：

```powershell
stack exec trust-base-manifest-witness
stack exec trust-base-manifest-witness -- --json
```

这条 witness 只读取当前 cabal 和 `defaultSelfArtifactManifest`，检查 manifest 里声明的 module、executable、artifact sources 和 artifact commands 没有漂移。它不物化 Stage 1 artifact，也不执行 `self-artifact-witness`。

## 6. 后续收缩方向

优先收缩 kernel，避免扩大 runtime。

后续可以继续把以下能力移出 trust base：

```text
machine-readable fixed-point diff
concurrency effect-level payload split
JSON schema versioning after v1
artifact runner manifest policy split
```

每次收缩都必须保持：

```powershell
stack build
stack exec bootstrap-report
stack exec fixed-point-smoke
stack exec workflow-semantics-witness
stack exec runtime-diagnosis-witness
stack exec trust-base-manifest-witness
```

高危 artifact gate 只在大构建和轻量 gates 完成后最多运行一次：

```powershell
stack exec self-artifact-witness
```
## 7. Facade 化后的 Trust Base 入口

当前 trust base 不再要求业务或 handler 直接碰 `Framework.Runtime` / `Framework.Background`。

```text
Framework.Ast       业务 AST 前台
Framework.Effect    effect theory 前台
Framework.Business  capability / pipeline 前台
Framework.Handler   handler / transform 实现前台
Framework.TrustBase 架构自我迭代、证据、诊断、fixed point、TrustBase manifest、artifact gate
```

`Framework.TrustBase` 是“允许框架自我迭代触碰的额外组件”，承接 bootstrap runtime、native runner、typed runtime evidence、diagnosis、constraint proof、registry codegen、fixed point、TrustBase manifest 和 self artifact gate。业务热路径不运行这些 evidence；它们只在 witness/report/gate 中运行。

这条边界的目标是把 trust base 命名并缩小：

```text
业务声明不碰 runtime internals
handler 实现不碰 report/proof/codegen
自举证据集中到 Framework.TrustBase
Bootstrap.Runtime.* 继续作为 Stage 0 kernel
Framework.Runtime 继续作为 internal/devtools typed interpreter
```
