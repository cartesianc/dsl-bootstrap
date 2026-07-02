param(
  [string] $CommandLine = "",
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $Command = @(),
  [int] $StallSeconds = 90,
  [double] $ErrorContextSeconds = 1.0,
  [string] $LogPath = ".tmp-build-watch.log"
)

$ErrorActionPreference = "Stop"

if ($CommandLine -eq "" -and $Command.Count -eq 0) {
  Write-Error "usage: powershell -File scripts/build-watch.ps1 -CommandLine `"stack build --no-terminal`""
  exit 64
}

$root = Resolve-Path -LiteralPath "."
$logFullPath = Join-Path $root $LogPath
$stdoutPath = Join-Path $env:TEMP ("build-watch-out-" + [Guid]::NewGuid().ToString("N") + ".log")
$stderrPath = Join-Path $env:TEMP ("build-watch-err-" + [Guid]::NewGuid().ToString("N") + ".log")
$errorPatterns =
  @( "error:"
   , "Error:"
   , "Exception:"
   , "Failed to build"
   , "Build failed"
   , "Could not"
   , "cannot find"
   , "Not in scope"
   , "Ambiguous module name"
   )

Set-Content -LiteralPath $logFullPath -Value "" -Encoding UTF8
[System.IO.File]::WriteAllText($stdoutPath, "")
[System.IO.File]::WriteAllText($stderrPath, "")

function Write-WatchedLine {
  param([string] $Line)

  Write-Host $Line
  Add-Content -LiteralPath $logFullPath -Value $Line -Encoding UTF8
}

function Stop-ProcessTree {
  param([int] $RootProcessId)

  try {
    $children =
      Get-CimInstance Win32_Process |
      Where-Object { $_.ParentProcessId -eq $RootProcessId }

    foreach ($child in $children) {
      Stop-ProcessTree -RootProcessId $child.ProcessId
    }

    Stop-Process -Id $RootProcessId -Force -ErrorAction SilentlyContinue
  } catch {
  }

  if ($null -ne (Get-Process -Id $RootProcessId -ErrorAction SilentlyContinue)) {
    & taskkill /PID $RootProcessId /T /F 2>$null | Out-Null
  }
}

function Test-ErrorLine {
  param([string] $Line)

  foreach ($pattern in $errorPatterns) {
    if ($Line.Contains($pattern)) {
      return $true
    }
  }

  $false
}

function Handle-WatchedLine {
  param([string] $Line)

  Write-WatchedLine $Line
  Test-ErrorLine $Line
}

function Read-NewLines {
  param(
    [string] $Path,
    [ref] $Position
  )

  $lines = @()
  $stream = [System.IO.File]::Open($Path, "Open", "Read", "ReadWrite")
  try {
    [void] $stream.Seek($Position.Value, [System.IO.SeekOrigin]::Begin)
    $reader = New-Object System.IO.StreamReader($stream)
    while (-not $reader.EndOfStream) {
      $lines += $reader.ReadLine()
    }
    $Position.Value = $stream.Position
  } finally {
    $stream.Close()
  }

  $lines
}

$commandText =
  if ($CommandLine -ne "") {
    $CommandLine
  } else {
    $Command -join " "
  }

$redirectedCommand =
  $commandText +
  " 1> " +
  '"' + $stdoutPath + '"' +
  " 2> " +
  '"' + $stderrPath + '"'

Write-WatchedLine ("[watch] command: " + $commandText)
Write-WatchedLine ("[watch] log: " + $logFullPath)

$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = "cmd.exe"
$startInfo.Arguments = "/d /c " + $redirectedCommand
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $startInfo
[void] $process.Start()

$stdoutPosition = 0
$stderrPosition = 0
$lastOutput = Get-Date
$matchedError = $false
$errorDetectedAt = $null
$stall = $false

try {
  while (-not $process.HasExited) {
    foreach ($line in (Read-NewLines $stdoutPath ([ref] $stdoutPosition))) {
      $lastOutput = Get-Date
      if (Handle-WatchedLine $line) {
        if (-not $matchedError) {
          $matchedError = $true
          $errorDetectedAt = Get-Date
          Write-WatchedLine ("[watch] error detected; collecting " + $ErrorContextSeconds + "s context")
        }
      }
    }

    foreach ($line in (Read-NewLines $stderrPath ([ref] $stderrPosition))) {
      $lastOutput = Get-Date
      if (Handle-WatchedLine $line) {
        if (-not $matchedError) {
          $matchedError = $true
          $errorDetectedAt = Get-Date
          Write-WatchedLine ("[watch] error detected; collecting " + $ErrorContextSeconds + "s context")
        }
      }
    }

    if ($matchedError -and ((Get-Date) - $errorDetectedAt).TotalSeconds -ge $ErrorContextSeconds) {
      Write-WatchedLine ("[watch] error detected; stopping process tree " + $process.Id)
      Stop-ProcessTree -RootProcessId $process.Id
      break
    }

    $idleSeconds = ((Get-Date) - $lastOutput).TotalSeconds
    if ($StallSeconds -gt 0 -and $idleSeconds -ge $StallSeconds) {
      $stall = $true
      Write-WatchedLine ("[watch] no output for " + [int]$idleSeconds + "s; stopping process tree " + $process.Id)
      Stop-ProcessTree -RootProcessId $process.Id
      break
    }

    Start-Sleep -Milliseconds 250
    $process.Refresh()
  }

  foreach ($line in (Read-NewLines $stdoutPath ([ref] $stdoutPosition))) {
    if (Handle-WatchedLine $line) {
      $matchedError = $true
    }
  }

  foreach ($line in (Read-NewLines $stderrPath ([ref] $stderrPosition))) {
    if (Handle-WatchedLine $line) {
      $matchedError = $true
    }
  }
} finally {
  Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
}

if ($matchedError) {
  exit 2
}

if ($stall) {
  exit 3
}

$process.Refresh()
Write-WatchedLine ("[watch] exit code: " + $process.ExitCode)
exit $process.ExitCode
