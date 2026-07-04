# 检查模式

本文记录 framework 自举、业务边界和 promotion gate 的检查入口。

## 1. 证明层级

```text
host build
  Haskell/Stack 可编译当前工作树。

self-interpret proof
  compiled core_0 运行候选 core_1；core_1 以 domain 前台表达自身。

business boundary proof
  候选 core 的 facade、effect、runtime、validator、diagnosis 和 listener 边界可用于业务。

manifest/schema guardrail
  evidence、schema catalog、cabal executable、TrustBase manifest 和脚本清单同步。

artifact proof
  promotion 轮次物化 Stage1 artifact，并在 artifact 内重跑 release proof。
```

## 2. 脚本入口

```powershell
.\scripts\check-fast.cmd
.\scripts\check-semantic.cmd
.\scripts\check-release.cmd
```

展开清单：

```powershell
.\scripts\check-fast.cmd -List
.\scripts\check-semantic.cmd -List
.\scripts\check-release.cmd -List
```

当前脚本：

```text
check-fast
  stack build
  core-self-interpret -- --json

check-semantic
  stack build
  core-self-interpret -- --json
  trust-base-manifest-witness -- --evidence-json
  architecture-concern-witness -- --json

check-release
  stack build
  core-self-interpret -- --json
  trust-base-manifest-witness -- --evidence-json
  architecture-concern-witness -- --json
```

Promotion artifact gate：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

## 3. 自举主轴

```text
core_0 -> core_1 -> empty_business
```

```text
core_0
  上一轮已编译 core，本轮 TrustBase。

core_1
  当前候选 core，以 EDSL/domain 前台表达。

empty_business
  NoInput / Unit acceptance app，封闭候选 core 的业务参数。
```

默认验证：

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
```

`core-self-interpret-report.v1` 覆盖：

```text
previous compiled core runs candidate core foreground
candidate core runs as a domain expression
empty_business closes recursion without IO
TrustBase is non-recursive at terminal business
boot AST layout expands
boot AST DAG + occurrence index equivalence proof passes
runtime cursor projects through explicit hanging context
runtime cursor folds into AST node status overlay
listener context stays out of default hot path
gate command lists are consolidated
core_0 ~= core_1 normalized fixed-point evidence
```

## 4. 业务边界

业务边界验收线：

```text
core_0 -> core_1 -> boundary_business_suite
```

常用 focused witnesses：

```powershell
stack --work-dir .stack-work-codex exec domain-app-report -- --json
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec runtime-evidence-witness -- --json
stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json
```

选择规则：

```text
facade / business syntax / capability lowering
  core-self-interpret + business-syntax-witness

workflow AST / EffectTheory / fact closure
  core-self-interpret + workflow-semantics-witness

runtime interpreter / handler / diagnosis
  core-self-interpret + 对应 runtime witness

domain acceptance app
  core-self-interpret + domain-app-report
```

`domain-app` 是 acceptance app；`TrustBaseApp` 属于 framework 自举入口。

## 5. Runtime 与 Effect

```powershell
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --runtime-concurrency-json
stack --work-dir .stack-work-codex exec runtime-evidence-witness -- --json
stack --work-dir .stack-work-codex exec runtime-hot-path-witness -- --json
stack --work-dir .stack-work-codex exec runtime-policy-witness -- --json
stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json
```

代表性 facts：

```text
RuntimePlanBuiltFact
RuntimeFactRuleClosureValidatedFact
RuntimeArtifactClosureValidatedFact
RuntimeSendBoundaryCoveredFact
RuntimeHandlerRegistryValidatedFact
RuntimeTransformRegistryValidatedFact
RuntimeExecutionEvidencePassedFact
RuntimeConcurrencyEvidencePassedFact
RuntimeDiagnosisEvidencePassedFact
RuntimeBackendParityEvidencePassedFact
```

## 6. Framework Core 前台与 Codegen

```powershell
stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json
stack --work-dir .stack-work-codex exec registry-codegen-witness -- --json
```

检查内容：

```text
generated frontend sources
AST claim -> CoreSurface module -> cabal exposed-module
source-backed CoreSurface modules -> cabal exposed-modules
Framework.Runtime.Diagnosis implementation boundary
Framework.TrustBase.SelfInterpret public surface
Framework.Ast.Layout runtime cursor/status projection
```

自举入口字段：

```text
previous core
candidate interpreter
candidate AST
candidate effects
```

## 7. TrustBase、Manifest 与 Schema

```powershell
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec schema-catalog-witness -- --json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

`trust-base-manifest-witness` 检查：

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

导入边界：

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
```

两个命令应无输出。

Schema catalog 包含：

```text
core-self-interpret-report.v1
framework-core-report.v1
domain-report.v1
ast-tree.v1
domain-registry.v1
domain-map.v1
fixed-point-report.v1
fixed-point-summary.v1
framework-core-frontend-evidence.v1
trust-base-manifest.v2
trust-base-manifest-evidence.v1
schema-catalog-evidence.v1
constraint-proof-evidence.v1
business-syntax-evidence.v1
runtime-evidence.v1
runtime-hot-path-evidence.v1
runtime-policy-evidence.v1
runtime-diagnosis-evidence.v1
registry-codegen-evidence.v1
workflow-semantics-evidence.v1
runtime-concurrency-evidence.v1
architecture-concern-evidence.v1
```

## 8. AST Layout 与 Live Observation

```powershell
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-summary
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-layout
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-dag
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-live
```

```text
self-interpret-summary
  core_0 -> core_1 -> empty_business 摘要。

self-interpret-layout
  候选 core 的 boot-time AST layout。

self-interpret-dag
  boot-time AST DAG sample, occurrence index summary, and equivalence proof constraints.

self-interpret-live
  hanging context runtime cursor 与 AST node status overlay。
```

## 9. Promotion Artifact Gate

运行条件：

```text
release pre-gate passed
same HEAD has not run self-artifact-witness in this round
promotion/replacement round
```

命令：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

artifact 内部命令：

```text
stack build
core-self-interpret -- --json
trust-base-manifest-witness -- --evidence-json
architecture-concern-witness -- --json
```

## 10. 推荐组合

docs-only：

```powershell
git diff --check
rg -n "旧命令或旧 claim 名" docs README.md codex-skills
```

普通 framework 小改：

```powershell
.\scripts\check-fast.cmd
```

runtime/effect 语义改动：

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
```

业务 facade / domain acceptance：

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec domain-app-report -- --json
```

manifest/schema/check script：

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec schema-catalog-witness -- --json
```

release pre-gate：

```powershell
.\scripts\check-release.cmd
```
