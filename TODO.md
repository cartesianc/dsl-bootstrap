# 待办

当前目标：把 `new-framework-core` 收束成真正的 framework compiler/core，让 `domain-app` 作为外部使用者表达 core 自身。

## 1. 维持双包边界

当前形态：

```text
new-framework-core
  拥有 Bootstrap.*、Domain.*、native runtime、report、core CLI

domain-app
  依赖 new-framework-core
  只拥有 SelfDomainApp
  运行 domain-app-self-smoke
```

后续规则：

```text
core implementation 留在 new-framework-core
domain-app 保持外部使用者身份
旧 generated plugin/effect registry 不进入 production surface
旧 current/demo alias 不进入 production surface
旧 Framework.* facade 不进入 production import
compatibility/migration layer 需要单独 gate
```

## 2. Native Proof Surface

继续补全：

```text
fact 闭包
send contract 闭包
take/make 闭包
重复 producer 检测
handler 覆盖
transform 覆盖
boundary policy evidence
runtime final fact evidence
```

外部 SMT solver 是可选层。没有 solver 时，Haskell proof evidence 通过即可。需要强校验时运行：

```powershell
stack exec constraint-proof-witness -- --smt=required
```

## 3. Fixed Point

下一步补强固定点检查：

```text
Stage 0 构建报告
Stage 1 自证报告
Stage 0 / Stage 1 evidence diff
```

比较项：

```text
domain map
AST facts
effect facts
runtime fact 闭包
boundary evidence
proof evidence
渲染报告
```

## 4. Report 格式

当前 `Bootstrap.Report.FrameworkCoreReport` 已覆盖：

```text
声明 facts
计划 runtime facts
最终 runtime facts
send boundaries
已使用 handlers
已产生 artifacts
runtime 闭包外的声明 facts
```

后续补充：

```text
JSON / machine-readable report
Stage 报告
fixed point 报告
kernel 更新摘要
```

## 5. Runtime 拆分

`Bootstrap.Runtime` 仍偏大。建议按行为拆分：

```text
Bootstrap.Runtime.Types
Bootstrap.Runtime.Build
Bootstrap.Runtime.Validation
Bootstrap.Runtime.Closure
Bootstrap.Runtime.Boundary
Bootstrap.Runtime.Proof
Bootstrap.Runtime.SourceGraph
Bootstrap.Runtime.Report
```

拆分顺序：

```text
1. 提取类型
2. 提取纯函数
3. 保持现有语义
4. 每一步运行 stack build
5. 关键语义运行 workflow-semantics-witness
```

## 6. 文档规则

文档只描述当前 architecture：

```text
new-framework-core 是 core/compiler
domain-app 是外部使用者
旧业务 DomainApp 保留为历史参照
旧 generated plugin/effect registry 保留为历史参照
旧 current/demo alias 保留为历史参照
旧 Framework.* facade 不进入 production import
```

写法规则：

```text
使用短句
直接说明状态
先写命令和规则
减少解释性套话
避免对照式套话
```

## 7. 业务稳定版入口

自举层服务 framework 迭代。进入业务稳定版后，默认入口需要打薄：

```text
Framework.Business
业务 vocabulary
workflow
effect theory
runtime handlers
轻量 diagnosis/report
```

以下能力保留给 framework 作者：

```text
Bootstrap.*
SelfArtifact
fixed-point gate
artifact materialization gate
self-artifact-witness
workflow-semantics-witness
kernel replacement flow
```
