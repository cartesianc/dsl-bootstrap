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
  ,@("stack", "--work-dir", $WorkDir, "exec", "trust-base-manifest-witness", "--", "--json")
)

Push-Location $WorkspaceRoot
try {
  Invoke-CheckCommands -Commands $commands -Quiet -List:$List
}
finally {
  Pop-Location
}
