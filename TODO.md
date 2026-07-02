# TODO

当前目标是把 `new-framework-core` 收束成真正的 framework compiler/core，并让 `domain-app` 作为外部使用者表达 core 自身。

## 1. 保持两包边界

当前形态：

```text
new-framework-core
  owns Bootstrap.*, Domain.*, native runtime, report, core CLIs

domain-app
  depends on new-framework-core
  owns only SelfDomainApp
  runs domain-app-self-smoke
```

后续不要把 core 实现搬回 `domain-app`。

## 2. Native Proof Surface

继续补全：

```text
fact closure
send contract closure
take/make closure
duplicate producer detection
handler coverage
transform coverage
boundary policy evidence
runtime final fact evidence
```

外部 SMT solver 仍然是可选层；没有 solver 时，Haskell proof evidence 通过即可。

## 3. Fixed Point

下一步要加真正的固定点检查：

```text
Stage 0 build report
Stage 1 self report
Stage 0 / Stage 1 evidence diff
```

比较项：

```text
domain map
AST facts
effect facts
runtime fact closure
boundary evidence
proof evidence
rendered report
```

## 4. Report 格式

当前 `Bootstrap.Report.FrameworkCoreReport` 已覆盖：

```text
declared facts
planned runtime facts
final runtime facts
send boundaries
handlers used
artifacts produced
declared facts outside runtime closure
```

后续要补：

```text
JSON / machine-readable report
Stage report
fixed point report
kernel update summary
```

## 5. Runtime 拆分

`Bootstrap.Runtime` 现在仍然偏大。建议按行为拆：

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

先纯提取类型和函数，不改语义；每一步都用 build-watch 编译。

## 6. 文档规则

文档只描述当前 architecture：

```text
new-framework-core 是 core/compiler
domain-app 是使用者
不恢复旧业务 DomainApp
不恢复 generated plugin/effect registry
不恢复 current/demo alias
不把旧 Framework.* facade 当 production import
不增加 compatibility/migration layer
```
