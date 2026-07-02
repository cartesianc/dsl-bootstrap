param(
  [ValidateSet("all", "framework-core", "registry")]
  [string] $Target = "all"
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkspaceRoot = Split-Path -Parent $ScriptRoot

Push-Location $WorkspaceRoot
try {
  stack exec ast-tree -- $Target
}
finally {
  Pop-Location
}
