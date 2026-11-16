# Full acceptance run for a parser change: Eiffel test matrix, W3C runner (all cases, both builds), Python suite.
# The tested DLLs in build\native-eiffel are backed up first and restored at the end (run_benchmarks rebuilds them).
#   powershell -File reports\perf-allocations\acceptance.ps1 [-Python <python.exe>]
param([string] $Python = "python")
$ErrorActionPreference = "Continue"
$Repo = (Resolve-Path "$PSScriptRoot\..\..").Path
# run_benchmarks.ps1 calls "python": put the given Python first on PATH (the Store alias stops it, #308).
if ($Python -ne "python") { $env:PATH = (Split-Path $Python) + ";" + $env:PATH }
Set-Location $Repo
$Log = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force $Log | Out-Null
$Backup = Join-Path $Repo "build\native-eiffel-backup"
New-Item -ItemType Directory -Force $Backup | Out-Null
foreach ($Dll in "xpact.dll", "xpact_assertions.dll", "xpact.lib", "xpact_assertions.lib") {
	$Path = Join-Path $Repo "build\native-eiffel\$Dll"
	if (Test-Path $Path) { Copy-Item $Path $Backup -Force }
}
"backup: " + ((Get-ChildItem $Backup | ForEach-Object { "$($_.Name) $((Get-FileHash $_.FullName).Hash.Substring(0,16))" }) -join ", ")
try {
	"== 1/3 Eiffel test matrix $(Get-Date -Format HH:mm)"
	& powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_eiffel_test_matrix.ps1 > (Join-Path $Log "matrix.txt") 2>&1
	"MATRIX EXIT $LASTEXITCODE"
	"== 2/3 W3C runner, all cases, both builds $(Get-Date -Format HH:mm)"
	# -Command, not -File: with -File the build list would arrive as one string ("Finalized,FinalizedAssertions").
	& powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\scripts\run_benchmarks.ps1' -EiffelBuild Finalized,FinalizedAssertions -W3cAllCases -SkipWslC -NoDocsUpdate -Repetitions 2" > (Join-Path $Log "w3c.txt") 2>&1
	"W3C EXIT $LASTEXITCODE"
	"== 3/3 Python suite $(Get-Date -Format HH:mm)"
	& $Python -m unittest discover -s tests/python -p "test_*.py" > (Join-Path $Log "python.txt") 2>&1
	"PYTHON EXIT $LASTEXITCODE"
} finally {
	foreach ($File in Get-ChildItem $Backup) { Copy-Item $File.FullName (Join-Path $Repo "build\native-eiffel\$($File.Name)") -Force }
	"restored: " + ((Get-ChildItem (Join-Path $Repo "build\native-eiffel") -Filter "xpact*.dll" | ForEach-Object { "$($_.Name) $((Get-FileHash $_.FullName).Hash.Substring(0,16))" }) -join ", ")
	"done $(Get-Date -Format HH:mm)"
}
