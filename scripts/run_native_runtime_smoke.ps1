[CmdletBinding()]
param(
	[string] $OutputDir = "build\native-runtime"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $RepoRoot $OutputDir
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

function Get-VcVars {
	$VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
	if (-not (Test-Path -LiteralPath $VsWhere -PathType Leaf)) {
		throw "vswhere.exe not found."
	}
	$VsRoot = (& $VsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Out-String).Trim()
	if ([string]::IsNullOrWhiteSpace($VsRoot)) {
		throw "Visual Studio C++ tools not found."
	}
	$VcVars = Join-Path $VsRoot "VC\Auxiliary\Build\vcvars64.bat"
	if (-not (Test-Path -LiteralPath $VcVars -PathType Leaf)) {
		throw "vcvars64.bat not found: $VcVars"
	}
	$VcVars
}

function Get-IseInclude {
	if (-not [string]::IsNullOrWhiteSpace($env:ISE_EIFFEL)) {
		$Candidate = Join-Path $env:ISE_EIFFEL "studio\spec\win64\include"
		if (Test-Path -LiteralPath $Candidate -PathType Container) {
			return $Candidate
		}
	}
	$Fallback = "C:\El2502E\studio\spec\win64\include"
	if (Test-Path -LiteralPath $Fallback -PathType Container) {
		return $Fallback
	}
	throw "Cannot find Eiffel runtime include directory."
}

function Compile-CObject {
	param(
		[string] $Source,
		[string] $Object
	)
	$VcVars = Get-VcVars
	$IseInclude = Get-IseInclude
	$Include = Join-Path $RepoRoot "include"
	$Native = Join-Path $RepoRoot "native"
	$Command = "`"$VcVars`" >nul && cl /nologo /c /I`"$Include`" /I`"$Native`" /I`"$IseInclude`" `"$Source`" /Fo:`"$Object`""
	cmd.exe /c $Command
	if ($LASTEXITCODE -ne 0) {
		throw "C object build failed: $Source"
	}
}

Compile-CObject (Join-Path $RepoRoot "native\xpact_native.c") (Join-Path $OutputRoot "xpact_native.obj")
Compile-CObject (Join-Path $RepoRoot "native\xpact_eiffel_runtime_bridge.c") (Join-Path $OutputRoot "xpact_eiffel_runtime_bridge.obj")

ec -batch -clean -config tests\xpact_native_runtime.ecf -target xpact_native_runtime
if ($LASTEXITCODE -ne 0) {
	throw "Eiffel native runtime target compilation failed."
}

$WorkCode = Join-Path $RepoRoot "EIFGENs\xpact_native_runtime\W_code"
if (Test-Path -LiteralPath (Join-Path $WorkCode "Makefile.SH") -PathType Leaf) {
	Push-Location $WorkCode
	try {
		finish_freezing
	} finally {
		Pop-Location
	}
	if ($LASTEXITCODE -ne 0) {
		throw "finish_freezing failed for native runtime target."
	}
}

$Exe = Join-Path $WorkCode "xpact_native_runtime.exe"
& $Exe
if ($LASTEXITCODE -ne 0) {
	throw "Native runtime smoke failed."
}
