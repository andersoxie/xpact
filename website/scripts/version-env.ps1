# Sets VITE_XPACT_VERSION (from the repo's VERSION file) and VITE_XPACT_COMMIT (short git hash) for the
# frontend build, so the site shows which version it is (title, <meta name="xpact-version">, footer).
# Dot-sourced by publish.ps1 and dev.ps1.
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$env:VITE_XPACT_VERSION = (Get-Content (Join-Path $RepoRoot "VERSION") -TotalCount 1).Trim()
$env:VITE_XPACT_COMMIT = "unknown"
try {
	$Commit = & git -C $RepoRoot rev-parse --short HEAD 2>$null
	if ($LASTEXITCODE -eq 0 -and $Commit) { $env:VITE_XPACT_COMMIT = "$Commit".Trim() }
} catch { }
Write-Host "Site version: $env:VITE_XPACT_VERSION ($env:VITE_XPACT_COMMIT)"
