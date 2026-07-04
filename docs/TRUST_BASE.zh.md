# TrustBase

TrustBase 是本轮验证使用的上一代 compiled core。

```text
round N:
  core_0 as TrustBase -> core_1 as candidate -> empty_business

round N+1:
  core_1 as TrustBase -> core_2 as candidate -> empty_business
```

实现上，TrustBase 是一组已编译 library artifacts、executable entrypoints、manifest 和 gate scripts 的组合。

## 1. TrustBase Surface

```text
compiled library modules
  Framework.*
  Bootstrap.*
  FrameworkCore.*

executable entrypoints
  core-self-interpret
  trust-base-manifest-witness
  architecture-concern-witness
  ast-layout

contracts
  trust-base-manifest.v2
  trust-base-manifest-evidence.v1
  schema catalog
  check-fast / check-semantic / check-release
```

主要入口：

```powershell
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
```

## 2. Host Boundary

外部宿主：

```text
GHC
Stack
OS
filesystem
process
terminal encoding
```

当前 kernel：

```text
Bootstrap.Runtime.Types
Bootstrap.Runtime.Build
Bootstrap.Runtime.Contract
Bootstrap.Runtime.Interpreter
Bootstrap.Runtime.BootstrapHandlers
```

这些模块提供 NativeAppPlan 构建、workflow/fact closure 解释、external boundary 调用和 evidence artifact 生成。

## 3. Semantic Handles

影响 framework 承诺的能力需要可追踪 handle：

```text
fact
effect dependency
send boundary
evidence artifact
witness/report gate
schema entry
```

Runtime 语义 facts：

```text
RuntimePlanBuiltFact
RuntimeFactRuleClosureValidatedFact
RuntimeArtifactClosureValidatedFact
RuntimeSendBoundaryCoveredFact
RuntimeHandlerRegistryValidatedFact
RuntimeTransformRegistryValidatedFact
RuntimePlanBuildEvidencePassedFact
RuntimeValidationEvidencePassedFact
RuntimeExecutionEvidencePassedFact
RuntimeConcurrencyEvidencePassedFact
RuntimeErrorDispatchValidatedFact
RuntimeRetryPolicyValidatedFact
RuntimeIdempotencyPolicyValidatedFact
RuntimeDiagnosisEvidencePassedFact
RuntimeBackendParityEvidencePassedFact
RuntimeEvidencePassedFact
```

## 4. Manifest

`Framework.TrustBase.Manifest` 输出 TrustBase 结构化边界。

```text
trust-base-manifest.v2
trust-base-manifest-evidence.v1
schema-catalog-evidence.v1
host boundary
kernel modules
facade modules
report executables
witness executables
artifact gate executable
artifact sources
artifact commands
json schemas
gate policies
```

命令：

```powershell
stack --work-dir .stack-work-codex exec trust-base-manifest-witness
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
```

`--evidence-json` 检查 cabal、CoreSurface、schema catalog、defaultSelfArtifactManifest 和 check script 清单。

Schema catalog：

```powershell
stack --work-dir .stack-work-codex exec schema-catalog-witness -- --json
```

## 5. Gates

Default release proof：

```powershell
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
```

Artifact gate：

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

Stage1 artifact commands：

```text
stack build
core-self-interpret -- --json
trust-base-manifest-witness -- --evidence-json
architecture-concern-witness -- --json
```

## 6. Facade

Developer-facing facade：

```text
Framework.Ast       AST foreground
Framework.Effect    effect theory foreground
Framework.Business  capability / pipeline foreground
Framework.Handler   handler / transform implementation
Framework.TrustBase self-iteration, evidence, manifest, artifact gate
```

Internal/devtools surface：

```text
Bootstrap.Runtime.*
Framework.Runtime
Framework.Background
```

业务热路径运行 workflow/effect plan。自举 evidence 运行在 witness/report/gate 中。
