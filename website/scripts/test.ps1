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

# The frontend build does not depend on the backend: run it in a background job at the same time.
$FrontendDir = Join-Path $Website "frontend"
$FrontendJob = Start-Job -ScriptBlock {
	param($Dir)
	Set-Location $Dir
	if (-not (Test-Path node_modules)) { npm ci 2>&1 }
	npm run build 2>&1
	"FRONTEND EXIT $LASTEXITCODE"
} -ArgumentList $FrontendDir

Write-Host "== Backend tests (frontend build runs in parallel)"
# Coverage instruments only Xpact.Api (coverage.runsettings, #370).
$CoverageArgs = @()
if ($Coverage) {
	$CoverageArgs = @("--collect:XPlat Code Coverage", "--settings", (Join-Path $Website "backend\coverage.runsettings"),
		"--results-directory", (Join-Path $Website "backend\TestResults"))
}
dotnet test (Join-Path $Website "backend\Xpact.Web.slnx") -c Release --nologo @CoverageArgs
if ($LASTEXITCODE) { $Failed += "backend tests" }

Write-Host "== Frontend type check and build"
$FrontendOutput = @(Receive-Job -Job $FrontendJob -Wait -AutoRemoveJob | ForEach-Object { "$_" })
$FrontendOutput | Where-Object { $_ -notmatch '^FRONTEND EXIT ' } | Write-Host
if (($FrontendOutput | Select-Object -Last 1) -ne "FRONTEND EXIT 0") { $Failed += "frontend build" }

if ($Failed.Count) { Write-Host "FAILED: $($Failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host "All website checks passed." -ForegroundColor Green
