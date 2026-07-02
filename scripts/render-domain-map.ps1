param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$DomainMapArgs
)

$ErrorActionPreference = "Stop"

if ($DomainMapArgs.Count -eq 0) {
  stack exec domain-map --
} else {
  stack exec domain-map -- @DomainMapArgs
}

exit $LASTEXITCODE
