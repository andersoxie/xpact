[CmdletBinding()]
param(
    [switch] $Offline,
    [string] $SuiteDirectory = "",
    [ValidateRange(1, 3600)] [int] $TimeoutSeconds = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "import_msvc_environment.ps1")
$RunnerArguments = @("--timeout", "$TimeoutSeconds")
if ($Offline) { $RunnerArguments += "--offline" }
if ($SuiteDirectory) { $RunnerArguments += @("--suite-dir", $SuiteDirectory) }
& python (Join-Path $PSScriptRoot "run_dual_w3c.py") @RunnerArguments
if ($LASTEXITCODE -ne 0) {
    throw "Dual W3C returned $LASTEXITCODE. Parser gaps (exit 1) and incomplete infrastructure (exit 2) are recorded in the printed run directory."
}
