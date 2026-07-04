# Check Patterns

本文记录当前 gate 分层。工业化的目标不是每次都跑最重的东西，而是让 fast、semantic、release、promotion 的职责清楚。

## 证明层级

```text
host build
  Haskell/Stack 可编译当前工作树。

self-interpret proof
  compiled core_0 运行候选 core_1；core_1 以 domain 前台表达自身。

business frontend proof
  默认业务前台、capability lowering、EffectRow algebra、runner frontdoor 和 domain acceptance app 可用。

manifest/schema guardrail
  evidence、schema catalog、cabal executable、TrustBase manifest 和 check script 清单同步。

artifact proof
  只有 promotion 轮次才物化 self artifact，并在 artifact 内重跑 release proof。
```

## check-fast

用途：本地快速信心。

```powershell
.\scripts\check-fast.cmd
```

展开：

```text
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
```

`check-fast` 不跑业务边界 witness，不跑 domain acceptance report，不跑 self-artifact。

## check-semantic

用途：框架语义和默认业务前台边界。

```powershell
.\scripts\check-semantic.cmd
```

展开：

```text
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec domain-app-report -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

它覆盖：

```text
candidate core self-interpretation
boot AST DAG + occurrence index equivalence proof
ordinary business import boundary
Framework.App runner frontdoor
business-friendly diagnostics
EffectRow algebra over capability lowering
domain-app external acceptance report
TrustBase manifest / schema / gate policy drift
architecture concern risk guardrails
```

## check-release

用途：默认 release confidence，不包含 promotion artifact gate。

```powershell
.\scripts\check-release.cmd
```

当前默认命令与 semantic gate 的非 promotion 部分保持一致。它仍然不跑 `self-artifact-witness`。

## Promotion Gate

只有明确 promotion 时才跑：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

`self-artifact-witness` 是高风险 artifact gate。同一轮 HEAD 的重复运行由脚本 marker 保护。

## 自举主轴

```text
core_0 -> core_1 -> empty_business
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

## Focused Witnesses

调试具体边界时可以单独跑：

```powershell
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec domain-app-report -- --json
stack --work-dir .stack-work-codex exec workflow-semantics-witness -- --json
stack --work-dir .stack-work-codex exec runtime-hot-path-witness -- --json
stack --work-dir .stack-work-codex exec runtime-policy-witness -- --json
stack --work-dir .stack-work-codex exec runtime-diagnosis-witness -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

选择规则：

```text
business authoring/import boundary
  business-syntax-witness

capability lowering / EffectRow algebra
  business-syntax-witness

external business acceptance app
  domain-app-report

workflow AST / EffectTheory / fact closure
  workflow-semantics-witness

runtime dependency weight / hot path
  runtime-hot-path-witness

gate policy / architecture risk inventory
  architecture-concern-witness

manifest / schema / cabal executable drift
  trust-base-manifest-witness
```

## AST Layout 与 DAG

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

## List Mode

所有脚本都支持只列命令：

```powershell
.\scripts\check-fast.cmd -List
.\scripts\check-semantic.cmd -List
.\scripts\check-release.cmd -List
.\scripts\check-release.cmd -IncludeSelfArtifact -List
```

TrustBase manifest witness 会用这些输出检查 gate policy 是否漂移。
