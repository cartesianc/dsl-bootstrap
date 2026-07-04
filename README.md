# dsl-bootstrap

## 项目说明

`dsl-bootstrap` 是一个自举式 Haskell 业务框架实验仓库。它展示一套业务 DSL 如何用声明式源码表达 workflow、effect、runtime handler 和 semantic evidence，并把这些声明连接到 report、proof、diagnosis、codegen 和 artifact gate。

这个仓库面向框架开发者、代码审查者，以及想理解自举机制的使用者。当前发布形态保留 framework core、自表达 domain、domain 侧验收应用和 `TrustBase` gates，方便审查框架如何保持 facade 边界、如何自证、如何物化下一阶段 artifact。面向普通业务集成的裁剪版 SDK 会在单独发布边界里收敛。

业务 authoring surface 从 `Framework.Business` capability 开始。`Framework.Effect` 承接 lowering 后的 normalized semantic IR、compatibility layer 和 framework/internal 表达。

业务侧代码保持声明式：

- workflow AST
- capability frontend
- normalized effect/fact IR
- typed runtime handlers
- semantic evidence
- framework 自证

仓库当前有两个主要包：

```text
new-framework-core
  framework/compiler core，包含 public facade、runtime、proof API、self-domain source 和 bootstrap reports

domain-app
  domain 侧验收应用，使用 Framework.* facade 编写业务声明、handler 和 semantic evidence
```

说明性文档只服务阅读和维护，不进入 Stage 1 framework artifact。`self-artifact-witness` 只复制 framework/code inputs，用于生成隔离 artifact 并验证下一阶段框架。

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
stack exec domain-app-report -- --json
```

验证 capability 前台和 lowering 语法：

```powershell
stack exec business-syntax-witness
stack exec business-syntax-witness -- --json
```

检查 framework fixed point：

```powershell
stack exec fixed-point-smoke
```

检查 runtime evidence payload：

```powershell
stack exec runtime-evidence-witness
stack exec runtime-evidence-witness -- --json
```

检查 TrustBase manifest：

```powershell
stack exec trust-base-manifest-witness
stack exec trust-base-manifest-witness -- --json
stack exec trust-base-manifest-witness -- --evidence-json
```

验证 workflow 真实语义：

```powershell
stack exec workflow-semantics-witness
stack exec workflow-semantics-witness -- --json
stack exec workflow-semantics-witness -- --runtime-concurrency-json
```

Check facade：

```powershell
.\scripts\check-fast.cmd
.\scripts\check-semantic.cmd
.\scripts\check-release.cmd
```

`check-release` 默认跳过 `self-artifact-witness`。发布轮次需要运行高危 artifact gate 时显式执行：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

先查看命令清单：

```powershell
.\scripts\check-release.cmd -List
```

Stage 1 artifact 验证不属于快速开始。`self-artifact-witness` 是高危/重型 artifact gate，只有一轮大构建和轻量 gates 都完成后才允许运行一次；同一轮第二次不允许继续跑，README/docs-only 变更也不触发它。

## 文档地图

维护者从 README 进入说明性文档；个人 TODO 和未定设计草稿不放进主导航。

```text
Repository purpose and layout
  docs/PROJECT_LAYOUT.zh.md
  docs/PACKAGE_BOUNDARY.zh.md

Self-bootstrap and trust base
  docs/TRUST_BASE.zh.md
  docs/SELF_BOOTSTRAP_GATE.md
  docs/CORE_BOOTSTRAP_DESIGN.zh.md

Runtime, workflow, and diagnosis semantics
  docs/RUNTIME_ARCHITECTURE.zh.md
  docs/WORKFLOW_SEMANTICS.md
  docs/DIAGNOSIS_SYSTEM.zh.md

Frontend syntax and AST
  docs/CAPABILITY_FRONTEND.zh.md
  docs/EFFECT_FRONTEND_SYNTAX.zh.md
  docs/AST_SPEC.zh.md

Verification commands
  docs/CHECK_PATTERNS.zh.md

Domain 侧验收应用
  domain-app/README.md
```

- [Project layout and repository purpose](docs/PROJECT_LAYOUT.zh.md)
- [Package boundary](docs/PACKAGE_BOUNDARY.zh.md)
- [Trust base](docs/TRUST_BASE.zh.md)
- [Self-bootstrap gate](docs/SELF_BOOTSTRAP_GATE.md)
- [Core bootstrap design](docs/CORE_BOOTSTRAP_DESIGN.zh.md)
- [Runtime architecture](docs/RUNTIME_ARCHITECTURE.zh.md)
- [Workflow semantics](docs/WORKFLOW_SEMANTICS.md)
- [Diagnosis system](docs/DIAGNOSIS_SYSTEM.zh.md)
- [Capability frontend](docs/CAPABILITY_FRONTEND.zh.md)
- [Effect IR and capability lowering](docs/EFFECT_FRONTEND_SYNTAX.zh.md)
- [AST specification](docs/AST_SPEC.zh.md)
- [Common check patterns and automated boundaries](docs/CHECK_PATTERNS.zh.md)
- [Domain app business flow](domain-app/README.md)

期望结果：

```text
domain-app-report: status passed
bootstrap-report: status passed
fixed-point-smoke: diffs: 0
runtime-evidence-witness: ok runtime evidence 6 payload claims
trust-base-manifest-witness: ok trust base manifest trust-base-manifest.v2
workflow-semantics-witness: ok workflow semantics evidence 14 payload claims
business-syntax-witness: ok business syntax evidence 17 payload claims
architecture-concern-witness: ok architecture concern evidence 11 payload claims
self-artifact-witness: passed (仅高危 artifact gate 轮次需要)
```

## 架构

业务作者默认使用 capability 前台：

```haskell
import Framework.Ast
import Framework.Business
```

handler 实现使用：

```haskell
import Framework.Handler
```

facade 模块：

```text
Framework.Ast             frontend AST / AppBlueprint / workflow 构造器
Framework.Business        业务编写入口：capability/pipeline/policy/binding DSL，暴露 NoInput/Unit/ErrorInput authoring token 和业务命名类型
Framework.Effect          normalized semantic IR / compatibility layer：effect/fact/needs/take/make/uses/externalMake
Framework.Handler         handler implementation API：typed values、handlers、transforms、registries，底层由 Runtime.Handlers / Runtime.Values 支撑
Framework.TrustBase       架构自我迭代 API：bootstrap runtime、evidence、diagnosis、reports、codegen、TrustBase manifest、artifact gate
Framework.Workflow        AST vocabulary 兼容别名
Framework.Background      compatibility/devtools facade
Framework.Runtime         internal/devtools compatibility facade，re-export Runtime.Interpreter
Framework.Runtime.Interpreter typed RuntimeM interpreter implementation，组合 Runtime.Types / Runtime.State / Runtime.Values / Runtime.Handlers / Runtime.Diagnosis
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

## 自举层定位

自举层服务 framework 迭代、语义迁移和内核替换。业务稳定版会把默认入口打薄。

业务作者默认只接触：

```text
business frontend:
Framework.Business
Framework.Ast

normalized semantic IR:
Framework.Effect

handler implementation:
Framework.Handler

self-iteration:
Framework.TrustBase
```

框架作者继续维护：

```text
Bootstrap.*
SelfArtifact
fixed-point gate
artifact materialization gate
workflow semantics witness
self-artifact witness
kernel replacement flow
```

发布自我迭代版 framework snapshot 时，自举工具、domain-side acceptance、fixed-point gate 和 artifact gate 都保留在仓库内。未来如果要单独发布面向业务用户的裁剪版，再把自举工具移动到 devtools/bootstrap 包或内部命令。

## 编写业务

`domain-app` 展示业务侧形态：

```text
domain-app/src/Domain/Vocabulary.hs
domain-app/src/Domain/AppBlueprint.hs
domain-app/src/Domain/Business.hs
domain-app/src/Effects/Theory.hs
domain-app/src/Domain/Runtime.hs
domain-app/src/Domain/SemanticEvidence.hs
domain-app/src/SelfDomainApp.hs
domain-app/app/Main.hs
```

业务侧链路：

```text
Domain.Business capability
  -> Effects.* lowering
  -> effect IR
  -> Domain.Runtime handler/transform
  -> report/evidence
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

在 `Domain.AppBlueprint` 中使用 `Blueprint` 和 `Framework.Ast`。

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

### 3. 声明 Capability 并 Lower 到 Effect IR

业务入口在 `Domain.Business` 中使用 `Framework.Business` 声明 capability、pipeline、handler binding 和 transform binding。`Domain.Business` 是业务声明来源。`Effects.*` 调用 `capabilitiesEffect` lower 成 effect IR，并保留 capability group metadata。

业务编写入口：

```text
capability
requires
input
output
uses
produces
policy
pipeline
handler binding
transform binding
```

`NoInput`、`Unit`、`ErrorInput`、`EffectUnit` 和业务命名类型由 `Framework.Business` 暴露，业务 capability source 和 `Effects.*` lowering facade 不需要为了 send boundary sentinel values、lowering result type 或 `SendName` / `TypeName` 这类 authoring name 直接导入 `Framework.Effect`。

normalized semantic IR 仍然保留：

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

业务写法规范：[docs/CAPABILITY_FRONTEND.zh.md](docs/CAPABILITY_FRONTEND.zh.md)

Effect IR 和 lowering 规范：[docs/EFFECT_FRONTEND_SYNTAX.zh.md](docs/EFFECT_FRONTEND_SYNTAX.zh.md)

### 4. 实现 Runtime Handlers

在 `Domain.Runtime` 中使用 `Framework.Handler`。业务前台不直接导入 runtime；handler 实现只拿 typed value、handler、transform 和 registry API。

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
runtime-diagnosis-system-root-cause
registry-codegen-plugins
registry-codegen-effects
```

验证：

```powershell
stack exec domain-app-report
stack exec domain-app-self-smoke
stack exec runtime-diagnosis-witness
stack exec runtime-diagnosis-witness -- --json
```

`runtime-diagnosis-witness` 输出 `RuntimeDiagnosisEvidencePayload`，每条 diagnosis claim 都包含 `claim`、`status`、`expected`、`observed` 和 `artifact` 字段。

## Diagnosis 与 Proof

`Framework.TrustBase` 统一承接 runtime diagnosis、constraint proof、fixed point、registry codegen 和 artifact gate API：

```text
Framework.TrustBase
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
EffectSystem root cause 归因
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
stack exec runtime-diagnosis-witness -- --json
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
stack exec registry-codegen-witness -- --json
```

## 自举

每次 framework 改动都要先自证。

core self-validation：

```powershell
stack exec framework-core-mytest
stack exec bootstrap-smoke
stack exec bootstrap-runtime-smoke
stack exec bootstrap-report
stack exec bootstrap-report -- --json
stack exec runtime-evidence-witness
stack exec runtime-evidence-witness -- --json
stack exec fixed-point-smoke
stack exec fixed-point-smoke -- --json
stack exec fixed-point-smoke -- --summary-json
stack exec trust-base-manifest-witness
stack exec trust-base-manifest-witness -- --json
stack exec trust-base-manifest-witness -- --evidence-json
```

JSON 输出带 schema 字段：

```text
framework-core-report.v1
domain-report.v1
fixed-point-report.v1
fixed-point-summary.v1
framework-core-frontend-evidence.v1
trust-base-manifest.v2
trust-base-manifest-evidence.v1
schema-catalog-evidence.v1
business-syntax-evidence.v1
runtime-evidence.v1
runtime-hot-path-evidence.v1
runtime-policy-evidence.v1
runtime-diagnosis-evidence.v1
registry-codegen-evidence.v1
workflow-semantics-evidence.v1
runtime-concurrency-evidence.v1
architecture-concern-evidence.v1
```

`bootstrap-report -- --json` 和 `domain-app-report -- --json` 输出 report 后会检查 `status`；`failed` 会让命令返回非零退出码。
`domain-app-report` 的 semanticEvidence 保留 `details`，同时每条都提供结构化 `payload`：`claim/status/expected/observed/artifact`。当前 payload 覆盖 built-in checks、runtime diagnosis 和 registry codegen evidence。

fixed-point 比较：

```text
Stage 0: Bootstrap.* direct framework-core report
Stage 1: Framework.* facade/domain framework-core report
```

通过结果：

```text
fixed-point-smoke: fixed-point diff evidence 14 payload claims
fixed-point-smoke: runtime backend parity evidence 4 payload claims
fixed-point-smoke: diffs: 0
runtime-evidence-witness: ok runtime evidence 6 payload claims
```

runtime evidence payload claims：

```text
runtime-plan-build-evidence
runtime-validation-evidence
runtime-execution-evidence
runtime-concurrency-evidence
runtime-diagnosis-evidence
runtime-backend-parity-evidence
```

backend parity payload claims：

```text
runtime-backend-parity-plan
runtime-backend-parity-fact-closure
runtime-backend-parity-artifact
runtime-backend-parity-report
```

artifact gate 会物化 `.generated/stage1-framework`，只复制 framework/code artifact inputs，不复制 `docs`、`README.md`、`CHANGELOG.md`、`TODO.md` 等说明性文档，并在隔离包中运行：

`self-artifact-witness` 是高危/重型 gate：只有大构建和轻量 gates 完成后才允许运行一次。同一轮第二次不允许继续跑；README/docs-only 变更不触发它。

```text
stack build
stack exec bootstrap-report
stack exec fixed-point-smoke
stack exec runtime-evidence-witness
stack exec constraint-proof-witness -- --smt=auto
stack exec workflow-semantics-witness
stack exec runtime-diagnosis-witness
stack exec framework-core-frontend-witness -- --json
stack exec domain-app-report
stack exec registry-codegen-witness -- --json
stack exec architecture-concern-witness -- --json
stack exec business-syntax-witness
```

运行：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
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
stack exec framework-core-frontend-witness -- --json
stack exec runtime-evidence-witness
stack exec runtime-diagnosis-witness
stack exec constraint-proof-witness -- --smt=auto
stack exec workflow-semantics-witness
stack exec registry-codegen-witness -- --json
stack exec architecture-concern-witness -- --json
stack exec business-syntax-witness
```

完整 gate：

```powershell
stack build
stack exec mytest
stack exec domain-app-report
stack exec domain-app-self-smoke
stack exec business-syntax-witness
stack exec framework-core-mytest
stack exec bootstrap-smoke
stack exec bootstrap-runtime-smoke
stack exec bootstrap-report
stack exec fixed-point-smoke
stack exec runtime-evidence-witness
stack exec workflow-semantics-witness
stack exec runtime-diagnosis-witness
stack exec constraint-proof-witness -- --smt=auto
stack exec registry-codegen-witness -- --json
stack exec architecture-concern-witness -- --json
```

高危 artifact gate（大构建完成后最多一次）：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```
