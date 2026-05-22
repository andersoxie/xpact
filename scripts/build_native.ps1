[CmdletBinding()]
param(
	[ValidateSet("Windows", "Wsl", "All")]
	[string] $Target = "Windows",
	[string] $OutputDir = "build\native"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $RepoRoot $OutputDir
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

function ConvertTo-WslPath {
	param(
		[string] $WindowsPath,
		[string] $WslExecutable
	)
	$Normalized = $WindowsPath -replace "\\", "/"
	(& $WslExecutable -- wslpath -a $Normalized | Out-String).Trim()
}

function Build-WindowsDll {
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
	$Source = Join-Path $RepoRoot "native\xpact_native.c"
	$Include = Join-Path $RepoRoot "include"
	$Obj = Join-Path $OutputRoot "xpact_native.obj"
	$Dll = Join-Path $OutputRoot "xpact.dll"
	$Lib = Join-Path $OutputRoot "xpact.lib"
	$Command = "`"$VcVars`" >nul && cl /nologo /LD /O2 /DXPACT_BUILDING_DLL /I`"$Include`" `"$Source`" /Fo`"$Obj`" /Fe`"$Dll`" /link /NOLOGO /IMPLIB:`"$Lib`""
	cmd.exe /c $Command
	if ($LASTEXITCODE -ne 0) {
		throw "Windows native DLL build failed."
	}
	Write-Host "Built $Dll"
}

function Build-WslSo {
	$Wsl = Get-Command wsl.exe -ErrorAction Stop
	$Probe = & $Wsl.Source -- bash -lc "command -v gcc >/dev/null && printf available" 2>$null
	if ($LASTEXITCODE -ne 0 -or (($Probe | Out-String).Trim()) -ne "available") {
		throw "WSL gcc is not available."
	}
	$RepoRootWsl = ConvertTo-WslPath $RepoRoot $Wsl.Source
	$Command = "cd '$RepoRootWsl' && mkdir -p build/native && gcc -shared -fPIC -O2 -DXPACT_BUILDING_DLL -Iinclude native/xpact_native.c -o build/native/libxpact.so"
	& $Wsl.Source -- bash -lc $Command
	if ($LASTEXITCODE -ne 0) {
		throw "WSL native shared object build failed."
	}
	Write-Host "Built $(Join-Path $OutputRoot 'libxpact.so')"
}

if ($Target -eq "Windows" -or $Target -eq "All") {
	Build-WindowsDll
}

if ($Target -eq "Wsl" -or $Target -eq "All") {
	Build-WslSo
}
