[CmdletBinding()]
param(
	[string] $OutputDir = "build\native-eiffel",
	[switch] $SkipSmoke
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

function Invoke-VcCommand {
	param([string] $Command)
	$VcVars = Get-VcVars
	cmd.exe /c "`"$VcVars`" >nul && $Command"
	if ($LASTEXITCODE -ne 0) {
		throw "Visual C++ command failed: $Command"
	}
}

function Compile-CObject {
	param(
		[string] $Source,
		[string] $Object,
		[switch] $BuildingDll
	)
	$IseInclude = Get-IseInclude
	$Include = Join-Path $RepoRoot "include"
	$Native = Join-Path $RepoRoot "native"
	$Defines = if ($BuildingDll) { "/DXPACT_BUILDING_DLL" } else { "" }
	$Command = "cl /nologo /O2 /MT /c $Defines /I`"$Include`" /I`"$Native`" /I`"$IseInclude`" `"$Source`" /Fo:`"$Object`""
	Invoke-VcCommand $Command
}

$NativeObj = Join-Path $OutputRoot "xpact_native.obj"
$RuntimeObj = Join-Path $OutputRoot "xpact_eiffel_runtime_bridge.obj"
$DllMainObj = Join-Path $OutputRoot "xpact_eiffel_dllmain.obj"

Compile-CObject (Join-Path $RepoRoot "native\xpact_native.c") $NativeObj -BuildingDll
Compile-CObject (Join-Path $RepoRoot "native\xpact_eiffel_runtime_bridge.c") $RuntimeObj -BuildingDll
Compile-CObject (Join-Path $RepoRoot "native\xpact_eiffel_dllmain.c") $DllMainObj

ec -batch -clean -finalize -keep -config tests\xpact_native_library.ecf -target xpact_native_library
if ($LASTEXITCODE -ne 0) {
	throw "Eiffel native library target compilation failed."
}

$FinalCode = Join-Path $RepoRoot "EIFGENs\xpact_native_library\F_code"
Push-Location $FinalCode
try {
	finish_freezing
} finally {
	Pop-Location
}
if ($LASTEXITCODE -ne 0) {
	throw "finish_freezing failed for native library target."
}

$OriginalLink = Join-Path $FinalCode "xpact_native_library.lnk"
if (-not (Test-Path -LiteralPath $OriginalLink -PathType Leaf)) {
	throw "Expected Eiffel link response file not found: $OriginalLink"
}

$Dll = Join-Path $OutputRoot "xpact.dll"
$Lib = Join-Path $OutputRoot "xpact.lib"
$DllLink = Join-Path $FinalCode "xpact_dll.lnk"
$Response = New-Object System.Collections.Generic.List[string]
$Response.Add("-DLL -NOLOGO -NODEFAULTLIB:libc -OUT:`"$Dll`" -IMPLIB:`"$Lib`"")
$Response.Add("`"$DllMainObj`"")
foreach ($Line in Get-Content -Path $OriginalLink) {
	$Trimmed = $Line.Trim()
	if ([string]::IsNullOrWhiteSpace($Trimmed)) {
		continue
	}
	if ($Trimmed -like "*-OUT:*" -or $Trimmed -ieq "e1\emain.obj" -or $Trimmed -like "*.res") {
		continue
	}
	$Response.Add($Line)
}
Set-Content -Path $DllLink -Value $Response

$LinkCommand = "cd /d `"$FinalCode`" && link @`"$DllLink`""
Invoke-VcCommand $LinkCommand
Write-Host "Built $Dll"

if (-not $SkipSmoke) {
	$SmokeExe = Join-Path $OutputRoot "xpact_eiffel_dll_smoke.exe"
	$SmokeSource = Join-Path $RepoRoot "tests\native\xpact_eiffel_dll_smoke.c"
	$Include = Join-Path $RepoRoot "include"
	$SmokeCommand = "cl /nologo /I`"$Include`" `"$SmokeSource`" `"$Lib`" /Fe:`"$SmokeExe`" && `"$SmokeExe`""
	Invoke-VcCommand $SmokeCommand
}
