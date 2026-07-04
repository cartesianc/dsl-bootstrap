# Candidate Default Business Frontend

本文定义当前仓库的 candidate default business frontend。这里的 stable 是“默认前台契约正在收口”，不是已经承诺永久兼容。

## 默认业务入口

普通业务作者默认使用：

```text
Framework.Ast
Framework.Business
Framework.Handler
Framework.App
```

职责：

```text
Framework.Ast
  AppBlueprint and workflow AST

Framework.Business
  capability authoring and capability-to-effect lowering

Framework.Handler
  handler / transform implementation and RuntimeEffectEnvironment

Framework.App
  thin app runner facade
```

`Framework.App` 只解决业务运行代码从 `Framework.TrustBase` 拿 runner 的尴尬。它不承接 report、diagnosis、domain registration、manifest、self-artifact 或 promotion gate。

## 非默认业务入口

以下模块仍然存在并继续服务框架维护者，但 they are not a default business import：

```text
Framework.TrustBase
Framework.SelfArtifact
Framework.FixedPoint
Framework.Runtime.Evidence*
Bootstrap.*
witness executables
manifest and promotion gate code
```

`Framework.Effect` 继续 exposed，定位是：

```text
normalized IR
compatibility surface
framework-internal source
witness / test IR
```

普通业务文档不再推荐从 `Framework.Effect` 开始。

## Authoring 与 Acceptance

普通 authoring 区域：

```text
Domain.Business
Domain.AppBlueprint
Domain.Runtime
Domain.Vocabulary
Domain.EffectVocabulary
Effects.*
Plugins.*
```

这些区域由 `business-syntax-witness` 约束，只使用默认业务前台模块。

验收/报告层不同：

```text
SelfDomainApp
Domain.SemanticEvidence
domain-app-report
runtime diagnosis witness
business-syntax-witness
```

这些可以使用 evidence/reporting API，因为它们负责验收结果，而不是普通业务声明。

## Gate

```text
check-fast
  build + core-self-interpret

check-semantic
  build + core-self-interpret + business-syntax-witness + domain-app-report
  + trust-base-manifest-witness + architecture-concern-witness

check-release
  non-promotion release gate; self-artifact is still excluded by default

check-release -IncludeSelfArtifact
  explicit promotion artifact gate
```

## Current Contract

本轮只做边界标注、前台 API 收口、业务 import 护栏、错误文案映射、文档默认路径、门禁分层和复杂度护栏。

本轮不做：

```text
split into a separate SDK package
hide or remove Bootstrap.*
hide or remove Framework.TrustBase
remove self-bootstrap business
change promotion gate semantics
```
