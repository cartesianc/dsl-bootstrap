$ErrorActionPreference = "Stop"

function Invoke-CheckCommand {
  param(
    [string[]] $Command,
    [switch] $Quiet,
    [switch] $List
  )

  $commandText = $Command -join " "

  if ($List) {
    Write-Output $commandText
    return
  }

  Write-Host ("[check] " + $commandText)

  $executable = $Command[0]
  $arguments = @()
  if ($Command.Count -gt 1) {
    $arguments = $Command[1..($Command.Count - 1)]
  }

  if ($Quiet) {
    $stdoutPath = Join-Path $env:TEMP ("check-out-" + [Guid]::NewGuid().ToString("N") + ".log")
    $stderrPath = Join-Path $env:TEMP ("check-err-" + [Guid]::NewGuid().ToString("N") + ".log")
    try {
      & $executable @arguments 1> $stdoutPath 2> $stderrPath
      $exitCode = $LASTEXITCODE
      if ($null -eq $exitCode) {
        $exitCode = 0
      }

      if ($exitCode -ne 0) {
        Write-Host "[check] stdout"
        Get-Content -LiteralPath $stdoutPath -ErrorAction SilentlyContinue
        Write-Host "[check] stderr"
        Get-Content -LiteralPath $stderrPath -ErrorAction SilentlyContinue
        throw ("command failed (" + $exitCode + "): " + $commandText)
      }

      Write-Host "[check] ok"
      return
    }
    finally {
      Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
  }

  & $executable @arguments
  $exitCode = $LASTEXITCODE
  if ($null -eq $exitCode) {
    $exitCode = 0
  }

  if ($exitCode -ne 0) {
    throw ("command failed (" + $exitCode + "): " + $commandText)
  }
}

function Invoke-CheckCommands {
  param(
    [object[]] $Commands,
    [switch] $Quiet,
    [switch] $List
  )

  foreach ($command in $Commands) {
    Invoke-CheckCommand -Command ([string[]] $command) -Quiet:$Quiet -List:$List
  }
}

function Get-GitHeadName {
  $head = (& git rev-parse --short HEAD).Trim()
  if ($LASTEXITCODE -ne 0 -or $head -eq "") {
    throw "could not resolve current git HEAD"
  }
  $head
}

function Invoke-SelfArtifactGateOnce {
  param(
    [string] $WorkDir,
    [switch] $IncludeSelfArtifact,
    [switch] $ResetSelfArtifactMarker,
    [switch] $List
  )

  $command = @("stack", "--work-dir", $WorkDir, "exec", "self-artifact-witness")

  if (-not $IncludeSelfArtifact) {
    if ($List) {
      return
    } else {
      Write-Host "[check] self-artifact-witness skipped; pass -IncludeSelfArtifact to run the high-risk artifact gate once"
    }
    return
  }

  if ($List) {
    Write-Output "# self-artifact-witness high-risk gate; same HEAD may run only once unless marker is reset"
    Write-Output ($command -join " ")
    return
  }

  $head = Get-GitHeadName
  $markerDirectory = Join-Path ".generated" "check-markers"
  $markerPath = Join-Path $markerDirectory ("self-artifact-witness-" + $head + ".ran")

  if ($ResetSelfArtifactMarker -and (Test-Path -LiteralPath $markerPath)) {
    Remove-Item -LiteralPath $markerPath -Force
  }

  if (Test-Path -LiteralPath $markerPath) {
    throw ("self-artifact-witness already ran for HEAD " + $head + "; start a new round or pass -ResetSelfArtifactMarker intentionally")
  }

  Invoke-CheckCommand -Command $command
  New-Item -ItemType Directory -Force -Path $markerDirectory | Out-Null
  Set-Content -LiteralPath $markerPath -Value ((Get-Date).ToString("o")) -Encoding UTF8
}
