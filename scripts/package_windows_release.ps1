[CmdletBinding()]
param(
	[string] $Version = "0.1.0-preview",
	[string] $OutputDir = "dist",
	[switch] $SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ($Version -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
	throw "Version may only contain letters, digits, dot, underscore, and hyphen: $Version"
}
$PackageName = "xpact-$Version-windows-x64"
$OutputRoot = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $OutputDir))
$StageRoot = Join-Path $OutputRoot $PackageName
$ZipPath = Join-Path $OutputRoot "$PackageName.zip"

function Assert-UnderDirectory {
	param(
		[string] $Path,
		[string] $Directory
	)
	$FullPath = [System.IO.Path]::GetFullPath($Path)
	$FullDirectory = [System.IO.Path]::GetFullPath($Directory).TrimEnd('\') + '\'
	if (-not $FullPath.StartsWith($FullDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "Refusing to write outside package output directory: $FullPath"
	}
}

function Require-File {
	param([string] $Path)
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "Required release file not found: $Path"
	}
}

Assert-UnderDirectory $StageRoot $OutputRoot
Assert-UnderDirectory $ZipPath $OutputRoot
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

if (-not $SkipBuild) {
	& (Join-Path $PSScriptRoot "build_native_eiffel.ps1")
	if ($LASTEXITCODE -ne 0) {
		throw "Eiffel-backed Windows DLL build failed."
	}
}

$Dll = Join-Path $RepoRoot "build\native-eiffel\xpact.dll"
$Lib = Join-Path $RepoRoot "build\native-eiffel\xpact.lib"
$Header = Join-Path $RepoRoot "include\xpact.h"
$WindowsReadme = Join-Path $RepoRoot "docs\windows-release.md"
$ProjectReadme = Join-Path $RepoRoot "README.md"
$BenchmarkDoc = Join-Path $RepoRoot "docs\benchmarks.md"
$PerformanceDoc = Join-Path $RepoRoot "docs\performance-analysis.md"
$ApiDoc = Join-Path $RepoRoot "docs\libexpat-api-compatibility.md"
$ParityDoc = Join-Path $RepoRoot "docs\libexpat-parity.md"
$SmokeSource = Join-Path $RepoRoot "tests\native\xpact_eiffel_dll_smoke.c"

Require-File $Dll
Require-File $Lib
Require-File $Header
Require-File $WindowsReadme
Require-File $ProjectReadme
Require-File $BenchmarkDoc
Require-File $PerformanceDoc
Require-File $ApiDoc
Require-File $ParityDoc
Require-File $SmokeSource

if (Test-Path -LiteralPath $StageRoot) {
	Remove-Item -LiteralPath $StageRoot -Recurse -Force
}
if (Test-Path -LiteralPath $ZipPath) {
	Remove-Item -LiteralPath $ZipPath -Force
}

$BinDir = Join-Path $StageRoot "bin"
$LibDir = Join-Path $StageRoot "lib"
$IncludeDir = Join-Path $StageRoot "include"
$ExampleDir = Join-Path $StageRoot "examples"
$DocsDir = Join-Path $StageRoot "docs"
New-Item -ItemType Directory -Force -Path $BinDir, $LibDir, $IncludeDir, $ExampleDir, $DocsDir | Out-Null

Copy-Item -LiteralPath $Dll -Destination (Join-Path $BinDir "xpact.dll")
Copy-Item -LiteralPath $Lib -Destination (Join-Path $LibDir "xpact.lib")
Copy-Item -LiteralPath $Header -Destination (Join-Path $IncludeDir "xpact.h")
Copy-Item -LiteralPath $WindowsReadme -Destination (Join-Path $StageRoot "README-WINDOWS.md")
Copy-Item -LiteralPath $ProjectReadme -Destination (Join-Path $StageRoot "PROJECT-README.md")
Copy-Item -LiteralPath $SmokeSource -Destination (Join-Path $ExampleDir "xpact_eiffel_dll_smoke.c")
Copy-Item -LiteralPath $BenchmarkDoc -Destination (Join-Path $DocsDir "benchmarks.md")
Copy-Item -LiteralPath $PerformanceDoc -Destination (Join-Path $DocsDir "performance-analysis.md")
Copy-Item -LiteralPath $ApiDoc -Destination (Join-Path $DocsDir "libexpat-api-compatibility.md")
Copy-Item -LiteralPath $ParityDoc -Destination (Join-Path $DocsDir "libexpat-parity.md")

$VersionText = @(
	"Package: $PackageName",
	"Version: $Version",
	"Platform: Windows x64",
	"Native artifact: Eiffel-backed xpact.dll",
	"Generated: $((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))"
)
Set-Content -Path (Join-Path $StageRoot "VERSION.txt") -Value $VersionText -Encoding ASCII

$Prefix = $StageRoot.TrimEnd('\') + '\'
$HashLines = Get-ChildItem -Path $StageRoot -Recurse -File |
	Sort-Object FullName |
	ForEach-Object {
		$Relative = $_.FullName.Substring($Prefix.Length).Replace('\', '/')
		$Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
		"$Hash  $Relative"
	}
Set-Content -Path (Join-Path $StageRoot "SHA256SUMS.txt") -Value $HashLines -Encoding ASCII

Compress-Archive -Path $StageRoot -DestinationPath $ZipPath -Force
$ZipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ZipPath).Hash.ToLowerInvariant()

Write-Host "Packaged $ZipPath"
Write-Host "SHA256  $ZipHash"
