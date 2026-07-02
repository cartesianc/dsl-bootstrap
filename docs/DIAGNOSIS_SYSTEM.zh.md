# Diagnosis 系统

本文描述新的 runtime fact closure 和 failure diagnosis 方向。旧 runtime 文档不再作为 production 说明。

## 1. 诊断目标

Diagnosis 回答三个问题：

```text
某个 fact 为什么不能产生？
失败污染了哪些下游 fact？
哪些 send 可以安全 probe，哪些必须阻止？
```

它建立在 effect theory 之上，而不是建立在业务代码之上。

## 2. 输入

Diagnosis 输入来自 native runtime：

```text
NativeAppPlan
NativeFactRule
SendContract
RuntimeEffectEnvironment
NativeRuntime
RuntimeArtifact
```

关键关系：

```text
fact needs fact
fact takes artifact type
fact makes artifact type
fact uses send
send has input/output contract
send has idempotency/retry policy
handler may succeed or fail
```

## 3. 输出

目标诊断报告应包含：

```text
root fact
root send
root error
causal upstream facts
blocked probes
allowed probes
executed probes
polluted downstream facts
missing handlers
missing artifacts
missing producers
recommended next inspection point
```

## 4. Probe Policy

Probe 不等于 retry。Probe 是为了定位错误而重新执行某个 boundary。

默认规则：

```text
Idempotent + Replayable
  可以 probe

NonReplayable
  禁止 probe

Linear
  禁止重复消费

Affine
  如果已消费则禁止再次执行

未声明策略
  默认保守禁止 probe
```

当前 effect DSL 已有：

```text
idempotent
retry
```

后续需要扩展：

```text
ReplayPolicy
UsagePolicy
FailurePolicy
ProbePolicy
```

## 5. Pollution

如果一个 root fact 失败，所有依赖它且已经进入 claim/plan 的下游 fact 都可能被污染。

传播依据：

```text
needs dependency
take/make artifact dependency
transform dependency
send output dependency
workflow wait gate
```

报告要区分：

```text
definitely polluted
possibly polluted
blocked before execution
unreachable by current root closure
```

## 6. Runtime Closure

`bootstrap-runtime-smoke` 当前验证 framework-core runtime closure。

后续报告应稳定输出：

```text
declared facts
reachable facts
final facts
unreachable facts
send boundaries
handlers used
artifacts produced
constraints checked
```

这会让 runtime smoke 从“能跑”升级为“能解释为什么跑完”。

## 7. 分层

推荐分层：

```text
Bootstrap.Runtime
  runtime execution and native app plan

Bootstrap.Diagnosis.Policy
  pure probe/retry/usage rules

Bootstrap.Diagnosis.Graph
  upstream/downstream causal graph

Bootstrap.Diagnosis.Report
  stable human-readable and machine-readable report
```

真实 handler execution 只留在 runtime 层。纯诊断图不执行 IO。

## 8. 成功标准

Diagnosis 完成后，应能在 framework 自举失败时指出：

```text
哪个 final atomic capability 未闭合
缺哪个 producer 或 handler
哪个 artifact type 没有 maker
哪个 send boundary 没有实现
哪个 probe 被策略阻止
哪个下游 fact 已被污染
```
