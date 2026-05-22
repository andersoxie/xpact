[CmdletBinding()]
param(
	[ValidateSet("Windows", "Wsl", "All")]
	[string] $Target = "All",
	[string] $OutputDir = "build\native-tests"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $RepoRoot $OutputDir
$NativeRoot = Join-Path $RepoRoot "build\native"
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

function ConvertTo-WslPath {
	param(
		[string] $WindowsPath,
		[string] $WslExecutable
	)
	$Normalized = $WindowsPath -replace "\\", "/"
	(& $WslExecutable -- wslpath -a $Normalized | Out-String).Trim()
}

function Build-WindowsTests {
	& (Join-Path $PSScriptRoot "build_native.ps1") -Target Windows
	if ($LASTEXITCODE -ne 0) {
		throw "Windows native build failed."
	}

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

	$PublicSource = Join-Path $RepoRoot "tests\native\xpact_abi_smoke.c"
	$BridgeSource = Join-Path $RepoRoot "tests\native\xpact_bridge_smoke.c"
	$ImportLib = Join-Path $NativeRoot "xpact.lib"
	$PublicExe = Join-Path $OutputRoot "xpact_abi_smoke.exe"
	$BridgeExe = Join-Path $OutputRoot "xpact_bridge_smoke.exe"

	$Command = "`"$VcVars`" >nul && " +
		"cl /nologo /W4 /WX /I`"$RepoRoot\include`" /I`"$RepoRoot`" `"$PublicSource`" `"$ImportLib`" /Fe`"$PublicExe`" /link /NOLOGO && " +
		"cl /nologo /W4 /WX /I`"$RepoRoot\include`" /I`"$RepoRoot`" `"$BridgeSource`" `"$ImportLib`" /Fe`"$BridgeExe`" /link /NOLOGO"
	cmd.exe /c $Command
	if ($LASTEXITCODE -ne 0) {
		throw "Windows native ABI test build failed."
	}

	$OldPath = $env:Path
	try {
		$env:Path = "$NativeRoot;$OldPath"
		& $PublicExe
		if ($LASTEXITCODE -ne 0) {
			throw "Windows public ABI smoke failed."
		}
		& $BridgeExe
		if ($LASTEXITCODE -ne 0) {
			throw "Windows bridge ABI smoke failed."
		}
	} finally {
		$env:Path = $OldPath
	}
}

function Build-WslTests {
	& (Join-Path $PSScriptRoot "build_native.ps1") -Target Wsl
	if ($LASTEXITCODE -ne 0) {
		throw "WSL native build failed."
	}

	$Wsl = Get-Command wsl.exe -ErrorAction Stop
	$RepoRootWsl = ConvertTo-WslPath $RepoRoot $Wsl.Source
	$Command = @"
cd '$RepoRootWsl' &&
mkdir -p build/native-tests &&
gcc -Wall -Wextra -Werror -Iinclude -I. tests/native/xpact_abi_smoke.c build/native/libxpact.so -o build/native-tests/xpact_abi_smoke &&
gcc -Wall -Wextra -Werror -Iinclude -I. tests/native/xpact_bridge_smoke.c build/native/libxpact.so -o build/native-tests/xpact_bridge_smoke &&
LD_LIBRARY_PATH=build/native build/native-tests/xpact_abi_smoke &&
LD_LIBRARY_PATH=build/native build/native-tests/xpact_bridge_smoke
"@
	& $Wsl.Source -- bash -lc $Command
	if ($LASTEXITCODE -ne 0) {
		throw "WSL native ABI tests failed."
	}
}

if ($Target -eq "Windows" -or $Target -eq "All") {
	Build-WindowsTests
}

if ($Target -eq "Wsl" -or $Target -eq "All") {
	Build-WslTests
}
