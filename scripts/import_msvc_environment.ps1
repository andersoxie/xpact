[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
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

$EnvironmentLines = & cmd.exe /s /c "`"$VcVars`" >nul && set"
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
	Set-Item -Path "Env:$Name" -Value $Matches[2]
}

Write-Host "Loaded Visual Studio C++ x64 environment from $VcVars"
