# domain-app

`domain-app` is the external acceptance app for the framework business frontend.
It is not a self-bootstrap artifact and it is not a TrustBase app.

The app stays in this repository to prove that ordinary business code can use
the candidate default business frontend without importing the maintenance layer.

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
  stable workflow fact names

Domain.EffectVocabulary
  stable send/type/handler/transform names

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

`Domain.SemanticEvidence` and `SelfDomainApp` are allowed to use evidence and
reporting APIs because they are acceptance/reporting code, not ordinary business
authoring.

## Boundary

Ordinary authoring files should stay on:

```text
Framework.Ast
Framework.Business
Framework.Handler
Framework.App
```

They should not import:

```text
Bootstrap.*
Framework.TrustBase
Framework.SelfArtifact
Framework.FixedPoint
Framework.Runtime.Evidence*
Framework.Runtime
Framework.Effect
```

`Framework.Effect` may still appear in witnesses or acceptance code when the
test needs to inspect normalized IR.

## Verification

```powershell
stack --work-dir .stack-work-codex exec mytest
stack --work-dir .stack-work-codex exec domain-app-report -- --json
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
```

`business-syntax-witness` checks capability lowering, authoring imports,
`Framework.App` runner usage, handler/transform shape, friendly diagnostics, and
the typed runtime pipeline adapter.
