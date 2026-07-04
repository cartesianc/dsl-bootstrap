# Maintenance Tooling Notes

本页记录仓库内的维护工具说明。业务开发者阅读 `README.md`、
`docs/STABLE_FRONTEND.zh.md` 和 `domain-app/README.md` 即可。

工具目录：

```text
codex-skills/framework-self-iteration
codex-skills/core-promotion-gate
```

这些目录作为可审查的仓库资产保存。需要全局使用时，可以把对应目录安装或复制到 Codex skills 目录。

## framework-self-iteration

用途：日常架构维护。

适用场景：

```text
定位功能所属的 facade / CoreSurface / AST fact / EffectSystem / witness claim
调整 AST layout、runtime listener、recursion context
收口 capability / effect / runtime / evidence 的局部语义
选择最小 local witness
```

默认流程：

```text
找到一个 anchor
修改最小语义面
运行对应 witness
```

发布新 core 和 `self-artifact-witness` 由 `core-promotion-gate` 覆盖。

## core-promotion-gate

用途：发布或替换新 core。

适用场景：

```text
domain framework 晋升 core framework
release pre-gate
TrustBase / fixed-point / schema catalog 验证
self-artifact-witness planning and execution
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

`self-artifact-witness` 属于这条 promotion/release 流程。`schema-catalog-witness -- --json`
会执行 catalog 里的 JSON 输出命令，工具超时时间建议给到 20 到 30 分钟；10 分钟超时属于 inconclusive。

## 架构压力

如果日常维护仍然需要大量上下文，优先补架构索引：

```text
facade symbol
CoreSurface capability
AST / effect / fact handle
runtime event
AstLayoutModel / AstRuntimeCursor
witness claim
schema-cataloged JSON payload
```

用更清晰的架构索引降低维护成本。
