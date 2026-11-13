# Run the website for development: the API on http://localhost:5080 (new window)
# and the React dev server on http://localhost:5173 (this window, with hot reload).
#
#   .\website\scripts\dev.ps1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Website = Split-Path -Parent $PSScriptRoot
$Api = Join-Path $Website "backend\src\Xpact.Api"

if (-not (Test-Path (Join-Path $Website "backend\native\xpact.dll"))) {
	Write-Warning "backend\native\xpact.dll is missing: run .\website\scripts\build-dll.ps1 first."
}

Start-Process powershell -ArgumentList "-NoExit", "-Command", "dotnet run --project '$Api' --launch-profile Xpact.Api"

Push-Location (Join-Path $Website "frontend")
try {
	if (-not (Test-Path node_modules)) { npm install }
	npm run dev
} finally { Pop-Location }
