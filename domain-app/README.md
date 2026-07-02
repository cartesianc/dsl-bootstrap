# domain-app

`domain-app` is the external-user example for the framework facade. It is intentionally small and declarative.

The current business flow is:

```text
configure app
  -> start app and prepare runtime
  -> ask/recognize/remember user
  -> open calculation report
  -> calculate add/factorial/squares facts
  -> generate report
  -> finish app
```

The frontend source should read like a config file:

```text
Domain.AppBlueprint
  app and hanging hook composition only

Plugins.*
  named workflow fragments only

Effects.*
  thin lowering facade only

Domain.Vocabulary / Domain.EffectVocabulary
  stable names only

Domain.Business
  capability, pipeline, policy, handler binding, transform binding

Domain.Runtime
  handler and transform implementation

Domain.SemanticEvidence
  evidence probes and generated-source checks
```

Do not put algorithms in `Domain.AppBlueprint`, `Plugins.*`, `Domain.Business`, or `Effects.*`. If a step needs computation, IO, retry behavior, or typed value conversion, express the capability/send/transform in `Domain.Business` and implement the work in `Domain.Runtime` handlers or transforms.

`Effects.*` should stay boring: each module lowers a small capability group with `Framework.Business.capabilitiesEffect`.
