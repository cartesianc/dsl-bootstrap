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

## 0. Check Facade

日常检查优先使用脚本入口：

```powershell
.\scripts\check-fast.cmd
.\scripts\check-semantic.cmd
.\scripts\check-release.cmd
```

```text
check-fast
  build
  framework-core frontend witness
  business syntax witness
  runtime hot-path payload
  runtime policy payload
  runtime diagnosis payload
  trust-base-manifest evidence JSON

check-semantic
  check-fast 范围
  domain-app report JSON
  workflow semantics payload
  runtime concurrency payload

check-release
  semantic gates
  bootstrap-report JSON
  runtime-evidence JSON
  runtime-hot-path JSON
  runtime-policy JSON
  fixed-point summary JSON
  domain-app acceptance
  registry/codegen witness
  business syntax witness
  constraint proof
```

`check-release` 默认跳过 `self-artifact-witness`。高危 artifact gate 需要显式开关：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

先查看命令清单：

```powershell
.\scripts\check-release.cmd -List
```

## 1. 快速内圈

日常小改优先跑：

```powershell
stack build
stack exec framework-core-frontend-witness -- --json
stack exec business-syntax-witness
stack exec business-syntax-witness -- --json
stack exec runtime-hot-path-witness -- --json
stack exec runtime-policy-witness -- --json
stack exec runtime-diagnosis-witness -- --json
stack exec trust-base-manifest-witness
stack exec trust-base-manifest-witness -- --json
stack exec trust-base-manifest-witness -- --evidence-json
```

这些命令覆盖：

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
  runtime semantic evidence payload

fixed-point-smoke
  stage0-bootstrap 与 stage1-framework-facade diff 为 0
  fixed-point diff evidence payload
  runtime backend parity payload
  fixed-point-report.v1 JSON schema
  fixed-point-summary.v1 compact JSON schema
```

当前期望输出：

```text
bootstrap-report: status passed
bootstrap-report --json: framework-core-report.v1
runtime-evidence-witness: ok runtime evidence 7 payload claims
runtime-evidence-witness --json: runtime-evidence.v1
runtime-hot-path-witness: ok runtime hot-path evidence 3 payload claims
runtime-hot-path-witness --json: runtime-hot-path-evidence.v1
runtime-policy-witness: ok runtime policy evidence 4 payload claims
runtime-policy-witness --json: runtime-policy-evidence.v1
framework-core-frontend-witness --json: framework-core-frontend-evidence.v1
business-syntax-witness -- --json: business-syntax-evidence.v1
trust-base-manifest-witness: trust-base-manifest.v2
trust-base-manifest-witness -- --evidence-json: trust-base-manifest-evidence.v1
schema-catalog-witness -- --json: schema-catalog-evidence.v1
constraint-proof-witness -- --smt=off --json: constraint-proof-evidence.v1
registry-codegen-witness -- --json: registry-codegen-evidence.v1
architecture-concern-witness -- --json: architecture-concern-evidence.v1
fixed-point-smoke: fixed-point diff evidence 15 payload claims
fixed-point-smoke: diffs: 0
fixed-point-smoke --json: fixed-point-report.v1
fixed-point-smoke --summary-json: fixed-point-summary.v1
```

`bootstrap-report -- --json` 和 `domain-app-report -- --json` 输出 report 后会检查 `status`；`failed` 会让命令返回非零退出码。

## 2. Runtime 语义闭包

runtime 相关改动优先跑：

```powershell
stack exec bootstrap-runtime-smoke
stack exec runtime-evidence-witness
stack exec runtime-evidence-witness -- --json
stack exec runtime-hot-path-witness
stack exec runtime-hot-path-witness -- --json
stack exec runtime-policy-witness
stack exec runtime-policy-witness -- --json
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

这些事实现在已经是 effect graph 里的一级 fact/artifact/send。`runtime-diagnosis-witness` 负责跑对应的代表性 claim：

```text
runtime-diagnosis-error-handler
runtime-diagnosis-retry-probe
runtime-diagnosis-non-idempotent-blocker
runtime-diagnosis-system-root-cause
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
runtime-evidence.v1
runtime-hot-path-evidence.v1
runtime-policy-evidence.v1
framework-core-frontend-evidence.v1
schema-catalog-evidence.v1
constraint-proof-evidence.v1
runtime-diagnosis-evidence.v1
registry-codegen-evidence.v1
workflow-semantics-evidence.v1
runtime-concurrency-evidence.v1
architecture-concern-evidence.v1
```

schema catalog witness payload claims 包含每个 schema 输出检查：
```text
schema-catalog-output:framework-core-report.v1
schema-catalog-output:domain-report.v1
schema-catalog-output:ast-tree.v1
schema-catalog-output:domain-registry.v1
schema-catalog-output:domain-map.v1
schema-catalog-output:fixed-point-report.v1
schema-catalog-output:fixed-point-summary.v1
schema-catalog-output:framework-core-frontend-evidence.v1
schema-catalog-output:trust-base-manifest.v2
schema-catalog-output:trust-base-manifest-evidence.v1
schema-catalog-output:schema-catalog-evidence.v1
schema-catalog-output:constraint-proof-evidence.v1
schema-catalog-output:business-syntax-evidence.v1
schema-catalog-output:runtime-evidence.v1
schema-catalog-output:runtime-hot-path-evidence.v1
schema-catalog-output:runtime-policy-evidence.v1
schema-catalog-output:runtime-diagnosis-evidence.v1
schema-catalog-output:registry-codegen-evidence.v1
schema-catalog-output:workflow-semantics-evidence.v1
schema-catalog-output:runtime-concurrency-evidence.v1
schema-catalog-output:architecture-concern-evidence.v1
schema-catalog-claim-manifest
```

`RunRuntimeEvidence` 现在对应 7 条 `RuntimeEvidencePayload`：

```text
runtime-plan-build-evidence
runtime-validation-evidence
runtime-execution-evidence
runtime-concurrency-evidence
runtime-diagnosis-evidence
runtime-backend-parity-evidence
runtime-evidence-claim-manifest
```

`RunRuntimeConcurrencyEvidence` 现在对应 5 条 `RuntimeConcurrencyEvidencePayload`：

```text
runtime-concurrency-parallel-branches
runtime-concurrency-parallel-merge-conflict
runtime-concurrency-race-cancellation
runtime-concurrency-race-exhausted
runtime-concurrency-claim-manifest
```

`RunRuntimeDiagnosisEvidence` 现在对应 4 条 `RuntimeDiagnosisEvidencePayload`：

```text
runtime-diagnosis-error-handler
runtime-diagnosis-retry-probe
runtime-diagnosis-non-idempotent-blocker
runtime-diagnosis-system-root-cause
```

`domain-app-report -- --json` 会把 semanticEvidence 放进 `semanticEvidence.payload`，字段为 `claim/status/expected/observed/artifact`；`details` 保留给文本阅读。

当前 domain-app semanticEvidence payload 覆盖：

```text
constraint-ir-built
constraint-proof-passed
constraint-negative-check
runtime-closure-executed
runtime-diagnosis-error-handler
runtime-diagnosis-retry-probe
runtime-diagnosis-non-idempotent-blocker
runtime-diagnosis-system-root-cause
registry-codegen-plugins
registry-codegen-effects
```

`RunRuntimeBackendParityEvidence` 现在对应 4 条 `RuntimeBackendParityEvidencePayload`：

```text
runtime-backend-parity-plan
runtime-backend-parity-fact-closure
runtime-backend-parity-artifact
runtime-backend-parity-report
runtime-backend-parity-claim-manifest
```

workflow semantics 已经由 `workflow-semantics-witness` 输出 14 条 payload。

## 3. Framework Core 前台与 Codegen

framework-core facade/codegen 改动优先跑：

```powershell
stack exec framework-core-frontend-witness -- --json
stack exec registry-codegen-witness -- --json
```

registry codegen witness payload claims：
```text
registry-codegen-plugins
registry-codegen-effects
registry-codegen-claim-manifest
```

`framework-core-frontend-witness` 同时检查：

```text
generated frontend sources
AST claim -> CoreSurface module -> cabal exposed-module
source-backed CoreSurface modules -> cabal exposed-modules
Framework.Runtime.Diagnosis implementation boundary
```

`--json` 输出 `framework-core-frontend-evidence.v1`，每条 payload 都包含 `claim`、`status`、`expected`、`observed` 和 `artifact` 字段。

当前自动校验的 link：

```text
AstStructureExpressedFact -> Framework.Ast -> new-framework-core exposed-modules
EffectTheoryDslExpressedFact -> Framework.Effect -> new-framework-core exposed-modules
RuntimeConcurrencySemanticsExpressedFact -> Framework.Runtime.Concurrency -> new-framework-core exposed-modules
RuntimeDiagnosisExpressedFact -> Framework.Runtime.Diagnosis -> new-framework-core exposed-modules
RuntimeBackendParityExpressedFact -> Framework.FixedPoint -> new-framework-core exposed-modules
RuntimeFactClosureExpressedFact -> Framework.Runtime.Evidence -> new-framework-core exposed-modules
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
TrustBase manifest evidence schema
kernel modules -> cabal exposed-modules
facade modules -> cabal exposed-modules
report/witness/artifact gate executables -> cabal executable names
artifact sources/commands -> defaultSelfArtifactManifest
json schemas -> TrustBase schema catalog
gate policies -> check script -List output
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
.\scripts\check-release.cmd -IncludeSelfArtifact
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
stack exec runtime-evidence-witness
stack exec constraint-proof-witness -- --smt=auto
stack exec workflow-semantics-witness
stack exec runtime-diagnosis-witness
stack exec framework-core-frontend-witness -- --json
stack exec domain-app-report
stack exec registry-codegen-witness -- --json
stack exec architecture-concern-witness -- --json
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
stack exec framework-core-frontend-witness -- --json
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
.\scripts\check-release.cmd -IncludeSelfArtifact
```

## 8. 目前还没完全自动化的部分

当前已经自动化的是边界闭包、代表性 witness、fixed point 和 artifact gate。

后续还值得继续升级：

```text
artifact runner manifest policy split
```

这不会改变业务运行热路径；这些检查仍然属于 report/witness/gate 编译验证路径。
