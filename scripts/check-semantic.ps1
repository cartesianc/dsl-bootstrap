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
  ,@("stack", "--work-dir", $WorkDir, "exec", "core-self-interpret", "--", "--json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "trust-base-manifest-witness", "--", "--evidence-json")
  ,@("stack", "--work-dir", $WorkDir, "exec", "architecture-concern-witness", "--", "--json")
)

Push-Location $WorkspaceRoot
try {
  Invoke-CheckCommands -Commands $commands -Quiet -List:$List
}
finally {
  Pop-Location
}
