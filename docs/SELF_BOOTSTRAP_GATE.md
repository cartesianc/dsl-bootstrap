# 自举 Gate

本仓库把 framework 改动视为 bootstrap 改动。

每个新 framework 版本都要先完成自证，再参与替换或发布。

`docs/CORE_PROMOTION_SOP.zh.md` 定义 domain framework 晋升 core framework 的完整 promotion 流程；本文只展开 self-bootstrap、artifact 物化和替换 gate。

## 当前状态

当前实现已经达到 evidence fixed point：

```text
Stage 0: Bootstrap.* 直接生成 framework-core report
Stage 1: Framework.* facade/domain 生成 framework-core report
Result: fixed-point-smoke 输出 diffs: 0
```

registry/codegen 已进入 framework semantics：

```text
Framework.RegistryCodegen
RegistryCodegenExpressedFact
RegistryCodegenEvidencePassedFact
domain-app registry-codegen semantic evidence
```

artifact 物化已有 witness：

```text
Framework.SelfArtifact
SelfArtifactManifestExpressedFact
SelfArtifactManifestEvidencePassedFact
self-artifact-witness
.generated/stage1-framework
```

已提交源码就是 core source。artifact tree 是从当前源码生成的隔离替换候选。

## 规则

framework 改动完成前必须通过编译和自证。

旧 framework 替换前必须在目标提交完成大构建和轻量 gates；`self-artifact-witness` 只作为高危 artifact gate 运行一次并通过。

本 gate 面向 framework 迭代、内核替换和 artifact 物化。业务稳定版使用打薄入口，日常开发只运行业务级 build、report 和轻量 witness。

`self-artifact-witness` 不属于每次 framework 改动的普通 gate。它是高危/重型指令：一轮大构建完成后最多运行一次；第二次不允许继续跑；README/docs-only 变更不触发它。

## 每次 Framework 改动的 Gate

提交前运行：

```powershell
.\scripts\check-release.cmd
```

展开命令：

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

通过结果：

```text
core-self-interpret-report.v1: passed
TrustBase manifest evidence: passed
architecture concern evidence: passed
self-artifact-witness: skipped unless this is the explicit high-risk artifact gate round
```

边界检查：

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
```

两个命令应无输出。

## Artifact 物化 Gate

替换旧 framework source 前必须物化 artifact。

`self-artifact-witness` 是高危指令：

```text
一轮大构建完成后最多运行一次。
同一轮第二次不允许继续跑。
README/docs-only 变更不触发它。
```

gate 步骤：

```text
1. 在目标提交完成 release pre-gate：build + core-self-interpret + TrustBase manifest + architecture guardrail。
2. 确认当前轮还没有运行过 self-artifact-witness。
3. 运行 .\scripts\check-release.cmd -IncludeSelfArtifact。
4. witness 创建 .generated/stage1-framework。
5. Stage 1 artifact 运行 stack build。
6. Stage 1 artifact 运行 core-self-interpret、trust-base-manifest-witness 和 architecture-concern-witness。
```

artifact 内部的 self-interpret release proof 全部通过后，旧 framework 保留为参考和回滚点。

## 替换 Gate

替换旧 framework 代码前确认：

```text
artifact 物化 gate: passed
边界检查: passed
core-self-interpret report: passed
core_0/core_1 exchangeability: passed
git status: clean after commit
```

替换提交要求：

```text
commit 1: 引入或更新已自证 framework
commit 2: 用已验证 framework 替换旧 framework
```

artifact materialization 失败时，保留旧 framework source。

## Stage 计划

```text
Stage 5: plugins/effects 自动 registry/codegen
Stage 6: artifact 物化自托管
Stage 7: 已验证 framework source 替换
```

Stage 5 状态：

```text
registry/codegen 已声明在 framework-core AST/effect semantics 中
domain-app plugin/effect registries 已有 generated-line semantic evidence
registry-codegen-witness 是对应 host witness
```

Stage 6 状态：

```text
self-artifact manifest 已声明在 framework-core AST/effect semantics 中
self-artifact-witness 物化 .generated/stage1-framework
stage1 framework artifact 可编译并验证 self-interpret release proof
```

后续 stage 必须保留本文件列出的 gate。
