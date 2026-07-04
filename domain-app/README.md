# domain-app

`domain-app` is the external acceptance app for the business frontend. It shows
how ordinary business modules use `Framework.Ast`, `Framework.Business`,
`Framework.Handler`, and `Framework.App`.

Maintenance and self-bootstrap artifacts live in the framework layer.

## Business Flow

```text
configure app
  -> start app and prepare runtime
  -> ask / greet / remember user
  -> open calculation section
  -> calculate add / factorial / squares
  -> generate report
  -> finish app
```

## Source Layers

```text
Domain.Vocabulary
  workflow fact names

Domain.EffectVocabulary
  send/type/handler/transform names

Domain.AppBlueprint
  AppBlueprint and workflow composition through Framework.Ast

Domain.Business
  capability declarations through Framework.Business

Effects.*
  capability groups lowered to EffectTheory through Framework.Business

Domain.Runtime
  typed values, handlers, transforms, and RuntimeEffectEnvironment through Framework.Handler

app/InterpretConfig.hs
  business runner through Framework.App

Domain.SemanticEvidence / SelfDomainApp
  acceptance and reporting layer
```

`Domain.SemanticEvidence` and `SelfDomainApp` can use evidence and reporting APIs
because they produce acceptance reports.

## Import Boundary

Ordinary authoring files stay on:

```text
Framework.Ast
Framework.Business
Framework.Handler
Framework.App
```

Avoid these imports in ordinary authoring files:

```text
Bootstrap.*
Framework.TrustBase
Framework.SelfArtifact
Framework.FixedPoint
Framework.Runtime.Evidence*
Framework.Runtime
Framework.Effect
```

Witnesses and acceptance code may inspect normalized IR through `Framework.Effect`.

## Verification

```powershell
stack --work-dir .stack-work-codex exec mytest
stack --work-dir .stack-work-codex exec domain-app-report -- --json
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
```

`business-syntax-witness` checks capability lowering, authoring imports,
`Framework.App` runner usage, handler/transform shape, friendly diagnostics,
EffectRow algebra, and the typed runtime pipeline adapter.
