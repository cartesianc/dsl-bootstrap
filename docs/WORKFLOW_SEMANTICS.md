# Workflow 语义

本文记录 workflow AST 的 runtime 合约。

## Runtime 合约

```text
chain      按顺序执行 step，遇到第一个失败即停止
parallel   从同一输入 runtime state 并发启动所有分支
race       并发启动所有分支，保留第一个成功分支
fallback   按顺序尝试分支，失败分支 state 不进入后续分支
choice     只执行 selected ChoiceKey 对应的分支
wait       fact expression 满足后执行 body
FactAll    每个表达式都要满足
FactAny    按顺序尝试表达式，保留第一个成功表达式
loop       运行到 facts/runtime values 固定点，最多 16 轮
callback   目标 component 进入时触发；失败写入记录
middleware 记录 body 前后的 entered/exited 事件，失败路径同样记录退出
suspense   记录目标状态和轻量 RuntimeSnapshot
```

`parallel` 和 `race` 使用真实 runtime branch。每个 branch 都从同一份输入 runtime state 启动。`parallel` 按 blueprint 分支顺序合并结果。同一 `TypeName` 在多个成功分支中产生不同 value 时，`parallel` 返回 merge conflict。

`suspense` 只捕获可渲染的 runtime snapshot。数据库 schema、resume queue、分布式恢复由 host 层设计。

## 见证程序

运行：

```powershell
stack exec workflow-semantics-witness
```

witness 覆盖：

```text
parallel 并发执行
parallel value 冲突
race 取消慢分支
race 全失败 exhausted
fallback 隔离失败分支 state
choice 精确匹配 selected key
FactAny 顺序选择
loop 固定点
middleware 失败路径退出事件
suspense snapshot
callback 失败记录
Bootstrap.Runtime / Framework.Runtime fact 对齐
```
