# dsl-bootstrap

`dsl-bootstrap` 是一个自举式 Haskell 业务框架。业务用声明式源码表达：

- workflow AST
- effect theory
- typed runtime handlers
- semantic evidence
- framework 自证

仓库当前有两个活动包：

```text
new-framework-core
  kernel、public facade、runtime、proof API、self-domain source、bootstrap reports

domain-app
  外部 domain/frontend 包，使用 Framework.* facade 编写业务
```

提交到仓库里的源码就是 core source。`self-artifact-witness` 会从当前源码生成隔离的 Stage 1 artifact，并在替换或发布前完成验证。

## 快速开始

编译全部包：

```powershell
stack build
```

运行 domain frontend：

```powershell
stack exec mytest
```

生成 domain report：

```powershell
stack exec domain-app-report
```

检查 framework fixed point：

```powershell
stack exec fixed-point-smoke
```

验证 workflow 真实语义：

```powershell
stack exec workflow-semantics-witness
```

生成并验证 Stage 1 artifact：

```powershell
stack exec self-artifact-witness
```

期望结果：

```text
domain-app-report: status passed
bootstrap-report: status passed
fixed-point-smoke: diffs: 0
workflow-semantics-witness: ok workflow semantics evidence
self-artifact-witness: passed
```

## 架构

业务作者使用 `Framework.*` facade：

```haskell
import Framework.Workflow
import Framework.Effect
import Framework.Background
```

facade 模块：

```text
Framework.Workflow        workflow AST 构造器
Framework.Effect          effect theory DSL
Framework.Background      runtime、reports、diagnosis、proof facade
Framework.Runtime         typed RuntimeM interpreter API
Framework.Domain          domain 注册和 reports
Framework.FixedPoint      bootstrap-vs-facade evidence 对比
Framework.RegistryCodegen registry 渲染和 generated-line 检查
Framework.SelfArtifact    隔离 Stage 1 artifact 物化
```

内部层：

```text
Bootstrap.*
  framework-core 自举验证使用的 native kernel

Domain.*
  framework-core 自身的 self-domain expression

domain-app/src/*
  外部业务代码；导入 facade 模块和本地 domain 模块
```

边界规则：

```text
Bootstrap.* 禁止导入 Framework.*。
domain-app/src 和 domain-app/app 禁止导入 Bootstrap.*。
new-framework-core/src/Domain 通过 public facade style 表达 framework-core。
```

边界检查：

```powershell
rg -n "^import\s+Framework\." new-framework-core/src/Bootstrap
rg -n "^import\s+Bootstrap\." domain-app/src domain-app/app
```

两个命令应无输出。

## 编写业务

`domain-app` 展示业务侧形态：

```text
domain-app/src/Domain/Vocabulary.hs
domain-app/src/Domain/AppBlueprint.hs
domain-app/src/Effects/Theory.hs
domain-app/src/Domain/Runtime.hs
domain-app/src/Domain/SemanticEvidence.hs
domain-app/src/SelfDomainApp.hs
domain-app/app/Main.hs
```

### 1. 定义词汇

在 `Domain.Vocabulary` 和 `Domain.EffectVocabulary` 声明：

```text
domain facts
send names
type names
transform names
```

名称要稳定。report、runtime trace、diagnosis、proof evidence 都通过这些名称串联。

### 2. 编写 Workflow AST

在 `Domain.AppBlueprint` 中使用 `Blueprint` 和 `Framework.Workflow`。

常用构造：

```text
chain
parallel
fallback
race
choice
wait
fact
hanging
middleware
callback
suspense
loop
```

workflow runtime 语义：

```text
chain      按顺序执行，遇到第一个失败即停止
parallel   从同一输入 runtime state 并发启动所有分支，按 blueprint 顺序合并成功分支
race       并发启动所有分支，保留第一个成功分支，取消剩余分支
fallback   按顺序尝试分支，失败分支 state 不污染后续分支
choice     只执行匹配 selected ChoiceKey 的分支
wait       fact expression 满足后执行 body
FactAll    所有表达式都要满足
FactAny    按顺序尝试表达式，保留第一个成功表达式
loop       运行到 facts/runtime values 固定点，最多 16 轮
callback   目标 component 进入时触发；失败会记录，不中断目标 flow
middleware 记录 body 前后的 entered/exited 事件，失败路径同样记录退出
suspense   记录目标状态和轻量 RuntimeSnapshot
```

示例形态：

```haskell
appFlow :: App
appFlow =
  chain AppFlow
    [ parallel BootPreparation
        [ fact [AppStartedFact]
        , fact [RuntimePreparedFact]
        ]
    , wait
        (allOf [UserKnownFact])
        (fact [ReportGeneratedFact])
    ]
```

### 3. 声明 Effect Theory

在 `Effects.*` 中使用 `Framework.Effect`。

核心声明：

```text
needs          fact 依赖
take           pipe 输入类型
make           pipe 输出类型
uses           外部 send boundary
externalMake   send boundary 声明
transform      typed value 转换
error          error handler 分发
idempotent     可重放 send 标记
retry          retry policy
```

effect theory 把 workflow facts、runtime handlers、generated reports 连接成同一套契约。

### 4. 实现 Runtime Handlers

在 `Domain.Runtime` 中使用 `Framework.Background` 和 `Framework.Runtime`。

runtime 支持：

```text
RuntimeM
RuntimeTypedValue
SomeRuntimeValue
ValueTag
RuntimeHandler
HandlerSucceededTyped
RuntimeTransform
HandlerRegistry
TransformRegistry
RuntimeEffectEnvironment
```

当前 domain 演示的 typed pipeline：

```text
AskUserName -> UserName
UserNameToReportInput: UserName -> ReportInput
GenerateReport: ReportInput -> ReportOutput
```

### 5. 接入入口

frontend executable 直接使用声明式源码：

```haskell
main :: IO ()
main =
  currentInterpreter currentAst currentEffects
```

运行：

```powershell
stack exec mytest
```

### 6. 注册 Semantic Evidence

domain evidence 位于 `Domain.SemanticEvidence`，通过 `SelfDomainApp` 挂接。

当前 evidence：

```text
constraint-ir-built
constraint-proof-passed
constraint-negative-check
runtime-closure-executed
runtime-diagnosis-error-handler
runtime-diagnosis-retry-probe
runtime-diagnosis-non-idempotent-blocker
registry-codegen-plugins
registry-codegen-effects
```

验证：

```powershell
stack exec domain-app-report
stack exec domain-app-self-smoke
```

## Diagnosis 与 Proof

`Framework.Background` 重新导出 runtime diagnosis 和 constraint proof API：

```text
Framework.Background.RuntimeDiagnosis
Framework.Background.ConstraintProof
```

runtime diagnosis 覆盖：

```text
handler 失败
output 不匹配
缺少 handler input
缺少 transform
ErrorInput error handler 分发
idempotent RetryOnce replay
diagnosis probes
非幂等 replay 阻断
```

constraint/proof 支持：

```text
constraint IR 提取
纯 Haskell proof evidence
可选 z3/cvc5 solver witness
facts、errors、propositions、results 渲染 helpers
```

外部 SMT solver 查找顺序：

```powershell
$env:Z3_EXE = "D:\smt solver\z3\bin\z3.exe"
$env:CVC5_EXE = "D:\tools\cvc5\bin\cvc5.exe"
```

未设置显式 exe 时，会继续从 `PATH` 查找 `z3` 和 `cvc5`。

SMT 模式：

```powershell
$env:FRAMEWORK_SMT = "off"
$env:FRAMEWORK_SMT = "auto"
$env:FRAMEWORK_SMT = "required"
stack exec constraint-proof-witness -- --smt=off
stack exec constraint-proof-witness -- --smt=auto
stack exec constraint-proof-witness -- --smt=required
```

模式含义：

```text
off       只跑 Haskell proof evidence
auto      默认模式；发现 solver 就调用，缺 solver 时保持通过
required  强制外部 solver 可用；缺失、失败、unknown 都会使 witness 失败
```

验证：

```powershell
stack exec runtime-diagnosis-witness
stack exec constraint-proof-witness -- --smt=auto
```

## Registry 代码生成

registry codegen 已表达在 framework semantics 中。

domain registry spec：

```text
domain-app/src/Domain/RegistryCodegenSpec.hs
```

生成行 evidence 检查：

```text
domain-app/src/Plugins.hs
domain-app/src/Effects/Theory.hs
```

运行：

```powershell
stack exec registry-codegen-witness
```

## 自举

每次 framework 改动都要先自证。

core self-validation：

```powershell
stack exec framework-core-mytest
stack exec bootstrap-smoke
stack exec bootstrap-runtime-smoke
stack exec bootstrap-report
stack exec fixed-point-smoke
```

fixed-point 比较：

```text
Stage 0: Bootstrap.* direct framework-core report
Stage 1: Framework.* facade/domain framework-core report
```

通过结果：

```text
fixed-point-smoke: diffs: 0
```

artifact gate 会物化 `.generated/stage1-framework`，并在隔离包中运行：

```text
stack build
stack exec bootstrap-report
stack exec fixed-point-smoke
stack exec constraint-proof-witness -- --smt=auto
stack exec workflow-semantics-witness
stack exec domain-app-report
stack exec registry-codegen-witness
```

运行：

```powershell
stack exec self-artifact-witness
```

详细 gate 规则：[docs/SELF_BOOTSTRAP_GATE.md](docs/SELF_BOOTSTRAP_GATE.md)

workflow 语义：[docs/WORKFLOW_SEMANTICS.md](docs/WORKFLOW_SEMANTICS.md)

## 命令索引

日常开发：

```powershell
stack build
stack exec mytest
stack exec domain-app-report
```

framework 验证：

```powershell
stack exec framework-core-mytest
stack exec bootstrap-smoke
stack exec bootstrap-runtime-smoke
stack exec bootstrap-report
stack exec fixed-point-smoke
```

witness：

```powershell
stack exec runtime-diagnosis-witness
stack exec constraint-proof-witness -- --smt=auto
stack exec workflow-semantics-witness
stack exec registry-codegen-witness
stack exec self-artifact-witness
```

完整 gate：

```powershell
stack build
stack exec mytest
stack exec domain-app-report
stack exec domain-app-self-smoke
stack exec framework-core-mytest
stack exec bootstrap-smoke
stack exec bootstrap-runtime-smoke
stack exec bootstrap-report
stack exec fixed-point-smoke
stack exec workflow-semantics-witness
stack exec runtime-diagnosis-witness
stack exec constraint-proof-witness -- --smt=auto
stack exec registry-codegen-witness
stack exec self-artifact-witness
```
