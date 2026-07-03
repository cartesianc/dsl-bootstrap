# domain-app

`domain-app` 用来验证业务侧如何通过 framework facade 编写声明式 domain。

它当前保持小型、声明式，重点验证 facade 边界、capability lowering、handler/transform 和 evidence 是否能在 domain 侧闭合。

当前业务流程：

```text
configure app
  -> start app and prepare runtime
  -> ask / recognize / remember user
  -> open calculation report
  -> calculate add / factorial / squares facts
  -> generate report
  -> finish app
```

业务链路：

```text
Domain.Business capability
  -> Effects.* lowering
  -> effect IR
  -> Domain.Runtime handler/transform
  -> domain-app-report / business-syntax-witness
```

前台源码应该像配置文件：

```text
Domain.AppBlueprint
  只组合 app flow 和 hanging hook

Plugins.*
  只放命名 workflow fragment

Effects.*
  只做 lowering 薄层

Domain.Vocabulary / Domain.EffectVocabulary
  只放稳定命名

Domain.Business
  业务声明入口：capability、pipeline、policy、handler binding、transform binding

Domain.Runtime
  执行、IO、typed value conversion、handler 和 transform 实现

Domain.SemanticEvidence
  evidence probe 和 generated-source check
```

算法、IO、retry 行为和 typed value conversion 放进 `Domain.Runtime`。`Domain.AppBlueprint`、`Plugins.*`、`Domain.Business` 和 `Effects.*` 只保留声明和 lowering。

`Effects.*` 每个模块只把一组 capability 通过 `Framework.Business.capabilitiesEffect` lower 成 effect IR。

业务编写从 `Framework.Business` capability 开始。`Framework.Effect` 用在 lowering 后的规范化语义 IR。
