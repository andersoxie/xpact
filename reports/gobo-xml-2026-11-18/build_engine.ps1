# Builds the Gobo XML test engine (gx_engine.exe) with gec + MSVC into build\gobo-xml-cmp\engine.
# Usage: powershell -File reports\gobo-xml-2026-11-18\build_engine.ps1
param([string] $Out = "")
$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
$Repo = (Resolve-Path "$Here\..\..").Path
. "$Repo\reports\gobo-2026-11-16\gobo-env.ps1" -CC msc | Out-Host
$env:GOBO_EIFFEL = "ge"
if (-not $Out) { $Out = Join-Path $Repo "build\gobo-xml-cmp\engine" }
New-Item -ItemType Directory -Force $Out | Out-Null
Push-Location $Out
try {
	& gec --finalize --gc=boehm --no-benchmark "$Here\engine\gx_engine.ecf"
	if ($LASTEXITCODE -ne 0) { throw "gec failed ($LASTEXITCODE)" }
} finally { Pop-Location }
$exe = Join-Path $Out "gx_engine.exe"
"Built $exe  SHA-256 $((Get-FileHash $exe).Hash)"
