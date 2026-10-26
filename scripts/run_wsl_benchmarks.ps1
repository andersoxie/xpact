[CmdletBinding()]
param(
	[ValidateRange(1, 2147483647)]
	[int] $Iterations = 10000,
	[ValidateRange(1, 1000)]
	[int] $Repetitions = 5,
	[ValidateSet("Finalized", "FinalizedAssertions", "Workbench")]
	[string[]] $EiffelBuild = @("Finalized", "FinalizedAssertions"),
	[string] $OutputDir = "build\wsl-benchmarks",
	[string] $Distribution = "",
	# Optional Linux shell environment file supplied by the EiffelStudio installation.
	[string] $EiffelEnvironment = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
	[System.IO.Path]::GetFullPath($OutputDir)
} else {
	[System.IO.Path]::GetFullPath((Join-Path $RepoRoot $OutputDir))
}
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
# Invalidate old measurements even when WSL or the environment setup fails.
foreach ($ReportName in @("benchmark-results.tsv", "summary.md", "metadata.json")) {
	$ReportPath = Join-Path $OutputRoot $ReportName
	if (Test-Path -LiteralPath $ReportPath -PathType Leaf) {
		Remove-Item -LiteralPath $ReportPath -Force
	}
}

function ConvertTo-BashLiteral {
	param([string] $Value)
	"'" + $Value.Replace("'", "'`"'`"'") + "'"
}

$Wsl = (Get-Command wsl.exe -ErrorAction Stop).Source
$WslArguments = @()
if (-not [string]::IsNullOrWhiteSpace($Distribution)) {
	$WslArguments += @("--distribution", $Distribution)
}
$Kernel = (& $Wsl @WslArguments --exec uname -r | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $Kernel -notmatch "WSL2") {
	throw "A WSL2 Linux distribution is required. Select one with -Distribution. Kernel: $Kernel"
}

function ConvertTo-WslPath {
	param([string] $Path)
	$Result = (& $Wsl @WslArguments --exec wslpath -a ($Path -replace "\\", "/") | Out-String).Trim()
	if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Result)) {
		throw "Cannot convert path for WSL: $Path"
	}
	$Result
}

$Runner = ConvertTo-WslPath (Join-Path $PSScriptRoot "run_wsl_benchmarks.py")
$OutputWsl = ConvertTo-WslPath $OutputRoot
$Command = "set -e`n"
if (-not [string]::IsNullOrWhiteSpace($EiffelEnvironment)) {
	$Command += "source $(ConvertTo-BashLiteral $EiffelEnvironment)`n"
}
$Command += "exec python3 $(ConvertTo-BashLiteral $Runner) --iterations $Iterations --repetitions $Repetitions --output-dir $(ConvertTo-BashLiteral $OutputWsl)"
foreach ($Build in $EiffelBuild) {
	$Command += " --eiffel-build $(ConvertTo-BashLiteral $Build)"
}
# Encoding avoids differences in native argument quoting between PowerShell 5 and 7,
# including spaces, apostrophes and non-ASCII characters in paths.
$EncodedCommand = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Command))
Write-Host "Building and timing Eiffel/GCC and libexpat inside WSL2. Results: $OutputRoot"
& $Wsl @WslArguments --exec bash -lc "echo $EncodedCommand | base64 --decode | bash"
if ($LASTEXITCODE -ne 0) {
	throw "WSL2 Eiffel/GCC benchmarks failed. See the output above and logs under $OutputRoot. Linux EiffelStudio, GCC, make, Python 3 and libexpat development headers are required; see docs/wsl-benchmarks.md."
}
$global:LASTEXITCODE = 0
