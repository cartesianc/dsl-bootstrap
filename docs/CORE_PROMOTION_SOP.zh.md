# Core Promotion SOP

本文定义候选 framework core 晋升为下一轮 TrustBase 的流程。

适用范围：

```text
new-framework-core/src/Domain
new-framework-core/src/FrameworkCore
Framework.TrustBase
artifact gate
check scripts
```

## 1. 候选对象

候选 core 由当前源码表达：

```text
Domain-as-core expression
  new-framework-core/src/Domain

Readable core frontend
  new-framework-core/src/FrameworkCore

TrustBase self-interpret entry
  Framework.TrustBase.SelfInterpret
```

候选 core 的验证线：

```text
core_0 -> core_1 -> empty_business
```

Promotion 后：

```text
core_1 -> core_2 -> empty_business
```

## 2. 语义风险

以下改动属于 semantic-risk：

```text
AST constructor / hanging branch / recursion context
capability authoring surface
effect/fact vocabulary
lowering rule
runtime interpreter semantics
handler / transform boundary
CoreSurface exposed module or capability catalog
TrustBase manifest
self-artifact manifest
witness payload schema
fixed-point diff key
artifact source list
```

semantic-risk 改动需要对应的 fact、effect、witness claim 或 schema evidence。

文档、README、说明性注释、命令索引变更不触发 artifact gate。

## 3. Release Pre-gate

目标提交先运行：

```powershell
.\scripts\check-release.cmd
```

展开命令：

```text
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

通过条件：

```text
build passed
core-self-interpret-report.v1 passed
core_0/core_1 exchangeability passed
TrustBase manifest evidence passed
architecture guardrail passed
```

## 4. Focused Witnesses

Focused witnesses 用于定位具体边界：

```powershell
stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec domain-app-report -- --json
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec runtime-evidence-witness -- --json
stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json
stack --work-dir .stack-work-codex exec schema-catalog-witness -- --json
stack --work-dir .stack-work-codex exec registry-codegen-witness -- --json
```

运行选择见 [CHECK_PATTERNS.zh.md](CHECK_PATTERNS.zh.md)。

## 5. Boundary Checks

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
```

两个命令应无输出。

## 6. Artifact Gate

Promotion artifact gate：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

运行条件：

```text
release pre-gate passed
same HEAD has no recorded self-artifact-witness run in this round
current round is a promotion/replacement round
```

Stage1 artifact：

```text
.generated/stage1-framework
```

Artifact 内部命令：

```text
stack build
core-self-interpret -- --json
trust-base-manifest-witness -- --evidence-json
architecture-concern-witness -- --json
```

通过条件：

```text
artifact created
artifact build passed
artifact core-self-interpret passed
artifact TrustBase manifest evidence passed
artifact architecture guardrail passed
artifact command list matches defaultSelfArtifactManifest
```

超时状态记为 inconclusive。

## 7. Replacement Decision

允许替换当前 core 的证据：

```text
release pre-gate: passed
artifact gate: passed
boundary checks: passed
git diff: scoped to current round
target commit recorded
```

建议提交顺序：

```text
commit 1: introduce verified candidate core
commit 2: replace previous core with verified candidate
```

artifact gate failed、timeout 或 evidence 缺失时，保留当前 core。

## 8. Evidence Record

每次 promotion 记录：

```text
target commit
semantic-risk scope
commands run
core-self-interpret result
core_0/core_1 exchangeability result
TrustBase manifest result
architecture guardrail result
self-artifact-witness result
artifact path
replacement decision
```
