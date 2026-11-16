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
		# Without -keep, ec -finalize drops every assertion from the system.
		$CompileArgs += @("-finalize", "-keep")
	}
	$CompileArgs += @("-config", $ConfigPath, "-target", $Target)

	Write-Host "== xpact tests: $AssertionLabel / $Mode =="
	$SystemRoot = Join-Path $RepoRoot "EIFGENs\$Target"
	if ($Mode -eq "Finalized") {
		$CodeDir = Join-Path $SystemRoot "F_code"
	} else {
		$CodeDir = Join-Path $SystemRoot "W_code"
	}
	# Two lanes share each target (Workbench, then Finalized). Right after the first, ec can print
	# "Cannot create project directory", leave EIFGENs\<target>\ec.lock and still EXIT 0 without generating
	# code (a file of the fresh build still locked, e.g. by the virus scanner). So a compile counts only if
	# ec exits 0 AND writes a fresh Makefile.SH; otherwise wait, remove the stale lock and retry, at most twice.
	$Lock = Join-Path $SystemRoot "ec.lock"
	$Makefile = Join-Path $CodeDir "Makefile.SH"
	for ($Attempt = 1; $Attempt -le 3; $Attempt++) {
		$Started = Get-Date
		& ec @CompileArgs
		$Fresh = (Test-Path -LiteralPath $Makefile -PathType Leaf) -and ((Get-Item -LiteralPath $Makefile).LastWriteTime -ge $Started)
		if ($LASTEXITCODE -eq 0 -and $Fresh) { break }
		if ($Attempt -lt 3) {
			Write-Host "ec produced no fresh code (exit $LASTEXITCODE, lock: $(Test-Path -LiteralPath $Lock)); retry $Attempt of 2 in 10 s"
			Start-Sleep -Seconds 10
			Remove-Item -LiteralPath $Lock -Force -ErrorAction SilentlyContinue
			continue
		}
		throw "Eiffel compilation failed for $AssertionLabel / $Mode (exit $LASTEXITCODE, fresh code: $Fresh)."
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
# finish_freezing also runs for Workbench lanes; with an MSVC C backend it
# needs cl and link.
if ($SelectedBuildModes -contains "Finalized" -or $env:ISE_C_COMPILER -like "msc*") {
	. (Join-Path $PSScriptRoot "import_msvc_environment.ps1")
}

# ec writes EIFGENs to the current folder and the tests read files relative to
# it, so run every lane from the repository root, wherever the script started.
Push-Location $RepoRoot
try {
	foreach ($AssertionTarget in Selected-AssertionTargets) {
		foreach ($Mode in $SelectedBuildModes) {
			Invoke-TestLane `
				-AssertionLabel $AssertionTarget.Label `
				-Target $AssertionTarget.Target `
				-Mode $Mode
		}
	}
} finally {
	Pop-Location
}

Write-Host "xpact Eiffel test matrix: ok"
