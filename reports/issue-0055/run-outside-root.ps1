# Runs the assertions-off Workbench lane from a folder outside the repository
# and shows whether the test executable in the repository was rebuilt and
# whether EIFGENs ended up in the outside folder.
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Outside = Join-Path $env:TEMP "xpact-issue55-cwd"
$Exe = Join-Path $RepoRoot "EIFGENs\xpact_tests\W_code\xpact_tests.exe"
if (Test-Path -LiteralPath $Outside) { Remove-Item -Recurse -Force -LiteralPath $Outside }
New-Item -ItemType Directory -Path $Outside | Out-Null
Set-Location $Outside

function Show-Exe([string] $When) {
	if (Test-Path -LiteralPath $Exe) {
		Write-Host "$When repo xpact_tests.exe: $((Get-Item -LiteralPath $Exe).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
	} else {
		Write-Host "$When repo xpact_tests.exe: missing"
	}
}

Write-Host "Current folder: $Outside"
Show-Exe "Before:"
& (Join-Path $RepoRoot "scripts\run_eiffel_test_matrix.ps1") -AssertionMode Off -BuildMode Workbench
$Code = $LASTEXITCODE
Show-Exe "After: "
Write-Host "EIFGENs in the current folder: $(Test-Path -LiteralPath (Join-Path $Outside 'EIFGENs'))"
Set-Location $RepoRoot
Remove-Item -Recurse -Force -LiteralPath $Outside
exit $Code
