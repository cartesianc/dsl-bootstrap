# Diagnosis System

本文记录 runtime failure diagnosis 的当前职责和边界。

## 1. 目标

Diagnosis 回答三个问题：

```text
某个 fact 为什么不能产生？
失败污染了哪些下游 fact？
哪些 send 可以安全 probe，哪些必须阻止？
```

Diagnosis 建立在 `Workflow AST + EffectTheory + NativeAppPlan` 上，并使用 runtime witness 产生的执行证据。

## 2. 输入

Diagnosis 输入来自 bootstrap backend runtime evidence：

```text
NativeAppPlan
NativeFactRule
SendContract
RuntimeEffectEnvironment
NativeRuntime
RuntimeArtifact
```

这些名字属于 bootstrap backend 的证据模型，不表示项目存在两套运行时。typed runtime backend 也解释同一套 plan。

## 3. 关键关系

```text
fact depends on fact
fact takes artifact type
fact makes artifact type
fact uses send
send has input/output contract
send has idempotency/retry policy
handler succeeds or fails
```

## 4. Probe 策略

Probe 用于定位错误；普通 retry 由 retry policy 表达。Probe 只允许对 replay-safe 的边界执行。

当前 effect DSL 已有：

```text
idempotent
retry
```

当前诊断 evidence 覆盖：

```text
error handler dispatch with ErrorInput
idempotent RetryOnce failed probe
non-idempotent replay blocker
```

`runtime-diagnosis-witness` 为每个诊断 claim 输出 `RuntimeDiagnosisEvidencePayload`：

```text
claim
status
expected
observed
artifact
```

当前三条 payload claim：

```text
runtime-diagnosis-error-handler -> RuntimeErrorDispatchArtifact
runtime-diagnosis-retry-probe -> RuntimeRetryPolicyArtifact
runtime-diagnosis-non-idempotent-blocker -> RuntimeIdempotencyPolicyArtifact
```

## 5. 污染范围

如果 root fact 失败，所有依赖它且已经进入 claim/plan 的下游 fact 都可能被污染。

传播依据：

```text
needs dependency
take/make artifact dependency
transform dependency
send output dependency
workflow wait gate
```

## 6. 分层

```text
Framework.Runtime
  typed runtime backend and public diagnosis data types

Framework.Background.RuntimeDiagnosis
  public diagnosis facade

Bootstrap.Runtime
  bootstrap backend closure evidence
```

真实 handler execution 留在 runtime backend。纯诊断图不应执行 IO。

## 7. 成功标准

诊断应能指出：

```text
which fact failed
which producer or handler is missing
which artifact type has no maker
which send boundary has no implementation
which probe is blocked by policy
which downstream facts were polluted
```
