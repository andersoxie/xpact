[CmdletBinding()]
param(
	[string] $ExpatSourceDir = $env:EXPAT_SOURCE_DIR,
	[ValidateSet("All", "Manifest", "Corpus", "CMake", "NativeSuite")]
	[string] $Mode = "All",
	[string] $OutputDir = "build\libexpat-adapter",
	[string] $XpactLibrary = $env:XPACT_EXPAT_LIBRARY,
	[string] $ExpectedFailuresFile = "adapters\libexpat\expected-failures.tsv",
	[switch] $SkipXpactBuild,
	[switch] $SkipNativeBuild,
	[switch] $FailOnCorpusRejection
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-ExistingDirectory {
	param(
		[string] $Path,
		[string] $Description
	)
	if ([string]::IsNullOrWhiteSpace($Path)) {
		throw "$Description was not provided."
	}
	if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
		throw "$Description does not exist: $Path"
	}
	(Resolve-Path -LiteralPath $Path).Path
}

function Get-ExpatLayout {
	param([string] $Root)
	$NestedTests = Join-Path $Root "expat\tests"
	$FlatTests = Join-Path $Root "tests"
	if (Test-Path -LiteralPath $NestedTests -PathType Container) {
		[pscustomobject]@{
			ExpatDir = (Resolve-Path -LiteralPath (Join-Path $Root "expat")).Path
			TestsDir = (Resolve-Path -LiteralPath $NestedTests).Path
		}
	} elseif (Test-Path -LiteralPath $FlatTests -PathType Container) {
		[pscustomobject]@{
			ExpatDir = $Root
			TestsDir = (Resolve-Path -LiteralPath $FlatTests).Path
		}
	} else {
		throw "Could not find expat\tests or tests below $Root."
	}
}

function Invoke-CheckedCommand {
	param(
		[string] $FilePath,
		[string[]] $Arguments
	)
	& $FilePath @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
	}
}

function Read-ExpectedFailures {
	param([string] $Path)
	$ResolvedPath = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $RepoRoot $Path }
	if (-not (Test-Path -LiteralPath $ResolvedPath -PathType Leaf)) {
		throw "Expected-failure file not found: $ResolvedPath"
	}
	$Rows = New-Object System.Collections.Generic.List[object]
	foreach ($Line in Get-Content -LiteralPath $ResolvedPath) {
		if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith("#")) {
			continue
		}
		if ($Line -eq "source`tname`treason") {
			continue
		}
		$Parts = $Line -split "`t", 3
		if ($Parts.Count -ne 3 -or [string]::IsNullOrWhiteSpace($Parts[0]) -or [string]::IsNullOrWhiteSpace($Parts[1]) -or [string]::IsNullOrWhiteSpace($Parts[2])) {
			throw "Invalid expected-failure row in ${ResolvedPath}: $Line"
		}
		$Rows.Add([pscustomobject]@{
			Source = $Parts[0]
			Name = $Parts[1]
			Reason = $Parts[2]
		})
	}
	$Rows
}

function Get-UpstreamTestSources {
	param([string] $TestsDir)
	$Names = @(
		"acc_tests.c",
		"alloc_tests.c",
		"basic_tests.c",
		"chardata.c",
		"common.c",
		"dummy.c",
		"handlers.c",
		"memcheck.c",
		"minicheck.c",
		"misc_tests.c",
		"ns_tests.c",
		"nsalloc_tests.c",
		"runtests.c",
		"structdata.c"
	)
	foreach ($Name in $Names) {
		$Path = Join-Path $TestsDir $Name
		if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
			throw "Missing upstream Expat test source: $Path"
		}
		Get-Item -LiteralPath $Path
	}
}

function Get-TestManifestRows {
	param(
		[System.IO.FileInfo[]] $Sources
	)
	$Rows = New-Object System.Collections.Generic.List[object]
	$Pattern = "START_TEST\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)"
	foreach ($Source in $Sources) {
		$Text = Get-Content -LiteralPath $Source.FullName -Raw
		foreach ($Match in [regex]::Matches($Text, $Pattern)) {
			$Rows.Add([pscustomobject]@{
				Source = $Source.Name
				Name = $Match.Groups[1].Value
			})
		}
	}
	$Rows
}

function Write-TestManifest {
	param(
		[object[]] $Rows,
		[string] $Destination
	)
	"source`tname" | Set-Content -LiteralPath $Destination -Encoding UTF8
	foreach ($Row in $Rows) {
		"$($Row.Source)`t$($Row.Name)" | Add-Content -LiteralPath $Destination -Encoding UTF8
	}
	Write-Host "libexpat manifest: $($Rows.Count) START_TEST entries -> $Destination"
}

function Write-ExpectedFailureExpansion {
	param(
		[object[]] $ManifestRows,
		[object[]] $ExpectedFailures,
		[string] $Destination
	)
	"source`tname`treason" | Set-Content -LiteralPath $Destination -Encoding UTF8
	$Matched = New-Object System.Collections.Generic.HashSet[string]
	foreach ($Row in $ManifestRows) {
		foreach ($Expected in $ExpectedFailures) {
			if ($Row.Source -like $Expected.Source -and $Row.Name -like $Expected.Name) {
				$Key = "$($Row.Source)`t$($Row.Name)"
				if ($Matched.Add($Key)) {
					"$($Row.Source)`t$($Row.Name)`t$($Expected.Reason)" | Add-Content -LiteralPath $Destination -Encoding UTF8
				}
				break
			}
		}
	}
	Write-Host "libexpat expected failures: $($Matched.Count) manifest entries -> $Destination"
	if ($ExpectedFailures.Count -gt 0 -and $Matched.Count -eq 0) {
		throw "Expected-failure file did not match any upstream START_TEST entries."
	}
}

function Get-CorpusFiles {
	param([string] $ExpatDir)
	$Roots = @(
		(Join-Path $ExpatDir "tests"),
		(Join-Path $ExpatDir "tests\benchmark"),
		(Join-Path $ExpatDir "xmlwf")
	) | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -Unique
	$Seen = @{}
	foreach ($Root in $Roots) {
		Get-ChildItem -LiteralPath $Root -Recurse -File |
			Where-Object { $_.Extension -ieq ".xml" } |
			Sort-Object FullName |
			Where-Object {
				if ($Seen.ContainsKey($_.FullName)) {
					$false
				} else {
					$Seen[$_.FullName] = $true
					$true
				}
			}
	}
}

function Invoke-CorpusRun {
	param(
		[System.IO.FileInfo[]] $Files,
		[string] $XpactExe,
		[string] $Destination
	)
	"file`tstatus`tmessage" | Set-Content -LiteralPath $Destination -Encoding UTF8
	$Rejected = 0
	foreach ($File in $Files) {
		$Output = & $XpactExe --parse-file $File.FullName 2>&1
		$Status = if ($LASTEXITCODE -eq 0) { "accepted" } else { "rejected" }
		if ($Status -eq "rejected") {
			$Rejected += 1
		}
		$Message = (($Output | Out-String).Trim() -replace "`t", " " -replace "`r?`n", " ")
		"$($File.FullName)`t$Status`t$Message" | Add-Content -LiteralPath $Destination -Encoding UTF8
	}
	Write-Host "libexpat corpus: $($Files.Count) XML files, $Rejected rejected -> $Destination"
	if ($FailOnCorpusRejection -and $Rejected -gt 0) {
		throw "$Rejected upstream XML corpus files were rejected by xpact."
	}
}

function Resolve-XpactLibrary {
	param([string] $LibraryPath)
	if (-not [string]::IsNullOrWhiteSpace($LibraryPath)) {
		return $LibraryPath
	}
	$WindowsImportLibrary = Join-Path $RepoRoot "build\native\xpact.lib"
	$SharedObject = Join-Path $RepoRoot "build\native\libxpact.so"
	if (Test-Path -LiteralPath $WindowsImportLibrary -PathType Leaf) {
		return $WindowsImportLibrary
	}
	if (Test-Path -LiteralPath $SharedObject -PathType Leaf) {
		return $SharedObject
	}
	return $null
}

function Invoke-CMakeAdapter {
	param(
		[string] $ExpatRoot,
		[string] $OutputRoot,
		[string] $LibraryPath,
		[switch] $RequireBuildTools
	)
	if ([string]::IsNullOrWhiteSpace($LibraryPath)) {
		$Message = "pass -XpactLibrary or set XPACT_EXPAT_LIBRARY after the native ABI exists."
		if ($RequireBuildTools) {
			throw "Cannot run native C suite: $Message"
		}
		Write-Host "Skipping CMake adapter: $Message"
		return
	}
	$CMake = Get-Command cmake -ErrorAction SilentlyContinue
	if ($null -eq $CMake) {
		if ($RequireBuildTools) {
			throw "Cannot run native C suite: cmake is not on PATH."
		}
		Write-Host "Skipping CMake adapter: cmake is not on PATH."
		return
	}
	$BuildDir = Join-Path $OutputRoot "cbuild"
	New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
	$AdapterDir = Join-Path $RepoRoot "adapters\libexpat"
	$IncludeDir = Join-Path $RepoRoot "include"
	Invoke-CheckedCommand $CMake.Source @(
		"-S", $AdapterDir,
		"-B", $BuildDir,
		"-DEXPAT_SOURCE_DIR=$ExpatRoot",
		"-DXPACT_LIBRARY=$LibraryPath",
		"-DXPACT_INCLUDE_DIR=$IncludeDir"
	)
	Write-Host "Configured C adapter build: $BuildDir"
	$BuildDir
}

function Invoke-NativeSuite {
	param(
		[string] $ExpatRoot,
		[string] $OutputRoot,
		[string] $LibraryPath,
		[object[]] $ExpectedFailures
	)
	if (-not $SkipNativeBuild) {
		Invoke-CheckedCommand "powershell" @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "build_native.ps1"), "-Target", "Windows")
	}
	$ResolvedLibrary = Resolve-XpactLibrary $LibraryPath
	$BuildDir = Invoke-CMakeAdapter $ExpatRoot $OutputRoot $ResolvedLibrary -RequireBuildTools
	$CMake = Get-Command cmake -ErrorAction Stop
	Invoke-CheckedCommand $CMake.Source @("--build", $BuildDir)

	$CTest = Get-Command ctest -ErrorAction Stop
	$LogPath = Join-Path $OutputRoot "libexpat-native-suite.log"
	$RuntimeDir = Split-Path -Parent $ResolvedLibrary
	$OldPath = $env:Path
	try {
		$env:Path = "$RuntimeDir;$OldPath"
		$Output = & $CTest.Source --test-dir $BuildDir --output-on-failure 2>&1
		$ExitCode = $LASTEXITCODE
		($Output | Out-String).Trim() | Set-Content -LiteralPath $LogPath -Encoding UTF8
	} finally {
		$env:Path = $OldPath
	}

	if ($ExitCode -eq 0) {
		if ($ExpectedFailures.Count -gt 0) {
			throw "Native libexpat suite passed while expected failures remain in $ExpectedFailuresFile."
		}
		Write-Host "Native libexpat suite passed."
	} elseif ($ExpectedFailures.Count -gt 0) {
		Write-Host "Native libexpat suite failed as expected; see $LogPath and expected-failure expansion."
	} else {
		throw "Native libexpat suite failed unexpectedly; see $LogPath."
	}
}

$ExpatRoot = Resolve-ExistingDirectory $ExpatSourceDir "Expat source directory"
$Layout = Get-ExpatLayout $ExpatRoot
$OutputRoot = Join-Path $RepoRoot $OutputDir
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

if ($Mode -eq "All" -or $Mode -eq "Manifest") {
	$Sources = @(Get-UpstreamTestSources $Layout.TestsDir)
	$ManifestRows = @(Get-TestManifestRows $Sources)
	Write-TestManifest $ManifestRows (Join-Path $OutputRoot "libexpat-runtests-manifest.tsv")
	$ExpectedFailures = @(Read-ExpectedFailures $ExpectedFailuresFile)
	Write-ExpectedFailureExpansion $ManifestRows $ExpectedFailures (Join-Path $OutputRoot "libexpat-expected-failures-expanded.tsv")
}

if ($Mode -eq "All" -or $Mode -eq "Corpus") {
	if (-not $SkipXpactBuild) {
		Invoke-CheckedCommand "ec" @("-batch", "-config", "xpact.ecf", "-target", "xpact")
	}
	$XpactExe = Join-Path $RepoRoot "EIFGENs\xpact\W_code\xpact.exe"
	if (-not (Test-Path -LiteralPath $XpactExe -PathType Leaf)) {
		throw "xpact executable not found: $XpactExe"
	}
	$CorpusFiles = @(Get-CorpusFiles $Layout.ExpatDir)
	Invoke-CorpusRun $CorpusFiles $XpactExe (Join-Path $OutputRoot "libexpat-corpus-results.tsv")
}

if ($Mode -eq "All" -or $Mode -eq "CMake") {
	$ResolvedLibrary = Resolve-XpactLibrary $XpactLibrary
	Invoke-CMakeAdapter $ExpatRoot $OutputRoot $ResolvedLibrary | Out-Null
}

if ($Mode -eq "NativeSuite") {
	$Sources = @(Get-UpstreamTestSources $Layout.TestsDir)
	$ManifestRows = @(Get-TestManifestRows $Sources)
	Write-TestManifest $ManifestRows (Join-Path $OutputRoot "libexpat-runtests-manifest.tsv")
	$ExpectedFailures = @(Read-ExpectedFailures $ExpectedFailuresFile)
	Write-ExpectedFailureExpansion $ManifestRows $ExpectedFailures (Join-Path $OutputRoot "libexpat-expected-failures-expanded.tsv")
	Invoke-NativeSuite $ExpatRoot $OutputRoot $XpactLibrary $ExpectedFailures
}
