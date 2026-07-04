# Agent Skills

本仓库保留 repo-local Codex skills，用于框架维护时降低定位和验证成本。

位置：

```text
codex-skills/framework-self-iteration
codex-skills/core-promotion-gate
```

这些 skills 先作为仓库内可审查资产保存。需要全局使用时，再把对应目录安装或复制到 Codex skills 目录。

## framework-self-iteration

用途：日常架构内迭代。

使用场景：

```text
定位一个功能属于哪个 facade / CoreSurface / AST fact / EffectSystem / witness claim
调整 AST layout、runtime listener、recursion context
收口 capability / effect / runtime / evidence 的局部语义
选择最小 local witness
```

默认流程：

```text
找到一个 anchor
改最小语义面
跑最小 witness
```

这条 skill 不负责发布新 core，也不运行 `self-artifact-witness`。

## core-promotion-gate

用途：发布或替换新 core。

使用场景：

```text
domain framework 晋升 core framework
release pre-gate
TrustBase / fixed-point / schema catalog 验证
self-artifact-witness 计划和执行
core replacement decision
```

默认流程：

```text
domain-as-core expression
  -> facade conformance
  -> semantic witness
  -> fixed-point
  -> TrustBase manifest
  -> release pre-gate
  -> self-artifact gate
  -> replacement decision
```

`self-artifact-witness` 只属于这条 skill 的 promotion/release 轮次。

release pre-gate 也属于长流程。`schema-catalog-witness -- --json` 会执行 catalog 里的 JSON 输出命令，工具超时应给 20 到 30 分钟；10 分钟超时只算 inconclusive。

## 架构压力

如果 `framework-self-iteration` 用起来仍然需要大量上下文，优先优化架构索引：

```text
facade symbol
CoreSurface capability
AST / effect / fact handle
runtime event
AstLayoutModel / AstRuntimeCursor
witness claim
schema-cataloged JSON payload
```

不要用更长提示词代替缺失的架构索引。
