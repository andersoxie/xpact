# Build everything into one folder that can be copied to a Windows server:
#   website/dist/   Xpact.Api.exe, Xpact.Worker.exe, native/*.dll, data/*.json, wwwroot/ (the React site)
#
#   .\website\scripts\publish.ps1
#   .\website\dist\Xpact.Api.exe --urls http://0.0.0.0:5099
# (8080 is often taken: on the student PC Apache httpd listens there.)
[CmdletBinding()]
param([string] $Output = "")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Website = Split-Path -Parent $PSScriptRoot
if (-not $Output) { $Output = Join-Path $Website "dist" }
$Frontend = Join-Path $Website "frontend"
$Api = Join-Path $Website "backend\src\Xpact.Api\Xpact.Api.csproj"

foreach ($Dll in "xpact.dll", "xpact_assertions.dll") {
	if (-not (Test-Path (Join-Path $Website "backend\native\$Dll"))) {
		throw "backend\native\$Dll is missing. Run .\website\scripts\build-dll.ps1 first."
	}
}

Write-Host "== Frontend"
Push-Location $Frontend
try {
	if (-not (Test-Path node_modules)) { npm ci; if ($LASTEXITCODE) { throw "npm ci failed" } }
	npm run build; if ($LASTEXITCODE) { throw "npm run build failed" }
} finally { Pop-Location }

Write-Host "== API and worker"
# Only ever delete an earlier publish: a folder that is empty or holds Xpact.Api.exe. A mistyped
# -Output (for example a home or project folder) stops here instead of being wiped.
if (Test-Path $Output) {
	$Old = @(Get-ChildItem -LiteralPath $Output -Force)
	if ($Old.Count -and -not (Test-Path (Join-Path $Output "Xpact.Api.exe"))) {
		throw "$Output is not empty and is not an earlier publish (no Xpact.Api.exe): not deleting it. Pick an empty or new folder."
	}
	Remove-Item -Recurse -Force $Output
}
dotnet publish $Api -c Release -o $Output --nologo
if ($LASTEXITCODE) { throw "dotnet publish failed" }

Write-Host "== Site into wwwroot"
$WwwRoot = Join-Path $Output "wwwroot"
New-Item -ItemType Directory -Force -Path $WwwRoot | Out-Null
Copy-Item -Recurse -Force (Join-Path $Frontend "dist\*") $WwwRoot

Write-Host "Published to $Output"
Write-Host "Start:  & '$Output\Xpact.Api.exe' --urls http://localhost:5099"
