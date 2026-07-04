# 默认业务前台

本文说明普通业务开发者的推荐入口。长期 SDK 兼容承诺会在更多业务验收后单独发布。

## 推荐导入

业务代码从这四个模块开始：

```haskell
import Framework.Ast
import Framework.Business
import Framework.Handler
import Framework.App
```

职责划分：

```text
Framework.Ast
  AppBlueprint、workflow AST、fact、name、hanging hook。

Framework.Business
  capability 声明，以及 capability 到 effect theory 的 lowering。

Framework.Handler
  handler、transform、typed runtime value、RuntimeEffectEnvironment。

Framework.App
  AppBlueprint + EffectTheory + RuntimeEffectEnvironment 的运行入口。
```

`Framework.App` 的范围很小：`runApp`、`runAppResult`、`runAppRuntimeResult`
和错误渲染。报告、domain registration、manifest、self-artifact、promotion
gate 保持在维护层模块中。

## 维护入口

下面这些模块服务框架维护、报告、验收和发布流程：

```text
Framework.TrustBase
Framework.SelfArtifact
Framework.FixedPoint
Framework.Runtime.Evidence*
Bootstrap.*
witness executables
manifest and promotion gate code
```

业务 authoring 文件保持在推荐导入列表上。维护工具、witness 和报告程序可以使用维护入口。

`Framework.Effect` 继续作为 normalized IR、兼容代码、框架内部实现和 witness
检查使用。新业务代码通常通过 `Framework.Business` 描述 capability。

## 普通业务文件

`business-syntax-witness` 检查这些 authoring 区域：

```text
Domain.Business
Domain.AppBlueprint
Domain.Runtime
Domain.Vocabulary
Domain.EffectVocabulary
Effects.*
Plugins.*
```

这些文件使用默认业务前台模块。

## 验收和报告文件

验收和报告文件负责读取证据、生成报告、检查运行结果：

```text
SelfDomainApp
Domain.SemanticEvidence
domain-app-report
runtime diagnosis witness
business-syntax-witness
```

这些文件可以使用 reporting/evidence API。

## Gate

```text
check-fast
  build + core-self-interpret

check-semantic
  build + core-self-interpret + business-syntax-witness + domain-app-report
  + trust-base-manifest-witness + architecture-concern-witness

check-release
  release pre-check without the self-artifact promotion gate

check-release -IncludeSelfArtifact
  explicit promotion artifact gate
```

## 当前范围

本页描述当前仓库内的默认业务前台。它建立入口、import 边界、错误文案、
文档路径、gate 分层和复杂度护栏。

包拆分、隐藏内部模块、删除自举业务和 promotion gate 语义调整属于后续设计。
