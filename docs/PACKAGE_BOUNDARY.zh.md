# 包边界

当前 build surface 有两个包：

```text
new-framework-core
domain-app
```

旧 `framework-core/` 目录已经从当前架构中移除，不作为源码、package dependency 或 source catalog 保留。

## 1. new-framework-core

`new-framework-core` 是新的 compiler/core 包，拥有：

```text
Bootstrap.Workflow
Bootstrap.Effect
Bootstrap.Runtime
Bootstrap.Report
Domain.Ast
Domain.Effects
Domain.EffectHandlers
Domain.Interpreter
Domain.Registry
```

生产 registry 只注册：

```text
framework-core
```

core 自带可执行：

```text
mytest
domain-registry
ast-tree
domain-map
bootstrap-smoke
bootstrap-runtime-smoke
bootstrap-report
```

## 2. domain-app

`domain-app` 是外部使用者，不是 core 实现容器。

它只暴露：

```text
SelfDomainApp
```

它的内容是 `framework-core` 自身：

```text
domain-app:self-framework-core
  content: framework-core
```

验证入口：

```text
domain-app-self-smoke
```

## 3. Source Catalog

native import graph 当前扫描：

```text
new-framework-core/src
domain-app/src
```

core boundary 检查只针对：

```text
new-framework-core/src
```

这保证当前 core 不再从旧实现目录偷读任何源码。

## 4. Import 规则

production source 允许：

```text
Bootstrap.*
Domain.*
SelfDomainApp
Blueprint
Prelude
base libraries
```

production source 禁止：

```text
Framework.Workflow
Framework.Effect
Framework.Background
Framework.Background.*
Core.*
Interpreter.*
old generated registry modules
```

`Bootstrap.CoreSurface` 里的历史 `Framework.*` 字符串是 catalog data，不是 import。

## 5. Setup 规则

`Setup.hs` 保持最小：

```haskell
main = defaultMain
```

任何未来 generator 都必须生成 framework expression 代码，不能生成旧业务 registries。
