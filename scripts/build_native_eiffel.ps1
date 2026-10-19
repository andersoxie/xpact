[CmdletBinding()]
param(
	[string] $OutputDir = "build\native-eiffel",
	[ValidateSet("Production", "Assertions")]
	[string] $BuildTier = "Production",
	[switch] $SkipSmoke
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $RepoRoot $OutputDir
$EcfObjectRoot = Join-Path $RepoRoot "build\native-eiffel"
New-Item -ItemType Directory -Force -Path $OutputRoot, $EcfObjectRoot | Out-Null

. (Join-Path $PSScriptRoot "import_msvc_environment.ps1")

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
	$Fallback = "C:\Program Files\Eiffel Software\EiffelStudio 25.12 Standard\studio\spec\win64\include"
	if (Test-Path -LiteralPath $Fallback -PathType Container) {
		return $Fallback
	}
	throw "Cannot find Eiffel runtime include directory."
}

function Invoke-VcCommand {
	param([string] $Command)
	$VcVars = Get-VcVars
	# vcvars64.bat writes harmless messages such as "'vswhere.exe' is not
	# recognized" to stderr; under "Stop" the 2>&1 below would make them fatal.
	$SavedErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		$Output = cmd.exe /c "`"$VcVars`" >nul && $Command" 2>&1
		$ExitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $SavedErrorActionPreference
	}
	foreach ($Line in $Output) {
		Write-Host $Line
	}
	if ($ExitCode -ne 0) {
		throw "Visual C++ command failed with exit code ${ExitCode}: $Command"
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

function Get-LinkResponseFile {
	param(
		[string] $CodeDirectory,
		[string] $Target
	)
	$Expected = Join-Path $CodeDirectory "$Target.lnk"
	if (Test-Path -LiteralPath $Expected -PathType Leaf) {
		return $Expected
	}
	$Candidates = @(Get-ChildItem -LiteralPath $CodeDirectory -Filter "*.lnk" |
		Where-Object { $_.Name -ne "xpact_dll.lnk" -and $_.Name -notlike "*.dll.lnk" } |
		Sort-Object Name)
	if ($Candidates.Count -eq 1) {
		return $Candidates[0].FullName
	}
	throw "Expected Eiffel link response file not found: $Expected"
}

$EiffelTarget = if ($BuildTier -eq "Assertions") { "xpact_native_library_assertions" } else { "xpact_native_library" }
$DllName = if ($BuildTier -eq "Assertions") { "xpact_assertions.dll" } else { "xpact.dll" }
$LibName = if ($BuildTier -eq "Assertions") { "xpact_assertions.lib" } else { "xpact.lib" }
$SmokeName = if ($BuildTier -eq "Assertions") { "xpact_assertions_eiffel_dll_smoke.exe" } else { "xpact_eiffel_dll_smoke.exe" }

$NativeObj = Join-Path $EcfObjectRoot "xpact_native.obj"
$RuntimeObj = Join-Path $EcfObjectRoot "xpact_eiffel_runtime_bridge.obj"
$DllMainObj = Join-Path $OutputRoot "xpact_eiffel_dllmain.obj"

Compile-CObject (Join-Path $RepoRoot "native\xpact_native.c") $NativeObj -BuildingDll
Compile-CObject (Join-Path $RepoRoot "native\xpact_eiffel_runtime_bridge.c") $RuntimeObj -BuildingDll
Compile-CObject (Join-Path $RepoRoot "native\xpact_eiffel_dllmain.c") $DllMainObj

# The link step below consumes the MSVC response file (`<target>.lnk`) that the
# Eiffel finalizer emits only when the target is compiled with an MSVC backend.
# Select the backend that matches the installed Visual Studio C++ tools; the
# mingw backend emits no `.lnk` and its objects cannot be linked by `link.exe`.
# The plain "msc" backend does not link with Visual Studio 18 (unresolved
# __iob_func, _set_output_format), so use "msc_vc140".
$OldCompiler = $env:ISE_C_COMPILER
$env:ISE_C_COMPILER = "msc_vc140"
try {
	$SavedErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		ec -batch -clean -finalize -keep -config tests\xpact_native_library.ecf -target $EiffelTarget
		$EiffelExitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $SavedErrorActionPreference
	}
	if ($EiffelExitCode -ne 0) {
		throw "Eiffel native library target compilation failed for $BuildTier."
	}

	$FinalCode = Join-Path $RepoRoot "EIFGENs\$EiffelTarget\F_code"
	Push-Location $FinalCode
	try {
		$SavedErrorActionPreference = $ErrorActionPreference
		$ErrorActionPreference = "Continue"
		try {
			finish_freezing
			$FinishExitCode = $LASTEXITCODE
		} finally {
			$ErrorActionPreference = $SavedErrorActionPreference
		}
	} finally {
		Pop-Location
	}
	if ($FinishExitCode -ne 0) {
		throw "finish_freezing failed for native library target $EiffelTarget."
	}
} finally {
	$env:ISE_C_COMPILER = $OldCompiler
}

$OriginalLink = Get-LinkResponseFile $FinalCode $EiffelTarget

$Dll = Join-Path $OutputRoot $DllName
$Lib = Join-Path $OutputRoot $LibName
$DllLink = Join-Path $FinalCode "$EiffelTarget.dll.lnk"
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
Write-Host "Built $Dll ($BuildTier)"

if (-not $SkipSmoke) {
	$SmokeExe = Join-Path $OutputRoot $SmokeName
	$SmokeSource = Join-Path $RepoRoot "tests\native\xpact_eiffel_dll_smoke.c"
	$Include = Join-Path $RepoRoot "include"
	$SmokeCommand = "cl /nologo /I`"$Include`" `"$SmokeSource`" `"$Lib`" /Fe:`"$SmokeExe`""
	Invoke-VcCommand $SmokeCommand
	$OldPath = $env:Path
	try {
		$env:Path = "$OutputRoot;$OldPath"
		$SavedErrorActionPreference = $ErrorActionPreference
		$ErrorActionPreference = "Continue"
		try {
			$SmokeOutput = & $SmokeExe 2>&1
			$SmokeExitCode = $LASTEXITCODE
		} finally {
			$ErrorActionPreference = $SavedErrorActionPreference
		}
		foreach ($Line in $SmokeOutput) {
			Write-Host $Line
		}
		if ($SmokeExitCode -ne 0) {
			throw "Smoke executable failed with exit code ${SmokeExitCode}: $SmokeExe"
		}
	} finally {
		$env:Path = $OldPath
	}
}
