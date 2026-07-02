# 变更记录

## 未发布

### 已变更

- 当前构建面拆成 `new-framework-core` 和 `domain-app`。
- framework-core 表达层和 compiler implementation 移入 `new-framework-core`。
- 旧 `framework-core` 源码树从活动架构移除。
- `domain-app` 收敛为最小 self domain app，内容指向 `framework-core`。
- Stack、Cabal project、HLS cradle 配置已覆盖两个包。
- native source roots 改为读取 `new-framework-core/src`。
- 主架构文档按双包边界重写。
- README 改为使用指南，并把 HLS cradle entry 对齐到具体 executable。
- 文档新增自举层定位：自举服务 framework 迭代，业务稳定版使用打薄入口。
- workflow runtime 语义补齐真实 `parallel`、`race`、`fallback`、`choice`、`FactAny`、`loop`、`callback`、`middleware`、`suspense`。
- SMT solver 发现逻辑支持 `Z3_EXE`、`CVC5_EXE` 和 `PATH`。
- `constraint-proof-witness` 支持 `--smt=off|auto|required` 和 `FRAMEWORK_SMT`。

### 已新增

- 新增 `domain-app-self-smoke`，验证外部 domain app 可编译并运行 framework-core self report。
- 新增 `Framework.SelfArtifact` 和 `self-artifact-witness`，用于 Stage 6 artifact 物化 gate。
- 新增 `CoreArtifactEffect` 和 self-artifact evidence facts。
- 新增 `workflow-semantics-witness`，覆盖 workflow runtime 核心语义。
- 新增 `RuntimeSnapshot`、`runtimeSnapshot`、`renderRuntimeSnapshot`。

### 已移除

- `domain-app` 不拥有 core implementation。
- 旧 oracle smoke executable 不进入当前构建面。
