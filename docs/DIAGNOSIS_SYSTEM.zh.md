# Diagnosis 系统设计

本文只描述 `diagnosis` 系统。AST 语法和 effect system 另有独立文档。

`diagnosis` 的职责是：当某个 `fact` 或 `externalMake` 失败时，沿着 effect 语义向上定位错误来源，判断哪些上游事实可疑，哪些下游事实已经被污染，哪些操作可以安全 probe，哪些操作必须阻止重复执行。

## 0. 术语

### 0.1 Idempotent

`Idempotent` 表示幂等。

一个操作执行一次和执行多次，在业务语义上得到同一个结果，可以视为幂等。

例子：

```text
写入同一个配置值
用相同 idempotency key 创建同一笔支付请求
查询同一个用户资料
重复确认同一个已完成状态
```

幂等不要求底层完全没有痕迹。日志、计数器、trace 可能增加。诊断系统关心的是：重复执行是否会改变被诊断的业务事实。

在当前系统里：

```text
Idempotent send
  => diagnosis 可以 probe
  => retry 可以更安全
```

### 0.2 NonIdempotent

`NonIdempotent` 表示非幂等。

一个操作重复执行可能改变业务状态，或者产生多次真实副作用，就属于非幂等。

例子：

```text
扣款
发送邮件
追加日志作为业务记录
创建没有去重键的新订单
提交事务
```

在当前系统里：

```text
NonIdempotent send
  => diagnosis 不自动 probe
  => 记录 DiagnosisNonIdempotentSend blocker
```

### 0.3 Replayable

`Replayable` 表示可重放。

可重放关注诊断过程能不能重新执行该操作。它比幂等更偏运行策略。

```text
Idempotent 关注重复执行后的业务结果
Replayable 关注诊断系统是否被允许再次执行
```

一个操作可以是幂等的，但仍然不允许诊断环境重放。例如生产支付网关支持 idempotency key，但测试策略仍然禁止 diagnosis 自动触发真实网关。

### 0.4 NonReplayable

`NonReplayable` 表示不可重放。

不可重放的操作不能为了诊断再次执行。诊断只能使用已有 trace、fact 状态、handler 结果和依赖图推理。

### 0.5 Affine

`Affine` 表示最多使用一次。

它可以不用；一旦使用，就不能重复使用。

例子：

```text
一次性限流 token
可选的取消句柄
可能存在的锁释放动作
```

### 0.6 Linear

`Linear` 表示必须且只能使用一次。

它不能被复制，也不能被静默丢弃。

例子：

```text
事务提交/回滚句柄
必须释放的资源句柄
必须完成 exactly-once 的业务命令
```

Linear 对 diagnosis 的意义是：诊断系统不能通过重复执行来定位错误，只能读取已经产生的证据。

## 1. 当前入口

当前运行时诊断入口在：

```text
Interpreter.Runtime.FactResolution.diagnoseRuntimeFailure
```

当前纯诊断构造在：

```text
Interpreter.Runtime.Diagnosis.buildFailureDiagnosis
```

运行路径：

```text
runtime failure
  -> diagnoseRuntimeFailure
  -> buildFailureDiagnosis
  -> runDiagnosisProbes
  -> recordRuntimeDiagnosis
```

`diagnoseRuntimeFailure` 接收：

```text
rootFact   失败发生在哪个 fact
rootSend   如果失败来自 externalMake，这里记录 send 名称
rootError  原始错误文本
```

然后它从 runtime environment 中取出 `EffectSemantics`，从 runtime state 中取出现有 fact 状态，构造诊断图。

## 2. 当前数据结构

核心结果类型：

```haskell
RuntimeFailureDiagnosis
```

它包含：

```text
diagnosisRootFact       诊断根 fact
diagnosisRootSend       诊断根 externalMake，可为空
diagnosisRootError      根错误
diagnosisNodes          向上追因得到的节点
diagnosisProbes         允许执行的 probe
diagnosisSuspects       可疑 fact 集合
diagnosisPollutedFacts  被失败污染的下游 fact 集合
```

单个诊断节点：

```haskell
RuntimeDiagnosisNode
```

它包含：

```text
diagnosisNodeFact                当前 fact
diagnosisNodeKind                root / needs upstream / pipe upstream
diagnosisNodeStatus              runtime 中记录的 fact 状态
diagnosisNodeExternalMakes       当前 fact 使用的 externalMake
diagnosisNodeIdempotentSends     可以 probe 的 send
diagnosisNodeNonIdempotentSends  不能 probe 的 send
diagnosisNodeBlockers            阻止进一步诊断的原因
```

当前 blocker：

```text
DiagnosisMissingRule
DiagnosisExternalTakeSource
DiagnosisNonIdempotentSend SendName
```

当前 probe 状态：

```text
DiagnosisProbePending
DiagnosisProbePassed
DiagnosisProbeFailed String
```

## 3. 当前诊断语义

### 3.1 向上追因

`buildFailureDiagnosis` 从 `rootFact` 开始，根据 `TakeMakeRule` 向上寻找依赖。

它会追踪：

```text
takeFacts       fact dependency
pipeTakeFacts   typed pipe dependency
```

这使诊断可以从失败点继续追问：

```text
这个 fact 是自己失败，还是上游 fact 导致失败？
```

### 3.2 probe

当前只有 `Idempotent` 的 send 会进入 `diagnosisProbes`。

规则：

```text
sendContractIdempotency == Idempotent
  => diagnosis 可以重新执行 externalMake 做 probe
```

当前实现会执行：

```text
runDiagnosisProbe
  -> runExternalMakeOnce
```

probe 成功记录 `DiagnosisProbePassed`，失败记录 `DiagnosisProbeFailed`。

### 3.3 blocker

如果某个节点缺少生产规则：

```text
DiagnosisMissingRule
```

如果某个节点来自外部输入：

```text
DiagnosisExternalTakeSource
```

如果某个节点依赖非幂等 send：

```text
DiagnosisNonIdempotentSend
```

这些 blocker 的含义是：诊断系统不能通过简单重复执行来进一步确认错误，只能依赖已有 runtime trace、fact 状态和 effect dependency 推理。

### 3.4 suspect

当前 suspect 规则：

```text
rootFact 一定是 suspect
有 idempotent sends 的节点是 suspect
有 non-idempotent blocker 的节点是 suspect
缺少 rule 的节点是 suspect
externalTake source 是 suspect
没有 externalMake 且没有 blocker 的叶子节点是 suspect
```

`suspect` 表示需要开发者、report 或后续自动诊断继续关注的候选位置。

### 3.5 polluted facts

`diagnosisPollutedFacts` 表示从失败 fact 向下游传播后，哪些已 claim 的 fact 可能被污染。

规则来源：

```text
如果某个 TakeMakeRule 依赖 rootFact，
并且它 make 出来的 fact 已经出现在 runtime claims 中，
那么该 fact 属于污染下游。
```

这部分用于回答：

```text
这个错误影响了哪些后续结果？
```

## 4. Diagnosis 与 Effect System 的关系

Diagnosis 不直接理解业务。它依赖 effect system 提供的语义：

```text
FactContract       fact 如何生产
TakeMakeRule       fact 的 take / make / uses / transform / error handler
SendContract       externalMake 的签名和策略
IdempotencyPolicy  send 是否幂等
RetryPolicy        send 是否允许重试
```

当前 effect DSL 中已经有：

```haskell
externalMake AskUserName NoInput UserName
idempotent AskUserName
retry AskUserName
```

这说明 diagnosis 的安全性来自 effect contract。

## 5. 幂等性对错误定位的作用

幂等性是 diagnosis 的执行许可。

```text
Idempotent
  => 可以为了定位错误重新执行
  => 可以 probe
  => 可以 retry
```

如果没有幂等性，diagnosis 仍然可以向上构建错误图，但不能随意重复执行外部操作。

这对生产环境非常重要：

```text
QueryUser        可以 probe
AskUserName      可以按策略 probe
WriteLog         可能不能 probe
ChargePayment    不能 probe
SendEmail        不能随意 probe
CommitTx         不能 probe
```

所以幂等性证明会直接提升错误定位能力。它使诊断系统可以把“只读推理”升级成“安全验证”。

## 6. 与 Linear 思路结合的顶层设计

当前系统只有：

```haskell
Idempotent | NonIdempotent
NoRetry | RetryOnce
```

后续不应把所有执行性质塞进一个 enum。更合适的是拆成几组正交策略。

### 6.1 ReplayPolicy

```haskell
data ReplayPolicy
  = Replayable
  | NonReplayable
```

含义：

```text
Replayable     diagnosis 可以重新执行该 send 做 probe
NonReplayable  diagnosis 不能为了定位错误重新执行该 send
```

### 6.2 UsagePolicy

```haskell
data UsagePolicy
  = Unrestricted
  | Affine
  | Linear
```

含义：

```text
Unrestricted  可复制、可丢弃、可多次使用
Affine        最多使用一次，可以不用
Linear        必须且只能使用一次
```

这组策略用于表达副作用资源的真实业务性质。

```text
支付请求     Linear / NonReplayable
事务 token   Linear
锁资源       Affine 或 Linear
限流 token   Affine
只读查询     Unrestricted / Replayable
```

### 6.3 FailurePolicy

```haskell
data FailurePolicy
  = Retryable
  | NonRetryable
```

含义：

```text
Retryable     handler 失败后可以自动重试
NonRetryable  handler 失败后不能自动重试
```

`RetryPolicy` 可以继续表达次数，例如 `RetryOnce`，但它需要建立在 `FailurePolicy` 或 replay 规则之上。

## 7. Linear 对 Diagnosis 的价值

Linear 思路不会让 diagnosis 更愿意重试。它的价值恰好相反：明确禁止不安全的重新执行。

诊断规则应变成：

```text
Replayable + Idempotent
  => 可以 probe

NonReplayable
  => 禁止 probe

Affine
  => 如果已消费，禁止再次执行

Linear
  => 必须检查 exactly-once；诊断只能读取 trace，不能重新消费
```

这可以避免错误定位本身制造新的副作用。

例子：

```text
ChargePayment 失败
  diagnosis 不能再次 ChargePayment
  diagnosis 只能查看 payment request、handler trace、gateway response、上游 UserKnownFact

AskUserName 失败
  如果声明为 idempotent/replayable
  diagnosis 可以重新执行 AskUserName 做 probe
```

## 8. 自动确定边界

这些策略不能全部自动确定。

`externalMake` 边界必须由业务声明：

```text
ChargePayment 是否幂等，取决于是否有 idempotency key、支付网关协议、handler 实现。
WriteLog 是否可重放，取决于日志是否 append、是否去重。
SendEmail 是否可重试，取决于业务是否允许重复邮件。
```

但声明之后，系统可以自动推导 fact 和 workflow 的诊断性质。

推导规则：

```text
fact uses replayable send
  => fact 可以被 probe

fact uses nonReplayable send
  => fact 只能 trace-based diagnosis

fact uses linear send
  => fact 是 linear-sensitive

parallel 分支重复消费同一个 linear resource
  => validation error

loop 内包含 nonReplayable send
  => validation error 或要求显式 override

fallback 第一分支消费 linear resource 后进入第二分支
  => 必须有 compensation 或显式策略
```

## 9. 模块分层建议

当前已实现：

```text
Interpreter.Runtime.Diagnosis
```

后续可以拆出纯 core 层：

```text
Core.Diagnosis
Core.Diagnosis.Policy
Core.Diagnosis.Graph
Core.Diagnosis.Report
Interpreter.Runtime.Diagnosis
```

建议职责：

```text
Core.Diagnosis
  定义 diagnosis graph、node、probe、blocker、suspect、pollution。

Core.Diagnosis.Policy
  判断 replay / retry / probe / linear usage 是否允许。

Core.Diagnosis.Graph
  根据 EffectSemantics 建立 upstream/downstream 因果图。

Core.Diagnosis.Report
  把诊断结果渲染成稳定报告。

Interpreter.Runtime.Diagnosis
  把纯 diagnosis 接到 runtime state 和 handler 执行。
```

这样可以保持：

```text
纯规则在 Core
运行时 probe 在 Interpreter.Runtime
前台业务代码不需要理解诊断实现
```

## 10. Probe 当前可用性

当前 probe 已经形成最小闭环。

已有流程：

```text
runtime failure
  -> buildFailureDiagnosis
  -> 找出 idempotent sends
  -> 生成 DiagnosisProbePending
  -> runDiagnosisProbes
  -> runExternalMakeOnce
  -> DiagnosisProbePassed / DiagnosisProbeFailed
  -> recordRuntimeDiagnosis
```

当前 probe 可用于：

```text
smoke test
内部诊断演示
idempotent externalMake 的失败确认
验证 diagnosis graph 是否能记录 probe 结果
```

当前限制：

```text
只识别 Idempotent / NonIdempotent
缺少 ReplayPolicy
缺少 UsagePolicy
缺少 Linear / Affine 资源消费记录
probe 直接调用当前 handler 路径
缺少 dry-run handler / probe handler 分离
缺少稳定报告格式
缺少生产级安全开关
```

当前判断：

```text
probe 可以作为 diagnosis 的实验闭环使用。
probe 进入生产路径前，需要增加 policy gate。
```

建议下一步把 probe 拆成三层：

```text
ProbePlan
  纯计划。列出候选 send、所需策略、阻塞原因。

ProbePolicy
  纯规则。判断某个 send 是否允许 probe。

ProbeExecution
  运行时执行。只执行 ProbePolicy 放行的 probe。
```

目标路径：

```text
buildFailureDiagnosis
  -> buildProbePlan
  -> checkProbePolicy
  -> executeAllowedProbes
  -> recordRuntimeDiagnosis
```

这样可以把“诊断图构造”和“真实外部执行”分开。

## 11. TODO

### 11.1 Probe 安全化

- 增加 `ProbePlan`。
- 增加 `ProbePolicy`。
- 增加 `ProbeExecution`。
- 让 `runDiagnosisProbe` 只接收已经通过 policy 的 probe。
- 把 probe blocker 扩展成可解释原因。
- 增加 probe report：候选、放行、阻止、执行结果。

建议 blocker：

```text
ProbeBlockedMissingRule
ProbeBlockedExternalTake
ProbeBlockedNonIdempotent
ProbeBlockedNonReplayable
ProbeBlockedLinearConsumed
ProbeBlockedAffineConsumed
ProbeBlockedMissingHandler
```

### 11.2 增加 buff 语义

- 在 effect DSL 中增加 operation 级别的语义标注。
- `buff` 只描述合约，不生产 fact。
- `buff` 优先作用于 `externalMake`。
- 普通 operation 可以不写 `buff`。
- 危险 operation 需要显式声明。

示例目标：

```haskell
externalMake ChargePayment PaymentRequest PaymentResult
buff ChargePayment [nonReplayable, linear]

externalMake QueryUser UserId User
buff QueryUser [replayable, idempotent, retryable]
```

### 11.3 从 runtime 摘出 Diagnosis 系统

- 当前 `Diagnosis` 还没有完全分离。
- `Interpreter.Runtime.Diagnosis` 已经存在，但仍然属于 runtime 层。
- `RuntimeFailureDiagnosis`、`RuntimeDiagnosisNode`、`RuntimeDiagnosisProbe` 等类型仍然定义在 `Interpreter.Runtime.Types`。
- `diagnoseRuntimeFailure` 和 `runDiagnosisProbes` 仍然由 `Interpreter.Runtime.FactResolution` 触发和执行。
- 下一步要把纯诊断模型摘到 `Core.Diagnosis`。
- `Core.Diagnosis` 只描述 diagnosis graph、suspect、probe plan、blocker、pollution。
- `Interpreter.Runtime.Diagnosis` 只负责把 runtime state、handler、trace 接到纯诊断模型。
- probe 的真实执行保留在 runtime 层。
- 前台业务代码不直接依赖 `Core.Diagnosis` 和 `Interpreter.Runtime.Diagnosis`。

### 11.4 扩展 effect policy

- 增加 `ReplayPolicy`。
- 增加 `UsagePolicy`。
- 增加更清晰的 failure/retry policy。
- 保留当前 `idempotent` / `retry` DSL，逐步扩展，不破坏前台写法。

### 11.5 定义 probe 许可规则

- `Idempotent + Replayable` 允许 probe。
- `NonReplayable` 禁止 probe。
- `Linear` 禁止重复消费。
- `Affine` 如果已消费则禁止再次执行。
- 未声明策略时默认保守处理。

### 11.6 定义向上错误定位规则

- 区分 root failure、dependency failure、pipe failure、handler failure。
- 给每种失败建立可解释的 suspect 规则。
- 记录“为什么这个 fact 被怀疑”。
- 记录“为什么这个 fact 不能继续 probe”。

### 11.7 定义污染传播规则

- 继续使用 dependency graph 推导 polluted facts。
- 增加 workflow 维度：chain / parallel / fallback / race / choice / loop 对污染传播的影响。
- 区分“已经污染”和“可能污染”。

### 11.8 定义 linear validation

- parallel 中禁止重复消费同一个 linear resource。
- loop 中禁止默认重复执行 nonReplayable effect。
- fallback / race 需要 cleanup 或 compensation 规则。
- callback 并行启动时检查捕获的资源是否可复制。

### 11.9 形成标准诊断报告

报告至少包含：

```text
root
root error
causal path
suspects
blocked probes
executed probes
polluted facts
linear/nonReplayable reason
recommended next inspection point
```

### 11.10 和测试体系连接

- 保留现有 runtime smoke。
- 增加 policy smoke。
- 增加 linear-sensitive workflow smoke。
- 增加 nonReplayable diagnosis smoke。
- 增加 polluted facts report smoke。

## 12. 当前完成度判断

当前 diagnosis 已经具备系统雏形：

```text
已有 root failure
已有 upstream graph
已有 idempotent probe
已有 non-idempotent blocker
已有 suspect facts
已有 polluted facts
已有 runtime smoke 覆盖
```

当前缺少的是策略完备性：

```text
缺 replay policy
缺 linear / affine usage policy
缺 workflow-aware pollution
缺稳定 report 格式
缺 core/runtime 分层
缺更完整的 validation
```

因此下一阶段目标是把 diagnosis 建成 effect system 之上的错误定位系统。
