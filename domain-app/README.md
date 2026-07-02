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
  fact dependencies, send boundaries, and type flow only

Domain.Vocabulary / Domain.EffectVocabulary
  stable names only

Domain.Runtime
  handler and transform implementation

Domain.SemanticEvidence
  evidence probes and generated-source checks
```

Do not put algorithms in `Domain.AppBlueprint` or `Plugins.*`. If a step needs computation, IO, retry behavior, or typed value conversion, express the fact/send/transform in `Effects.*` and implement the work in `Domain.Runtime` handlers or transforms.
