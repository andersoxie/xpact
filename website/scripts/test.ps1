# Run every website check: backend end-to-end tests (real worker and DLL) and the
# frontend type check and build. Exit code 0 only when everything passes.
#
#   .\website\scripts\test.ps1             # all checks
#   .\website\scripts\test.ps1 -Coverage   # also backend coverage (opencover + cobertura) into website\backend\TestResults
[CmdletBinding()]
param([switch]$Coverage)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Website = Split-Path -Parent $PSScriptRoot
$Failed = @()

Write-Host "== Backend tests"
# Coverage instruments only Xpact.Api (coverage.runsettings, #370).
$CoverageArgs = @()
if ($Coverage) {
	$CoverageArgs = @("--collect:XPlat Code Coverage", "--settings", (Join-Path $Website "backend\coverage.runsettings"),
		"--results-directory", (Join-Path $Website "backend\TestResults"))
}
dotnet test (Join-Path $Website "backend\Xpact.Web.slnx") -c Release --nologo @CoverageArgs
if ($LASTEXITCODE) { $Failed += "backend tests" }

Write-Host "== Frontend type check and build"
Push-Location (Join-Path $Website "frontend")
try {
	if (-not (Test-Path node_modules)) { npm ci }
	npm run build
	if ($LASTEXITCODE) { $Failed += "frontend build" }
} finally { Pop-Location }

if ($Failed.Count) { Write-Host "FAILED: $($Failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host "All website checks passed." -ForegroundColor Green
