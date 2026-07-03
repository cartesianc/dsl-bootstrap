module Framework.Runtime.Diagnosis
  ( RuntimeFailureDiagnosis (..)
  , RuntimeDiagnosisEvidencePayload (..)
  , RuntimeDiagnosisEvidenceStatus (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisNodeKind (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeDiagnosisBlocker (..)
  , buildFailureDiagnosis
  , completeDiagnosisProbe
  , diagnosisProbePairs
  , renderRuntimeDiagnosisEvidencePayload
  , renderRuntimeDiagnosisEvidenceStatus
  , recordRuntimeDiagnosis
  , runtimeDiagnosisEvidencePayloadPassed
  , renderRuntimeFailureDiagnosis
  ) where

import Framework.Runtime
  ( RuntimeDiagnosisBlocker (..)
  , RuntimeDiagnosisNode (..)
  , RuntimeDiagnosisNodeKind (..)
  , RuntimeDiagnosisProbe (..)
  , RuntimeDiagnosisProbeStatus (..)
  , RuntimeFailureDiagnosis (..)
  , buildFailureDiagnosis
  , completeDiagnosisProbe
  , diagnosisProbePairs
  , recordRuntimeDiagnosis
  , renderRuntimeFailureDiagnosis
  )

data RuntimeDiagnosisEvidencePayload = RuntimeDiagnosisEvidencePayload
  { runtimeDiagnosisEvidenceClaim :: String
  , runtimeDiagnosisEvidenceStatus :: RuntimeDiagnosisEvidenceStatus
  , runtimeDiagnosisEvidenceExpected :: String
  , runtimeDiagnosisEvidenceObserved :: String
  , runtimeDiagnosisEvidenceArtifact :: String
  }
  deriving (Eq, Show)

data RuntimeDiagnosisEvidenceStatus
  = RuntimeDiagnosisEvidencePassed
  | RuntimeDiagnosisEvidenceFailed
  deriving (Eq, Show)

runtimeDiagnosisEvidencePayloadPassed :: RuntimeDiagnosisEvidencePayload -> Bool
runtimeDiagnosisEvidencePayloadPassed payload =
  runtimeDiagnosisEvidenceStatus payload == RuntimeDiagnosisEvidencePassed

renderRuntimeDiagnosisEvidencePayload :: RuntimeDiagnosisEvidencePayload -> [String]
renderRuntimeDiagnosisEvidencePayload payload =
  [ "claim: " ++ runtimeDiagnosisEvidenceClaim payload
  , "status: " ++ renderRuntimeDiagnosisEvidenceStatus (runtimeDiagnosisEvidenceStatus payload)
  , "expected: " ++ runtimeDiagnosisEvidenceExpected payload
  , "observed: " ++ runtimeDiagnosisEvidenceObserved payload
  , "artifact: " ++ runtimeDiagnosisEvidenceArtifact payload
  ]

renderRuntimeDiagnosisEvidenceStatus :: RuntimeDiagnosisEvidenceStatus -> String
renderRuntimeDiagnosisEvidenceStatus RuntimeDiagnosisEvidencePassed =
  "passed"
renderRuntimeDiagnosisEvidenceStatus RuntimeDiagnosisEvidenceFailed =
  "failed"
