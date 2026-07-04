param(
  [string] $WorkDir = ".stack-work-codex",
  [switch] $IncludeSelfArtifact,
  [switch] $ResetSelfArtifactMarker,
  [switch] $List
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkspaceRoot = Split-Path -Parent $ScriptRoot
. (Join-Path $ScriptRoot "check-lib.ps1")

$commands = @(
  ,@("stack", "--work-dir", $WorkDir, "build")
  ,@("stack", "--work-dir", $WorkDir, "exec", "mytest")
  ,@("stack", "--work-dir", $WorkDir, "exec", "domain-app-report", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "domain-app-self-smoke")
  ,@("stack", "--work-dir", $WorkDir, "exec", "business-syntax-witness", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "framework-core-mytest")
  ,@("stack", "--work-dir", $WorkDir, "exec", "bootstrap-smoke")
  ,@("stack", "--work-dir", $WorkDir, "exec", "bootstrap-runtime-smoke")
  ,@("stack", "--work-dir", $WorkDir, "exec", "bootstrap-report", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "fixed-point-smoke", "--", "--summary-json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "runtime-evidence-witness", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "runtime-hot-path-witness", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "runtime-policy-witness", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "runtime-diagnosis-witness", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "workflow-semantics-witness", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "workflow-semantics-witness", "--", "--runtime-concurrency-json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "constraint-proof-witness", "--", "--smt=auto")
  ,@("stack", "--work-dir", $WorkDir, "exec", "framework-core-frontend-witness", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "trust-base-manifest-witness", "--", "--evidence-json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "schema-catalog-witness", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "registry-codegen-witness")
)

Push-Location $WorkspaceRoot
try {
  Invoke-CheckCommands -Commands $commands -Quiet -List:$List
  Invoke-SelfArtifactGateOnce `
    -WorkDir $WorkDir `
    -IncludeSelfArtifact:$IncludeSelfArtifact `
    -ResetSelfArtifactMarker:$ResetSelfArtifactMarker `
    -List:$List
}
finally {
  Pop-Location
}
