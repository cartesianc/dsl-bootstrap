# dsl-bootstrap

`dsl-bootstrap` is a self-expressing Haskell framework experiment. The current
repository deliberately keeps two layers in one place:

```text
default business frontend
  ordinary business authoring and the external domain acceptance app

framework maintenance / self-bootstrap layer
  Bootstrap.*, Domain.* framework-core self-expression, TrustBase, witnesses,
  manifests, self-artifact checks, and promotion gates
```

This branch treats the business frontend as a **candidate default business
frontend**. It is the recommended path for ordinary business code, but it is not
yet a strong long-term SDK compatibility promise.

## Default Business Path

Business authors should normally start from these modules:

```haskell
import Framework.Ast
import Framework.Business
import Framework.Handler
import Framework.App
```

Use them as follows:

```text
Framework.Ast
  AppBlueprint, workflow AST, facts, names, and hanging hooks

Framework.Business
  capability, pipeline, policy, handler binding, transform binding, and
  capability-to-effect lowering

Framework.Handler
  typed values, handlers, transforms, registries, and RuntimeEffectEnvironment

Framework.App
  thin runner facade for AppBlueprint + EffectTheory + RuntimeEffectEnvironment
```

`Framework.Effect` remains exposed as normalized IR / compatibility /
framework-internal surface. It is not the default starting point for ordinary
business authoring.

`Framework.TrustBase`, `Framework.SelfArtifact`, `Framework.FixedPoint`,
`Framework.Runtime.Evidence*`, `Bootstrap.*`, and witness executables remain in
the repository, but they are maintenance and acceptance surfaces rather than
ordinary business imports.

Start here:

- [Candidate default business frontend](docs/STABLE_FRONTEND.zh.md)
- [Capability frontend](docs/CAPABILITY_FRONTEND.zh.md)
- [Migrate from Effect IR to capabilities](docs/SDK_MIGRATION_FROM_EFFECT_IR.zh.md)
- [Domain app acceptance flow](domain-app/README.md)

## Maintenance Path

Framework maintainers continue to use the self-interpretation line:

```text
core_0 -> new_core -> empty_business
```

The core maintenance layer keeps:

```text
Bootstrap.*
Domain.* framework-core self-expression
Framework.TrustBase
Framework.SelfArtifact
Framework.FixedPoint
Framework.Runtime.Evidence*
witness executables
TrustBase manifest and schema catalog
promotion / self-artifact gates
```

Start here:

- [Project layout](docs/PROJECT_LAYOUT.zh.md)
- [Trust base](docs/TRUST_BASE.zh.md)
- [Core promotion SOP](docs/CORE_PROMOTION_SOP.zh.md)
- [Check patterns](docs/CHECK_PATTERNS.zh.md)

## Common Commands

Fast local confidence stays intentionally light:

```powershell
.\scripts\check-fast.cmd
```

It expands to:

```text
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
```

Semantic checks include the business boundary and external domain acceptance
app:

```powershell
.\scripts\check-semantic.cmd
```

Release checks do not run `self-artifact-witness` by default:

```powershell
.\scripts\check-release.cmd
```

Promotion runs the artifact gate only when requested explicitly:

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

To inspect command lists without running them:

```powershell
.\scripts\check-fast.cmd -List
.\scripts\check-semantic.cmd -List
.\scripts\check-release.cmd -List
```

Useful focused witnesses:

```powershell
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec domain-app-report -- --json
stack --work-dir .stack-work-codex exec runtime-hot-path-witness -- --json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
```

## Boundary Rule

Ordinary business authoring files are guarded by `business-syntax-witness`.
They should use only the default business frontend modules listed above.

Acceptance/reporting code is different. `SelfDomainApp`,
`Domain.SemanticEvidence`, diagnosis witnesses, reports, and maintenance tools
may use framework evidence and reporting APIs because they are not ordinary
business authoring surfaces.
