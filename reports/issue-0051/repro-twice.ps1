# Loads MSVC three times in one session, as repeated script runs do (#4):
# the later runs must take the "already loaded" path and PATH must not grow.
$ErrorActionPreference = "Stop"
$Script = Join-Path $PSScriptRoot "..\..\scripts\import_msvc_environment.ps1"
foreach ($Run in 1..3) {
	& { . $Script } *>&1 | ForEach-Object { "run ${Run}: $_" }
	"run ${Run}: PATH length $($env:Path.Length)"
}
