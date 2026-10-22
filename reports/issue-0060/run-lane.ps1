# Runs one lane of the test matrix from the repository root, with MSVC
# loaded first (vcvars64.bat, via import_msvc_environment.ps1).
param([string] $AssertionMode, [string] $BuildMode)
Set-Location (Join-Path $PSScriptRoot "..\..")
. .\scripts\import_msvc_environment.ps1
& .\scripts\run_eiffel_test_matrix.ps1 -AssertionMode $AssertionMode -BuildMode $BuildMode
exit $LASTEXITCODE
