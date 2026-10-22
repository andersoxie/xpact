# Runs one lane from the repository root: a test-matrix lane
# (-AssertionMode On|Off -BuildMode Workbench|Finalized) or, with -Native,
# the native runtime smoke test (-AssertionMode On|Off).
param([string] $AssertionMode, [string] $BuildMode = "", [switch] $Native)
Set-Location (Join-Path $PSScriptRoot "..\..\..")
. .\scripts\import_msvc_environment.ps1
if ($Native) {
	& .\scripts\run_native_runtime_smoke.ps1 -AssertionMode $AssertionMode
} else {
	& .\scripts\run_eiffel_test_matrix.ps1 -AssertionMode $AssertionMode -BuildMode $BuildMode
}
exit $LASTEXITCODE
