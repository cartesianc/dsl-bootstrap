# Effect 前台语法规范更新完成记录

状态：已完成。长期规范见：

```text
docs/EFFECT_FRONTEND_SYNTAX.zh.md
```

本次落地内容：

```text
新增 Framework.Business / Bootstrap.Business facade
新增 Capability DSL
新增 Pipeline DSL
新增 CapabilityPolicy
新增 capability -> normalized EffectUnit lowering
新增 handler binding checker
新增 transform binding checker
新增 Fact / Artifact / Internal 粒度 checker
新增 Domain.Business 作为业务 source of truth
Effects.* 改为薄 lowering facade
GenerateReport 改为前台 capability 样例
新增 business-syntax-witness
self-artifact-witness gate 纳入 business-syntax-witness
README / domain README / layout / gate 文档已更新
```

语义边界：

```text
业务作者写 capability/pipeline/policy/handler binding/transform binding。
底层 IR 仍显式保留 needs/take/make/uses/externalMake/transform/retry/idempotent。
runtime handler 执行语义未改变。
pipeline 只生成 artifact 数据流和 transform candidate，不自动生成业务 fact。
checker 只提示，不自动改名，不自动拆 fact。
```

验证命令：

```powershell
stack build
stack exec business-syntax-witness
stack exec workflow-semantics-witness
stack exec constraint-proof-witness -- --smt=auto
stack exec domain-app-report
stack exec self-artifact-witness
```

