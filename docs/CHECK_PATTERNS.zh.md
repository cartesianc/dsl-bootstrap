# 常用检查模式与自动化边界

本文记录当前项目里常用的检查命令，以及它们分别能自动证明哪些架构边界仍然可用。

这里的“证明”分几种强度：

```text
build proof
  GHC/Stack 能编译整个工程。

semantic closure proof
  workflow AST + effect theory 可以构建 NativeAppPlan，并且 fact closure、artifact closure、send boundary、handler registry 都闭合。

witness proof
  专门 witness executable 跑过代表性语义 claim。

fixed-point proof
  Stage0 bootstrap backend 和 Stage1 framework facade 产物一致。

artifact proof
  当前源码能物化出隔离 Stage1 artifact，并且 artifact 内部也能跑核心 gates。
```

## 1. 快速内圈

日常小改优先跑：

```powershell
stack build
stack exec bootstrap-report
stack exec bootstrap-report -- --json
stack exec trust-base-manifest-witness
stack exec trust-base-manifest-witness -- --json
stack exec fixed-point-smoke
stack exec fixed-point-smoke -- --json
```

这三条覆盖：

```text
stack build
  Haskell 类型、模块导出、可执行程序构建。

bootstrap-report
  core surface formalization
  native proof / constraint report
  fact closure
  runtime artifact closure
  send boundary coverage
  bootstrap handler coverage
  runtime semantic evidence aggregate

fixed-point-smoke
  stage0-bootstrap 与 stage1-framework-facade diff 为 0
  fixed-point diff evidence payload
  runtime backend parity payload
  fixed-point-report.v1 JSON schema
```

当前期望输出：

```text
bootstrap-report: status passed
bootstrap-report --json: framework-core-report.v1
trust-base-manifest-witness: trust-base-manifest.v1
fixed-point-smoke: fixed-point diff evidence 14 payload claims
fixed-point-smoke: diffs: 0
fixed-point-smoke --json: fixed-point-report.v1
```

## 2. Runtime 语义闭包

runtime 相关改动优先跑：

```powershell
stack exec bootstrap-runtime-smoke
stack exec runtime-diagnosis-witness
stack exec runtime-diagnosis-witness -- --json
stack exec workflow-semantics-witness
stack exec workflow-semantics-witness -- --json
stack exec workflow-semantics-witness -- --runtime-concurrency-json
```

自动覆盖的 runtime 边界：

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
RuntimeDiagnosisEvidencePassedFact
RuntimeBackendParityEvidencePassedFact
RuntimeEvidencePassedFact
```

当前 diagnosis 已经继续拆成：

```text
RuntimeErrorDispatchValidatedFact
RuntimeRetryPolicyValidatedFact
RuntimeIdempotencyPolicyValidatedFact
```

这些事实现在已经是 effect graph 里的一级 fact/artifact/send。`runtime-diagnosis-witness` 负责跑对应 3 个代表性 claim：

```text
runtime-diagnosis-error-handler
runtime-diagnosis-retry-probe
runtime-diagnosis-non-idempotent-blocker
```

每个 claim 现在输出 `RuntimeDiagnosisEvidencePayload`：

```text
claim
status
expected
observed
artifact
```

`workflow-semantics-witness` 现在输出 `WorkflowSemanticsEvidencePayload`：

```text
claim
status
expected
observed
artifact
```

JSON schema：

```text
runtime-diagnosis-evidence.v1
workflow-semantics-evidence.v1
runtime-concurrency-evidence.v1
```

`RunRuntimeConcurrencyEvidence` 现在对应 4 条 `RuntimeConcurrencyEvidencePayload`：

```text
runtime-concurrency-parallel-branches
runtime-concurrency-parallel-merge-conflict
runtime-concurrency-race-cancellation
runtime-concurrency-race-exhausted
```

`RunRuntimeDiagnosisEvidence` 现在对应 3 条 `RuntimeDiagnosisEvidencePayload`：

```text
runtime-diagnosis-error-handler
runtime-diagnosis-retry-probe
runtime-diagnosis-non-idempotent-blocker
```

`RunRuntimeBackendParityEvidence` 现在对应 4 条 `RuntimeBackendParityEvidencePayload`：

```text
runtime-backend-parity-plan
runtime-backend-parity-fact-closure
runtime-backend-parity-artifact
runtime-backend-parity-report
```

workflow semantics 已经由 `workflow-semantics-witness` 输出 12 条 payload。

## 3. Framework Core 前台与 Codegen

framework-core facade/codegen 改动优先跑：

```powershell
stack exec framework-core-frontend-witness
stack exec registry-codegen-witness
```

`framework-core-frontend-witness` 同时检查：

```text
generated frontend sources
AST claim -> CoreSurface module -> cabal exposed-module
```

当前自动校验的 link：

```text
AstStructureExpressedFact -> Framework.Ast -> new-framework-core exposed-modules
EffectTheoryDslExpressedFact -> Framework.Effect -> new-framework-core exposed-modules
RuntimeConcurrencySemanticsExpressedFact -> Framework.Runtime.Concurrency -> new-framework-core exposed-modules
RuntimeDiagnosisExpressedFact -> Framework.Runtime.Diagnosis -> new-framework-core exposed-modules
RuntimeBackendParityExpressedFact -> Framework.FixedPoint -> new-framework-core exposed-modules
RegistryCodegenExpressedFact -> Framework.RegistryCodegen -> new-framework-core exposed-modules
SelfArtifactManifestExpressedFact -> Framework.SelfArtifact -> new-framework-core exposed-modules
```

自动覆盖的边界：

```text
FrameworkCore.BaseApp
FrameworkCore.CurrentAst
FrameworkCore.CurrentEffects
FrameworkCore.CurrentInterpreter
FrameworkCore.CurrentApp
```

`framework-core-frontend-witness` 会比较 checked-in frontend 模块和 `Bootstrap.RegistryCodegen` 生成结果。也就是说，语义入口：

```haskell
frameworkCoreApp =
  baseApp currentTrustBase currentInterpreter currentAst currentEffects
```

语义入口已进入生成一致性 witness；README 只做说明。

## 4. Trust Base 与 Bootstrap 边界

`bootstrap-report` 会自动检查：

```text
CheckCoreBoundary
CheckFrontendBoundary
CheckLanguageSpec
CheckElaborationContract
```

`trust-base-manifest-witness` 会自动检查：

```text
TrustBase manifest schema
kernel modules -> cabal exposed-modules
facade modules -> cabal exposed-modules
report/witness/artifact gate executables -> cabal executable names
artifact sources/commands -> defaultSelfArtifactManifest
```

其中关键导入边界是：

```text
Bootstrap.* 不能导入 Framework.*
domain-app/src 和 domain-app/app 不能导入 Bootstrap.*
new-framework-core/src/Domain 可以用 public facade style 表达 framework-core 自身
```

也可以手动快速检查：

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
```

两条命令都应无输出。

## 5. Domain 与业务前台

domain/frontend 改动优先跑：

```powershell
stack exec domain-app-report
stack exec domain-app-self-smoke
stack exec business-syntax-witness
```

自动覆盖：

```text
business frontend shape
Domain.Business source of truth
Effects.* lowering shape
domain self artifact smoke
domain report status
```

这里验证业务作者只面对 `Framework.*` facade 和 domain-local 模块，不直接碰 `Bootstrap.*`。

## 6. 高危 Artifact Gate

`self-artifact-witness` 是高危/重型 gate，不属于日常检查，也不因为 README/docs-only 变更触发。

允许运行条件：

```text
1. 一轮大构建和轻量 gates 已完成。
2. 当前轮还没有运行过 self-artifact-witness。
3. 正在准备 framework replacement / artifact manifest 变更 / 重要发布快照。
```

同一轮大构建只允许运行一次；第二次请求必须拒绝，改为复用第一次结果或重新开始一轮新的大构建。

允许运行时使用：

```powershell
stack exec self-artifact-witness
```

这条命令会：

```text
1. 物化当前源码到 .generated/stage1-framework
2. 在隔离 artifact 内运行 manifest 中的 gates
3. 确认 Stage1 artifact 自己也能构建、报告、fixed point、witness 通过
```

当前 artifact manifest 会在 artifact 内运行：

```text
stack build
stack exec bootstrap-report
stack exec fixed-point-smoke
stack exec constraint-proof-witness -- --smt=auto
stack exec workflow-semantics-witness
stack exec runtime-diagnosis-witness
stack exec framework-core-frontend-witness
stack exec domain-app-report
stack exec registry-codegen-witness
stack exec business-syntax-witness
```

它通常比其他检查慢很多；它会在复制出来的 Stage1 工程里重新跑一整套 gates。日常小改不需要总跑它。

## 7. 推荐检查组合

小改：

```powershell
stack build
stack exec bootstrap-report
```

runtime/effect 语义改动：

```powershell
stack build
stack exec bootstrap-report
stack exec bootstrap-runtime-smoke
stack exec runtime-diagnosis-witness
stack exec workflow-semantics-witness
stack exec fixed-point-smoke
```

framework-core frontend/codegen 改动：

```powershell
stack build
stack exec framework-core-frontend-witness
stack exec trust-base-manifest-witness
stack exec bootstrap-report
stack exec fixed-point-smoke
```

发布或自举 artifact 改动：

```powershell
stack build
```

高危 artifact gate 只在大构建和轻量 gates 完成后最多运行一次：

```powershell
stack exec self-artifact-witness
```

## 8. 目前还没完全自动化的部分

当前已经自动化的是边界闭包、代表性 witness、fixed point 和 artifact gate。

后续还值得继续升级：

```text
TrustBase manifest 的 schema versioning 和 gate policy 分层
```

这不会改变业务运行热路径；这些检查仍然属于 report/witness/gate 编译验证路径。
