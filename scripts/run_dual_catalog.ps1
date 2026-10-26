[CmdletBinding()]
param(
    [switch] $Offline,
    [ValidateRange(1, 2147483647)] [int] $Iterations = 1000,
    [ValidateRange(1, 100)] [int] $Pairs = 6,
    [ValidateRange(1, 100)] [int] $Warmups = 2,
    [ValidateRange(0, 60)] [double] $MinSampleSeconds = 1.0,
    [ValidateRange(1, 3600)] [int] $SampleTimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "import_msvc_environment.ps1")
$RunnerArguments = @("--iterations", "$Iterations", "--pairs", "$Pairs", "--warmups", "$Warmups",
                     "--min-sample-seconds", $MinSampleSeconds.ToString([Globalization.CultureInfo]::InvariantCulture),
                     "--sample-timeout-seconds", "$SampleTimeoutSeconds")
if ($Offline) { $RunnerArguments += "--offline" }
& python (Join-Path $PSScriptRoot "run_dual_catalog.py") @RunnerArguments
if ($LASTEXITCODE -ne 0) { throw "Dual catalog failed. See the run.json and logs printed above." }
