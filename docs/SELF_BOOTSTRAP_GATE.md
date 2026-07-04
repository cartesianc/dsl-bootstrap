# Self-bootstrap Gate

本文定义 framework 自举验证和 Stage1 artifact 物化规则。

完整 promotion 流程见 [CORE_PROMOTION_SOP.zh.md](CORE_PROMOTION_SOP.zh.md)。

## 1. Self-interpret Line

```text
core_0 -> core_1 -> empty_business
```

```text
core_0
  Previous compiled core / current TrustBase.

core_1
  Candidate core expressed by current framework foreground.

empty_business
  Terminal Unit app for recursion closure.
```

## 2. Release Pre-gate

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

通过结果：

```text
core-self-interpret-report.v1 passed
TrustBase manifest evidence passed
architecture concern evidence passed
self-artifact-witness skipped
```

## 3. Artifact Gate

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

运行条件：

```text
release pre-gate passed
same HEAD has not run self-artifact-witness in this round
promotion/replacement round
```

步骤：

```text
1. Materialize .generated/stage1-framework.
2. Run stack build inside the artifact.
3. Run core-self-interpret inside the artifact.
4. Run trust-base-manifest-witness -- --evidence-json inside the artifact.
5. Run architecture-concern-witness -- --json inside the artifact.
```

通过结果：

```text
artifact created
artifact build passed
artifact self-interpret passed
artifact TrustBase manifest evidence passed
artifact architecture guardrail passed
```

## 4. Boundary Checks

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
```

两个命令应无输出。

## 5. Replacement Gate

替换当前 core 前确认：

```text
release pre-gate passed
artifact gate passed
boundary checks passed
core_0/core_1 exchangeability passed
git status clean after commit
```

替换提交：

```text
commit 1: introduce verified candidate framework
commit 2: replace previous framework with verified candidate
```

artifact gate failed、timeout 或 evidence 缺失时，保留当前 core。
