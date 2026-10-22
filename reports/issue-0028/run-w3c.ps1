# Builds both benchmark executables and runs the W3C suite with the Python
# runner, as in student/results/w3c-conformance-2026-10-21/README.md.
# -SkipBuild reuses the executables from an earlier run.
param([switch] $SkipBuild)
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..\..")
. .\scripts\import_msvc_environment.ps1
if (-not $SkipBuild) { foreach ($Build in @(@("xpact_benchmarks", @()), @("xpact_benchmarks_assertions", @("-keep")))) {
	$Target = $Build[0]
	Write-Host "== build $Target"
	& ec -batch -clean -finalize @($Build[1]) -config benchmarks\xpact_benchmarks.ecf -target $Target
	if ($LASTEXITCODE -ne 0) { throw "ec failed for $Target" }
	Push-Location "EIFGENs\$Target\F_code"
	& finish_freezing
	$Code = $LASTEXITCODE
	Pop-Location
	if ($Code -ne 0) { throw "finish_freezing failed for $Target" }
	Write-Host "SHA-256 $Target`: $((Get-FileHash "EIFGENs\$Target\F_code\xpact_benchmarks.exe" -Algorithm SHA256).Hash.ToLower())"
} }
$Python = Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\python.exe"
& $Python --version
& $Python scripts\run_w3c_conformance.py `
	--engine "Finalized=EIFGENs/xpact_benchmarks/F_code/xpact_benchmarks.exe" `
	--engine "FinalizedAssertions=EIFGENs/xpact_benchmarks_assertions/F_code/xpact_benchmarks.exe" `
	--timeout 10
exit $LASTEXITCODE
