module Bootstrap.Effects.CoreExpression.Facts.FrameworkCoreExpression
  ( astStructureExpressedFact
  , boundaryChecksExpressedFact
  , buildAppValidationExpressedFact
  , effectTheoryDslExpressedFact
  , frameworkCoreExpressedFact
  , frameworkCoreNativeValidatedFact
  , hyloRenderingProofSurfaceExpressedFact
  , runtimeFactClosureExpressedFact
  , runtimeInterpreterExpressedFact
  ) where

import Bootstrap.Vocabulary
import Bootstrap.Effect
  ( EffectSection
  , fact
  , needs
  )

astStructureExpressedFact :: EffectSection
astStructureExpressedFact =
  fact AstStructureExpressedFact
    [ needs FrameworkCoreModulesClassifiedFact
    , needs CoreSurfaceAstFormalizedFact
    ]

effectTheoryDslExpressedFact :: EffectSection
effectTheoryDslExpressedFact =
  fact EffectTheoryDslExpressedFact
    [ needs CoreSurfaceEffectTheoryFormalizedFact
    ]

runtimeInterpreterExpressedFact :: EffectSection
runtimeInterpreterExpressedFact =
  fact RuntimeInterpreterExpressedFact
    [ needs CoreSurfaceFormalizedFact
    , needs RuntimeEvidencePassedFact
    ]

buildAppValidationExpressedFact :: EffectSection
buildAppValidationExpressedFact =
  fact BuildAppValidationExpressedFact
    [ needs MinimalCoreReportBuiltFact
    ]

boundaryChecksExpressedFact :: EffectSection
boundaryChecksExpressedFact =
  fact BoundaryChecksExpressedFact
    [ needs CoreBoundaryValidatedFact
    , needs FrontendBoundaryValidatedFact
    ]

hyloRenderingProofSurfaceExpressedFact :: EffectSection
hyloRenderingProofSurfaceExpressedFact =
  fact HyloRenderingProofSurfaceExpressedFact
    [ needs CoreSurfaceFormalizedFact
    , needs ConstraintIRBuiltFact
    , needs SmtProofPassedFact
    ]

runtimeFactClosureExpressedFact :: EffectSection
runtimeFactClosureExpressedFact =
  fact RuntimeFactClosureExpressedFact
    [ needs RuntimeEvidencePassedFact
    , needs SmtProofPassedFact
    ]

frameworkCoreNativeValidatedFact :: EffectSection
frameworkCoreNativeValidatedFact =
  fact FrameworkCoreNativeValidatedFact
    [ needs AstStructureExpressedFact
    , needs EffectTheoryDslExpressedFact
    , needs RuntimeInterpreterExpressedFact
    , needs BuildAppValidationExpressedFact
    , needs BoundaryChecksExpressedFact
    , needs HyloRenderingProofSurfaceExpressedFact
    , needs RuntimeFactClosureExpressedFact
    ]

frameworkCoreExpressedFact :: EffectSection
frameworkCoreExpressedFact =
  fact FrameworkCoreExpressedFact
    [ needs FrameworkCoreNativeValidatedFact
    ]
