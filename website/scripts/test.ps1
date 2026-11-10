# Run every website check: backend end-to-end tests (real worker and DLL) and the
# frontend type check and build. Exit code 0 only when everything passes.
#
#   .\website\scripts\test.ps1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Website = Split-Path -Parent $PSScriptRoot
$Failed = @()

Write-Host "== Backend tests"
dotnet test (Join-Path $Website "backend\Xpact.Web.slnx") -c Release --nologo
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
