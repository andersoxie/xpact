# Runs the assertions-off Workbench lane in a session without the MSVC
# environment, with the given Eiffel C backend ("" = default, mingw).
param([string] $CCompiler = "")
$env:Path = (($env:Path -split ";") | Where-Object { $_ -notlike "*Microsoft Visual Studio*" }) -join ";"
Remove-Item Env:VSCMD_VER -ErrorAction SilentlyContinue
if ($CCompiler) { $env:ISE_C_COMPILER = $CCompiler } else { Remove-Item Env:ISE_C_COMPILER -ErrorAction SilentlyContinue }
# ec writes EIFGENs to the current directory; the script expects the repo root.
Set-Location (Join-Path $PSScriptRoot "..\..")
Write-Host "ISE_C_COMPILER=[$env:ISE_C_COMPILER] cl.exe on PATH: $([bool](Get-Command cl.exe -ErrorAction SilentlyContinue))"
& (Join-Path $PSScriptRoot "..\..\scripts\run_eiffel_test_matrix.ps1") -AssertionMode Off -BuildMode Workbench
exit $LASTEXITCODE
