[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Scripts dot-source this file into the caller's session on every run. Each
# vcvars64.bat import prepends another copy of the Visual Studio directories to
# PATH, so after a few runs in one window cmd.exe exceeds its 8191-character
# line limit and fails with "The input line is too long." Skip the import when
# an x64 MSVC environment is already loaded.
if ($env:VSCMD_VER -and $env:VSCMD_ARG_TGT_ARCH -eq "x64" -and (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
	Write-Host "Visual Studio C++ x64 environment already loaded ($env:VSCMD_VER)"
	return
}

$VsWhere ="${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path -LiteralPath $VsWhere -PathType Leaf)) {
	throw "vswhere.exe not found. Install Visual Studio 2022 Build Tools with the C++ x64 toolchain."
}

$VsRoot = (& $VsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($VsRoot)) {
	throw "Visual Studio C++ tools not found. Install the Microsoft.VisualStudio.Component.VC.Tools.x86.x64 component."
}

$VcVars = Join-Path $VsRoot "VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path -LiteralPath $VcVars -PathType Leaf)) {
	throw "vcvars64.bat not found: $VcVars"
}

# vcvars64.bat calls vswhere.exe by name. Without its folder on PATH it prints
# "'vswhere.exe' is not recognized" to stderr, which stops this script in
# Windows PowerShell 5.1 when the output is captured.
$VsInstaller = Split-Path -Parent $VsWhere
$EnvironmentLines = & cmd.exe /s /c "set `"PATH=%PATH%;$VsInstaller`" && `"$VcVars`" >nul && set"
if ($LASTEXITCODE -ne 0) {
	throw "Failed to import Visual Studio C++ environment from $VcVars"
}

foreach ($Line in $EnvironmentLines) {
	if ($Line -notmatch "^([^=]+)=(.*)$") {
		continue
	}
	$Name = $Matches[1]
	if ($Name.StartsWith("=")) {
		continue
	}
	$Value = $Matches[2]
	if ($Name -ieq "Path") {
		# Drop duplicate PATH entries, keeping the first occurrence, so PATH stays
		# bounded even if the environment is imported on top of another one.
		$Seen = @{}
		$Value = (@($Value -split ";" | Where-Object {
			$Key = $_.TrimEnd("\").ToLowerInvariant()
			if ([string]::IsNullOrWhiteSpace($Key) -or $Seen.ContainsKey($Key)) {
				$false
			} else {
				$Seen[$Key] = $true
				$true
			}
		}) -join ";")
	}
	Set-Item -Path "Env:$Name" -Value $Value
}

Write-Host "Loaded Visual Studio C++ x64 environment from $VcVars"
