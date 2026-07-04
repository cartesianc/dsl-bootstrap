# 常用检查模式与自动化边界

本文记录当前项目的检查命令，以及它们分别证明什么。

当前测试口径已经从“外部 witness 矩阵堆叠可信度”改成：

```text
host build
  证明 Haskell 宿主里的 framework core 可以被编译成可执行程序。

self-interpret proof
  证明已编译的 previous core 能运行候选 core；候选 core 又能作为 domain 前台表达运行自己。

business boundary proof
  证明候选 core 面向业务的 facade、effect、runtime、validator、diagnosis、listener 边界仍然成立。

manifest/schema guardrail
  证明 evidence、schema catalog、cabal executable、TrustBase manifest 和 check script 清单保持同步。

artifact proof
  只在 promotion 轮次使用，证明隔离 Stage1 artifact 里也能重跑同一条 release 证明线。
```

核心结论：普通框架迭代的主证明是 `core-self-interpret-report.v1`，不是旧的 `bootstrap-report`、`fixed-point-smoke`、runtime/business/domain witness 并列矩阵。那些 focused witnesses 仍然保留，但角色变成“业务边界 acceptance / 调试局部语义 / 补充 claim 覆盖”。

## 0. Check Facade

日常优先使用脚本入口：

```powershell
.\scripts\check-fast.cmd
.\scripts\check-semantic.cmd
.\scripts\check-release.cmd
```

当前脚本含义：

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
  与 check-semantic 相同
  默认跳过 self-artifact-witness
```

先查看实际命令清单：

```powershell
.\scripts\check-fast.cmd -List
.\scripts\check-semantic.cmd -List
.\scripts\check-release.cmd -List
```

高危 artifact gate 只在 promotion 轮次显式开启：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

## 1. 自举主轴

普通 architecture iteration 的主轴是：

```text
core_0 -> core_1 -> empty_business
```

其中：

```text
core_0
  已编译的 previous core。

core_1
  当前候选 core，用 EDSL/domain 前台表达出来。

empty_business
  NoInput / Unit acceptance app，用来封口业务参数，防止 core 递归无限下钻。
```

默认命令：

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
```

`core-self-interpret-report.v1` 应覆盖：

```text
previous compiled core runs the new core foreground
new core runs as a domain expression
empty_business closes recursion without IO
TrustBase is non-recursive at terminal business
boot AST layout expands
runtime cursor projects through explicit hanging context
runtime cursor folds into AST node status overlay
listener context stays out of the default hot path
default gate list is collapsed to self-interpret
artifact gate command list is collapsed to self-interpret
core_0 ~= core_1 normalized fixed-point evidence
```

这里的 fixed-point 不是再把 `fixed-point-smoke` 当主测试，而是把 `core_0/core_1` 可交换性放进 self-interpret evidence。`fixed-point-smoke` 仍然可以作为 focused debugging command。

## 2. 业务边界测试

框架本来就有业务边界测试。自举后它们不应该消失，而应该从“平行 release 条件”变成候选 core 之后的 acceptance 线：

```text
core_0 -> core_1 -> boundary_business_suite
```

`empty_business` 只证明递归封口、无 IO 占用、无 TrustBase 泄漏。真正的业务边界仍然由 focused business/domain/runtime witnesses 表达：

```powershell
stack --work-dir .stack-work-codex exec domain-app-report -- --json
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec runtime-evidence-witness -- --json
stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json
```

使用规则：

```text
改 facade / business syntax / capability lowering
  跑 core-self-interpret + business-syntax-witness。

改 workflow AST / EffectTheory / fact closure
  跑 core-self-interpret + workflow-semantics-witness。

改 runtime interpreter / handler / diagnosis
  跑 core-self-interpret + 对应 runtime witness。

改 domain acceptance app
  跑 core-self-interpret + domain-app-report。
```

这些命令证明业务作者只面对 `Framework.*` facade 和 domain-local 模块，不直接碰 `Bootstrap.*`。`domain-app` 仍是 acceptance app，不是 TrustBaseApp，也不是第二个 core。

如果某个业务边界已经被 `core-self-interpret-report.v1` 明确覆盖，就不要再把对应 focused witness 加回默认 release 清单。只有当该边界发生变化、coverage 缺口需要定位、或新增 claim 尚未纳入 self-interpret report 时，才运行 focused witness。

## 3. Runtime 与 Effect 语义

runtime/effect 相关改动的 focused commands：

```powershell
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --runtime-concurrency-json
stack --work-dir .stack-work-codex exec runtime-evidence-witness -- --json
stack --work-dir .stack-work-codex exec runtime-hot-path-witness -- --json
stack --work-dir .stack-work-codex exec runtime-policy-witness -- --json
stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json
```

自动覆盖的代表性边界：

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

这些是局部语义 gate。它们可以证明某一块 runtime/effect 行为，但不替代自举主轴。

## 4. Framework Core 前台与 Codegen

framework-core facade/codegen 改动的 focused commands：

```powershell
stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json
stack --work-dir .stack-work-codex exec registry-codegen-witness -- --json
```

它们检查：

```text
generated frontend sources
AST claim -> CoreSurface module -> cabal exposed-module
source-backed CoreSurface modules -> cabal exposed-modules
Framework.Runtime.Diagnosis implementation boundary
Framework.TrustBase.SelfInterpret public surface
Framework.Ast.Layout runtime cursor/status projection
```

当前自举入口应优先通过 `currentTrustBaseApp` / `core-self-interpret` 观察，而不是只看旧的：

```haskell
frameworkCoreApp =
  baseApp currentTrustBase currentInterpreter currentAst currentEffects
```

`baseApp` 兼容写法可以保留，但 release 语义应落到：

```text
previous core + candidate interpreter + candidate AST + candidate effects
```

## 5. TrustBase、Manifest 与 Schema

TrustBase 和 evidence contract 相关改动优先跑：

```powershell
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec schema-catalog-witness -- --json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

`trust-base-manifest-witness` 自动检查：

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

关键导入边界：

```text
Bootstrap.* 不能导入 Framework.*
domain-app/src 和 domain-app/app 不能导入 Bootstrap.*
new-framework-core/src/Domain 可以用 public facade style 表达 framework-core 自身
```

可以手动快速检查：

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
```

两条命令都应无输出。

当前 schema catalog 至少应覆盖：

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

## 6. AST Layout 与 Live Observation

自举线上的 AST 展开和运行期状态投影用：

```powershell
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-summary
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-layout
stack --work-dir .stack-work-codex exec ast-layout -- self-interpret-live
```

语义分层：

```text
self-interpret-summary
  输出 core_0 -> core_1 -> empty_business 的摘要。

self-interpret-layout
  展开候选 core 的 boot-time AST layout。

self-interpret-live
  用显式 hanging context 监听运行期 cursor，并折叠成 AST node status overlay。
```

listener/context 是 evidence-only 前台，不进入默认 `empty_business` hot path。

## 7. 高危 Artifact Gate

`self-artifact-witness` 是高危/重型 gate，不属于日常检查，也不因为 README/docs-only 变更触发。

允许运行条件：

```text
1. release pre-gate 已通过。
2. 当前 promotion 轮次还没有运行过 self-artifact-witness。
3. 正在准备 framework replacement / artifact manifest 变更 / 重要发布快照。
```

同一轮大构建只允许运行一次。允许运行时使用：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

这条命令会物化当前源码到 `.generated/stage1-framework`，并在隔离 artifact 内重跑同一条 release 证明线：

```text
stack build
core-self-interpret -- --json
trust-base-manifest-witness -- --evidence-json
architecture-concern-witness -- --json
```

它不重新引入旧的 focused witness 矩阵作为 artifact release 条件。

## 8. 推荐检查组合

docs-only 改动：

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

业务 facade / domain acceptance 改动：

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec domain-app-report -- --json
```

manifest/schema/check script 改动：

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

promotion artifact gate：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

## 9. 继续升级方向

后续测试工作不应该扩大默认 witness 矩阵，而应该把长期有效的边界证明迁移成 `core-self-interpret-report.v1` claim：

```text
focused witness proves a boundary
  -> self-interpret report gains the stable claim
  -> focused witness remains for local debugging
  -> default release gate stays small
```

这样测试体系保持同一个含义：编译好的 framework core 能解释候选 core，候选 core 能解释自己，并且候选 core 对业务边界仍然成立。
