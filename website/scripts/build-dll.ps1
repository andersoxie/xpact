# Build xpact.dll and xpact_assertions.dll with the repository's own script and
# copy them to website/backend/native, where the API picks them up.
#
#   .\website\scripts\build-dll.ps1            # build both, then copy
#   .\website\scripts\build-dll.ps1 -SkipBuild # only copy DLLs that are already built
[CmdletBinding()]
param([switch] $SkipBuild)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Website = Split-Path -Parent $PSScriptRoot
$Repo = Split-Path -Parent $Website
$Built = Join-Path $Repo "build\native-eiffel"
$Target = Join-Path $Website "backend\native"

if (-not $SkipBuild) {
	foreach ($Tier in "Production", "Assertions") {
		& (Join-Path $Repo "scripts\build_native_eiffel.ps1") -BuildTier $Tier
		if (-not $?) { throw "build_native_eiffel.ps1 -BuildTier $Tier failed" }
	}
}

New-Item -ItemType Directory -Force -Path $Target | Out-Null
foreach ($Name in "xpact.dll", "xpact_assertions.dll") {
	$Source = Join-Path $Built $Name
	if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
		throw "$Name not found in $Built. Run without -SkipBuild first."
	}
	Copy-Item -LiteralPath $Source -Destination $Target -Force
	$Hash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash.Substring(0, 16)
	Write-Host "Copied $Name ($Hash...) to $Target"
}
