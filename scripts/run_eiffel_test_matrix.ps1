[CmdletBinding()]
param(
	[ValidateSet("All", "Off", "On")]
	[string] $AssertionMode = "All",
	[ValidateSet("All", "Workbench", "Finalized")]
	[string] $BuildMode = "All"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $RepoRoot "tests\xpact_tests.ecf"

function Selected-AssertionTargets {
	if ($AssertionMode -eq "All" -or $AssertionMode -eq "Off") {
		[pscustomobject]@{
			Label = "assertions-off"
			Target = "xpact_tests"
		}
	}
	if ($AssertionMode -eq "All" -or $AssertionMode -eq "On") {
		[pscustomobject]@{
			Label = "assertions-on"
			Target = "xpact_tests_assertions"
		}
	}
}

function Selected-BuildModes {
	if ($BuildMode -eq "All" -or $BuildMode -eq "Workbench") {
		"Workbench"
	}
	if ($BuildMode -eq "All" -or $BuildMode -eq "Finalized") {
		"Finalized"
	}
}

function Invoke-TestLane {
	param(
		[string] $AssertionLabel,
		[string] $Target,
		[string] $Mode
	)
	$CompileArgs = @("-batch", "-clean")
	if ($Mode -eq "Finalized") {
		$CompileArgs += "-finalize"
	}
	$CompileArgs += @("-config", $ConfigPath, "-target", $Target)

	Write-Host "== xpact tests: $AssertionLabel / $Mode =="
	& ec @CompileArgs
	if ($LASTEXITCODE -ne 0) {
		throw "Eiffel compilation failed for $AssertionLabel / $Mode."
	}

	$SystemRoot = Join-Path $RepoRoot "EIFGENs\$Target"
	if ($Mode -eq "Finalized") {
		$CodeDir = Join-Path $SystemRoot "F_code"
	} else {
		$CodeDir = Join-Path $SystemRoot "W_code"
	}
	if (Test-Path -LiteralPath (Join-Path $CodeDir "Makefile.SH") -PathType Leaf) {
		Push-Location $CodeDir
		try {
			& finish_freezing
			if ($LASTEXITCODE -ne 0) {
				throw "finish_freezing failed for $AssertionLabel / $Mode."
			}
		} finally {
			Pop-Location
		}
	}
	$Exe = Join-Path $CodeDir "xpact_tests.exe"

	if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) {
		throw "Test executable not found: $Exe"
	}
	& $Exe
	if ($LASTEXITCODE -ne 0) {
		throw "Test executable failed for $AssertionLabel / $Mode."
	}
}

$SelectedBuildModes = @(Selected-BuildModes)
if ($SelectedBuildModes -contains "Finalized") {
	. (Join-Path $PSScriptRoot "import_msvc_environment.ps1")
}

foreach ($AssertionTarget in Selected-AssertionTargets) {
	foreach ($Mode in $SelectedBuildModes) {
		Invoke-TestLane `
			-AssertionLabel $AssertionTarget.Label `
			-Target $AssertionTarget.Target `
			-Mode $Mode
	}
}

Write-Host "xpact Eiffel test matrix: ok"
