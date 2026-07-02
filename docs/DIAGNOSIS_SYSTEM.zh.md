# 诊断系统

本文描述新的 runtime fact closure 和 failure diagnosis 方向。旧 runtime 文档退出 production 说明。

## 1. 诊断目标

Diagnosis 回答三个问题：

```text
某个 fact 为什么不能产生？
失败污染了哪些下游 fact？
哪些 send 可以安全 probe，哪些必须阻止？
```

它建立在 effect theory 之上，并从 runtime witness 收集业务执行证据。

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
fact 依赖 fact
fact 读取 artifact type
fact 产生 artifact type
fact 使用 send
send 拥有 input/output contract
send 拥有 idempotency/retry policy
handler 可成功或失败
```

## 3. 输出

目标诊断报告应包含：

```text
root fact
root send
root error
因果上游 facts
已阻止 probes
允许 probes
已执行 probes
被污染下游 facts
缺失 handlers
缺失 artifacts
缺失 producers
建议检查点
```

## 4. Probe 策略

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

## 5. 污染范围

如果一个 root fact 失败，所有依赖它且已经进入 claim/plan 的下游 fact 都可能被污染。

传播依据：

```text
needs 依赖
take/make artifact 依赖
transform 依赖
send output 依赖
workflow wait gate
```

报告要区分：

```text
确定污染
可能污染
执行前阻断
当前 root closure 不可达
```

## 6. Runtime 闭包

`bootstrap-runtime-smoke` 当前验证 framework-core runtime closure。

后续报告应稳定输出：

```text
声明 facts
可达 facts
最终 facts
不可达 facts
send boundaries
已使用 handlers
已产生 artifacts
已检查 constraints
```

这会让 runtime smoke 从“能跑”升级为“能解释为什么跑完”。

## 7. 分层

推荐分层：

```text
Bootstrap.Runtime
  runtime 执行和 native app plan

Bootstrap.Diagnosis.Policy
  纯 probe/retry/usage 规则

Bootstrap.Diagnosis.Graph
  上游/下游因果图

Bootstrap.Diagnosis.Report
  稳定人读和机器读 report
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
