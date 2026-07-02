# 自举 Gate

本仓库把 framework 改动视为 bootstrap 改动。

每个新 framework 版本都要先完成自证，再参与替换或发布。

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

旧 framework 替换前必须在目标提交运行 `self-artifact-witness` 并通过。

本 gate 面向 framework 迭代、内核替换和 artifact 物化。业务稳定版使用打薄入口，日常开发只运行业务级 build、report 和轻量 witness。

## 每次 Framework 改动的 Gate

提交前运行：

```powershell
stack build
stack exec mytest
stack exec domain-app-report
stack exec domain-app-self-smoke
stack exec framework-core-mytest
stack exec bootstrap-smoke
stack exec bootstrap-runtime-smoke
stack exec bootstrap-report
stack exec fixed-point-smoke
stack exec runtime-diagnosis-witness
stack exec constraint-proof-witness -- --smt=auto
stack exec workflow-semantics-witness
stack exec registry-codegen-witness
stack exec self-artifact-witness
```

通过结果：

```text
domain-app-report: status passed
domain-app semantic evidence: failed 0
bootstrap-report: status passed
fixed-point-smoke: diffs 0
runtime-diagnosis-witness: passed
constraint-proof-witness --smt=auto: passed
workflow-semantics-witness: passed
registry-codegen-witness: passed
self-artifact-witness: passed
```

边界检查：

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
```

两个命令应无输出。

## Artifact 物化 Gate

替换旧 framework source 前必须物化 artifact。

gate 步骤：

```text
1. 在目标提交运行 stack exec self-artifact-witness。
2. witness 创建 .generated/stage1-framework。
3. Stage 1 artifact 运行 stack build。
4. Stage 1 artifact 运行 bootstrap-report。
5. Stage 1 artifact 运行 fixed-point-smoke。
6. Stage 1 artifact 运行 constraint-proof-witness -- --smt=auto。
7. Stage 1 artifact 运行 workflow-semantics-witness。
8. Stage 1 artifact 运行 domain-app-report。
9. Stage 1 artifact 运行 registry-codegen-witness。
```

九步全部通过后，旧 framework 保留为参考和回滚点。

## 替换 Gate

替换旧 framework 代码前确认：

```text
artifact 物化 gate: passed
边界检查: passed
self-domain report: passed
fixed-point evidence: diffs 0
domain-app frontend entry: passed
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
stage1 framework artifact 可编译并验证自身 reports
```

后续 stage 必须保留本文件列出的 gate。
