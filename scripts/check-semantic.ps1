param(
  [string] $WorkDir = ".stack-work-codex",
  [switch] $List
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkspaceRoot = Split-Path -Parent $ScriptRoot
. (Join-Path $ScriptRoot "check-lib.ps1")

$commands = @(
  ,@("stack", "--work-dir", $WorkDir, "build")
  ,@("stack", "--work-dir", $WorkDir, "exec", "bootstrap-report", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "runtime-evidence-witness", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "bootstrap-runtime-smoke")
  ,@("stack", "--work-dir", $WorkDir, "exec", "runtime-diagnosis-witness", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "workflow-semantics-witness", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "workflow-semantics-witness", "--", "--runtime-concurrency-json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "framework-core-frontend-witness")
  ,@("stack", "--work-dir", $WorkDir, "exec", "fixed-point-smoke", "--", "--json")
)

Push-Location $WorkspaceRoot
try {
  Invoke-CheckCommands -Commands $commands -Quiet -List:$List
}
finally {
  Pop-Location
}
