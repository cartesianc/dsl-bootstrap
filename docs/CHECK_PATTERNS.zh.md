# Check Patterns

本文记录当前 gate 分层。工业化的目标不是每次都跑最重的东西，而是让 fast、semantic、release、promotion 的职责清楚。

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
ordinary business import boundary
Framework.App runner frontdoor
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

external business acceptance app
  domain-app-report

runtime dependency weight / hot path
  runtime-hot-path-witness

gate policy / architecture risk inventory
  architecture-concern-witness

manifest / schema / cabal executable drift
  trust-base-manifest-witness
```

## List Mode

所有脚本都支持只列命令：

```powershell
.\scripts\check-fast.cmd -List
.\scripts\check-semantic.cmd -List
.\scripts\check-release.cmd -List
```

TrustBase manifest witness 会用这些输出检查 gate policy 是否漂移。
