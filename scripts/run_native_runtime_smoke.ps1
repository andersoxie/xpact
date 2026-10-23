[CmdletBinding()]
param(
	[string] $OutputDir = "build\native-runtime",
	[ValidateSet("All", "Off", "On")]
	[string] $AssertionMode = "All"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $RepoRoot $OutputDir
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

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
	# Search order: ISE_EIFFEL, the known installs (C:\El2502E is EiffelStudio
	# 25.02 Enterprise on the Jenkins machine, 25.12 Standard is the student
	# PC), then the EiffelStudio whose ec.exe is on PATH
	# (<root>\studio\spec\win64\bin\ec.exe).
	$Roots = @()
	if (-not [string]::IsNullOrWhiteSpace($env:ISE_EIFFEL)) {
		$Roots += $env:ISE_EIFFEL
	}
	$Roots += "C:\El2502E"
	$Roots += "C:\Program Files\Eiffel Software\EiffelStudio 25.12 Standard"
	$Ec = Get-Command ec -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($Ec) {
		$Roots += Join-Path (Split-Path -Parent $Ec.Source) "..\..\..\.."
	}
	$Searched = @()
	foreach ($Root in $Roots) {
		$Candidate = Join-Path $Root "studio\spec\win64\include"
		if (Test-Path -LiteralPath $Candidate -PathType Container) {
			return (Resolve-Path -LiteralPath $Candidate).Path
		}
		$Searched += $Candidate
	}
	throw "Cannot find Eiffel runtime include directory. Searched: $($Searched -join '; ')"
}

# Runs a native command without letting harmless stderr output (such as the
# vcvars "'vswhere.exe' is not recognized" message) become a terminating error
# under $ErrorActionPreference = "Stop". Returns the command's exit code.
function Invoke-NativeCommand {
	param([scriptblock] $Block)
	$SavedErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		& $Block | Out-Host
		return $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $SavedErrorActionPreference
	}
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
	$CompileExitCode = Invoke-NativeCommand { cmd.exe /c $Command }
	if ($CompileExitCode -ne 0) {
		throw "C object build failed: $Source"
	}
}

Compile-CObject (Join-Path $RepoRoot "native\xpact_native.c") (Join-Path $OutputRoot "xpact_native.obj")
Compile-CObject (Join-Path $RepoRoot "native\xpact_eiffel_runtime_bridge.c") (Join-Path $OutputRoot "xpact_eiffel_runtime_bridge.obj")

function Selected-RuntimeTargets {
	if ($AssertionMode -eq "All" -or $AssertionMode -eq "On") {
		[pscustomobject]@{
			Label = "assertions-on"
			Target = "xpact_native_runtime"
		}
	}
	if ($AssertionMode -eq "All" -or $AssertionMode -eq "Off") {
		[pscustomobject]@{
			Label = "assertions-off"
			Target = "xpact_native_runtime_no_assertions"
		}
	}
}

# The external objects above are compiled with MSVC `cl`, so they reference
# MSVC CRT symbols (`__security_check_cookie`, `__GSHandlerCheck`) and carry
# `/DEFAULTLIB:LIBCMT` directives. The Eiffel C code must therefore be built and
# linked with the MSVC backend too; the machine's default mingw backend links
# with gcc/ld, which cannot resolve those symbols.
$OldCompiler = $env:ISE_C_COMPILER
# Keep an MSVC backend the machine already selects (for example "msc" on the
# Jenkins machine); switch only an unset or non-MSVC backend to "msc_vc140".
if ($OldCompiler -notlike "msc*") {
	$env:ISE_C_COMPILER = "msc_vc140"
}
try {
	foreach ($RuntimeTarget in Selected-RuntimeTargets) {
		Write-Host "== native runtime smoke: $($RuntimeTarget.Label) =="
		$EiffelExitCode = Invoke-NativeCommand { ec -batch -clean -config tests\xpact_native_runtime.ecf -target $RuntimeTarget.Target }
		if ($EiffelExitCode -ne 0) {
			throw "Eiffel native runtime target compilation failed for $($RuntimeTarget.Label)."
		}
		$WorkCode = Join-Path $RepoRoot "EIFGENs\$($RuntimeTarget.Target)\W_code"
		if (Test-Path -LiteralPath (Join-Path $WorkCode "Makefile.SH") -PathType Leaf) {
			Push-Location $WorkCode
			try {
				$FinishExitCode = Invoke-NativeCommand { finish_freezing }
			} finally {
				Pop-Location
			}
			if ($FinishExitCode -ne 0) {
				throw "finish_freezing failed for native runtime target $($RuntimeTarget.Label)."
			}
		}

		$Exe = Join-Path $WorkCode "xpact_native_runtime.exe"
		$SmokeExitCode = Invoke-NativeCommand { & $Exe }
		if ($SmokeExitCode -ne 0) {
			throw "Native runtime smoke failed for $($RuntimeTarget.Label)."
		}
	}
} finally {
	$env:ISE_C_COMPILER = $OldCompiler
}
