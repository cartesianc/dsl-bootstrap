# dsl-bootstrap

`dsl-bootstrap` is a Haskell framework experiment with two audiences in one
repository.

```text
Business developers
  Write workflows, capabilities, handlers, and a small app runner.

Framework maintainers
  Work on Bootstrap.*, framework-core self-expression, TrustBase, witnesses,
  manifests, self-artifact checks, and promotion gates.
```

## Business Developer Path

Start business code from these modules:

```haskell
import Framework.Ast
import Framework.Business
import Framework.Handler
import Framework.App
```

Use them like this:

```text
Framework.Ast
  AppBlueprint, workflow AST, facts, names, and hanging hooks.

Framework.Business
  capability, pipeline, policy, handler binding, transform binding, and
  capability-to-effect lowering.

Framework.Handler
  typed values, handlers, transforms, registries, and RuntimeEffectEnvironment.

Framework.App
  thin runner for AppBlueprint + EffectTheory + RuntimeEffectEnvironment.
```

Compatibility note: this is the current recommended business path. A stronger
SDK compatibility promise should come after more real business acceptance apps.

`Framework.Effect` remains available for normalized IR, compatibility code,
framework internals, and witnesses. New business code usually starts with
`Framework.Business`.

Maintenance modules such as `Framework.TrustBase`, `Framework.SelfArtifact`,
`Framework.FixedPoint`, `Framework.Runtime.Evidence*`, `Bootstrap.*`, and
witness executables stay in the repository. Business authoring code should keep
its imports on the four modules listed above.

Start here:

- [Default business frontend](docs/STABLE_FRONTEND.zh.md)
- [Capability frontend](docs/CAPABILITY_FRONTEND.zh.md)
- [Migrate from Effect IR to capabilities](docs/SDK_MIGRATION_FROM_EFFECT_IR.zh.md)
- [Domain app acceptance flow](domain-app/README.md)

## Framework Maintainer Path

Maintainers use the self-interpretation line:

```text
core_0 -> new_core -> empty_business
```

The maintenance layer contains:

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

Fast local check:

```powershell
.\scripts\check-fast.cmd
```

Command list:

```text
stack --work-dir .stack-work-codex build
stack --work-dir .stack-work-codex exec core-self-interpret -- --json
```

Semantic check:

```powershell
.\scripts\check-semantic.cmd
```

Release pre-check:

```powershell
.\scripts\check-release.cmd
```

Promotion artifact check:

```powershell
.\scripts\check-release.cmd -IncludeSelfArtifact
```

Print script command lists:

```powershell
.\scripts\check-fast.cmd -List
.\scripts\check-semantic.cmd -List
.\scripts\check-release.cmd -List
```

Focused checks:

```powershell
stack --work-dir .stack-work-codex exec business-syntax-witness -- --json
stack --work-dir .stack-work-codex exec domain-app-report -- --json
stack --work-dir .stack-work-codex exec runtime-hot-path-witness -- --json
stack --work-dir .stack-work-codex exec architecture-concern-witness -- --json
stack --work-dir .stack-work-codex exec trust-base-manifest-witness -- --evidence-json
```

## Import Boundary

`business-syntax-witness` checks ordinary business authoring files. Those files
stay on:

```text
Framework.Ast
Framework.Business
Framework.Handler
Framework.App
```

Acceptance and reporting code, including `SelfDomainApp`,
`Domain.SemanticEvidence`, diagnosis witnesses, reports, and maintenance tools,
may use evidence and reporting APIs.
