# Domain Framework 晋升 Core Framework SOP

本文定义 `domain framework` 晋升为可替换 `core framework` 的流程。

适用范围：

```text
new-framework-core/src/Domain
new-framework-core/src/FrameworkCore
domain-app
TrustBase
artifact gate
```

这份 SOP 关注 core promotion。`docs/SELF_BOOTSTRAP_GATE.md` 继续定义 self-bootstrap gate 细节。

## 1. 晋升对象

候选 core 必须同时满足三条线：

```text
Domain-as-core expression
  new-framework-core/src/Domain 用 facade style 表达当前 framework-core。

Readable current core frontend
  new-framework-core/src/FrameworkCore 提供 currentTrustBase / currentAst / currentEffects / currentInterpreter / currentApp。

Domain-side acceptance
  domain-app 验证 Framework.* facade、handler implementation、semantic evidence 和 report 可以在 domain 侧闭合。
```

这三条线都通过后，候选 core 才进入 replacement gate。

## 2. 开工前语义风险复核

开始修改前先判断本轮是否会改变架构语义。以下改动属于 semantic-risk：

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

semantic-risk 改动需要先写清楚预期语义，再改代码，并为对应 witness 增加或更新 claim。

文档、README、说明性注释、命令索引只改变阅读材料时，不触发 `self-artifact-witness`。

## 3. Facade Conformance

候选 core 必须证明自身语义能从 facade 被索引到：

```powershell
stack --work-dir .stack-work-codex exec framework-core-frontend-witness -- --json
```

如果触碰 capability / lowering / business authoring surface，再运行：

```powershell
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
```

边界检查：

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
```

两个命令应无输出。

## 4. Semantic Witness

候选 core 触碰哪一块语义，就运行对应 witness。常用组合：

```powershell
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec runtime-evidence-witness -- --json
stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json
stack --work-dir .stack-work-codex exec constraint-proof-witness -- --smt=auto
stack --work-dir .stack-work-codex exec registry-codegen-witness -- --json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

通过标准：

```text
相关 claim status 全部 passed
claim manifest 与导出清单同步
新增语义有对应 fact / effect / witness handle
```

## 5. Fixed-point

候选 core 必须证明 Stage 0 和 Stage 1 没有语义分裂：

```powershell
stack --work-dir .stack-work-codex exec bootstrap-report
stack --work-dir .stack-work-codex exec fixed-point-smoke
```

通过标准：

```text
bootstrap-report: status passed
fixed-point-smoke: diffs: 0
```

如果本轮修改 JSON schema、report payload 或 fixed-point diff key，再运行对应 JSON 输出：

```powershell
stack --work-dir .stack-work-codex exec bootstrap-report -- --json
stack --work-dir .stack-work-codex exec fixed-point-smoke -- --json
stack --work-dir .stack-work-codex exec fixed-point-smoke -- --summary-json
```

## 6. TrustBase

候选 core 必须证明 TrustBase 边界没有漂移：

```powershell
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec schema-catalog-witness -- --json
```

通过标准：

```text
TrustBase manifest 覆盖当前 module / executable / artifact source / gate policy
schema catalog 覆盖当前 machine-readable report 和 witness payload
self-artifact manifest 没有未声明的 source 或 command 漂移
```

`schema-catalog-witness -- --json` 会执行 schema catalog 中的 JSON 命令，单独运行也可能需要数分钟。release pre-gate 的工具超时应按 20 到 30 分钟设置；10 分钟超时只记为 inconclusive。

## 7. Artifact Gate

`self-artifact-witness` 是晋升 core 的重 gate。它证明当前 framework/code inputs 可以物化隔离的 Stage 1 artifact，并在 artifact 内部重新运行核心 gates。

运行前必须满足：

```text
大构建通过
轻量 gates 通过
当前轮还没有运行过 self-artifact-witness
本轮不是 README/docs-only 改动
```

运行：

```powershell
stack --work-dir .stack-work-codex exec self-artifact-witness
```

或通过 check facade：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

执行约束：

```text
预计耗时至少 10 分钟。
工具超时应给 15 到 20 分钟。
同一轮大构建后最多运行一次。
超时只记为 inconclusive，不能记为 passed 或 failed。
```

## 8. Core Replacement

只有以下证据全部成立，候选 core 才允许替换当前 core：

```text
facade conformance: passed
semantic witness: passed
fixed-point: diffs 0
TrustBase manifest: passed
artifact gate: passed
git diff: 只包含本轮预期改动
```

替换提交建议分两步：

```text
commit 1: 引入或更新已自证候选 core
commit 2: 用已验证候选 core 替换旧 core
```

artifact gate 失败、超时或缺少证据时，保留旧 core。不能把超时当作晋升依据。

## 9. Evidence Record

每次 promotion 记录以下信息：

```text
target commit
semantic-risk scope
commands run
passed witness list
fixed-point result
TrustBase manifest result
self-artifact-witness result
artifact path
replacement decision
```

这条记录可以放在 PR、release note 或维护日志中。说明性文档本身不进入 Stage 1 artifact。
