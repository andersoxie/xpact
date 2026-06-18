[CmdletBinding()]
param(
	[string] $OutputDir = "build\incremental-shim-audit",
	[switch] $SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $RepoRoot $OutputDir
$Source = Join-Path $RepoRoot "tests\native\xpact_incremental_shim_audit.c"
$TsvPath = Join-Path $OutputRoot "incremental-shim-audit.tsv"
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

function Invoke-VcCommand {
	param([string] $Command)
	$VcVars = Get-VcVars
	$Output = cmd.exe /c "`"$VcVars`" >nul && $Command" 2>&1
	if ($LASTEXITCODE -ne 0) {
		throw "Visual C++ command failed: $Command`n$($Output | Out-String)"
	}
	foreach ($Line in $Output) {
		Write-Host $Line
	}
}

function Invoke-NativeBuild {
	$Stdout = Join-Path $OutputRoot "native-build.stdout.log"
	$Stderr = Join-Path $OutputRoot "native-build.stderr.log"
	$BuildScript = Join-Path $PSScriptRoot "build_native_eiffel.ps1"
	$Command = "`"powershell.exe`" -NoProfile -ExecutionPolicy Bypass -File `"$BuildScript`" -SkipSmoke > `"$Stdout`" 2> `"$Stderr`""
	Push-Location $RepoRoot
	try {
		cmd.exe /d /c $Command
		$ExitCode = $LASTEXITCODE
	} finally {
		Pop-Location
	}
	$Output = @()
	if (Test-Path -LiteralPath $Stdout -PathType Leaf) {
		$Output += Get-Content -LiteralPath $Stdout
	}
	if (Test-Path -LiteralPath $Stderr -PathType Leaf) {
		$Output += Get-Content -LiteralPath $Stderr
	}
	foreach ($Line in $Output) {
		Write-Host $Line
	}
	if ($ExitCode -ne 0) {
		throw "Eiffel-backed Windows DLL build failed with exit code $ExitCode. Logs: $Stdout, $Stderr"
	}
}

if (-not $SkipBuild) {
	Invoke-NativeBuild
}

$NativeRoot = Join-Path $RepoRoot "build\native-eiffel"
$ImportLib = Join-Path $NativeRoot "xpact.lib"
$Dll = Join-Path $NativeRoot "xpact.dll"
if (-not (Test-Path -LiteralPath $ImportLib -PathType Leaf)) {
	throw "xpact import library not found: $ImportLib"
}
if (-not (Test-Path -LiteralPath $Dll -PathType Leaf)) {
	throw "xpact DLL not found: $Dll"
}

$Exe = Join-Path $OutputRoot "xpact_incremental_shim_audit.exe"
$ObjectFile = Join-Path $OutputRoot "xpact_incremental_shim_audit.obj"
$Command = "cl /nologo /W4 /WX /O2 /MT /I`"$RepoRoot\include`" /Fo`"$ObjectFile`" `"$Source`" `"$ImportLib`" /Fe`"$Exe`" /link /NOLOGO"
Invoke-VcCommand $Command

$OldPath = $env:Path
try {
	$env:Path = "$NativeRoot;$OldPath"
	$Output = & $Exe
	$ExitCode = $LASTEXITCODE
	$Output | Set-Content -LiteralPath $TsvPath -Encoding UTF8
	foreach ($Line in $Output) {
		Write-Host $Line
	}
	if ($ExitCode -ne 0) {
		throw "Incremental shim audit failed with exit code $ExitCode. Rows written to $TsvPath"
	}
} finally {
	$env:Path = $OldPath
}

Write-Host "Incremental shim audit rows written to $TsvPath"
