[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $OutputDirectory,
    [Parameter(Mandatory = $true)] [string] $BuildId,
    [switch] $Offline,
    [string] $SuiteDirectory = "",
    [ValidateRange(1, 3600)] [int] $TimeoutSeconds = 10,
    [ValidateRange(1, 2147483647)] [int] $Iterations = 1000,
    [ValidateRange(1, 100)] [int] $Pairs = 6,
    [ValidateRange(1, 100)] [int] $Warmups = 2,
    [ValidateRange(0, 60)] [double] $MinSampleSeconds = 1.0,
    [ValidateRange(1, 3600)] [int] $SampleTimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "import_msvc_environment.ps1")
$RunnerArguments = @("--output-dir", $OutputDirectory, "--build-id", $BuildId,
                     "--timeout", "$TimeoutSeconds", "--iterations", "$Iterations",
                     "--pairs", "$Pairs", "--warmups", "$Warmups", "--min-sample-seconds",
                     $MinSampleSeconds.ToString([Globalization.CultureInfo]::InvariantCulture),
                     "--sample-timeout-seconds", "$SampleTimeoutSeconds")
if ($Offline) { $RunnerArguments += "--offline" }
if ($SuiteDirectory) { $RunnerArguments += @("--suite-dir", $SuiteDirectory) }
& python (Join-Path $PSScriptRoot "run_dual_jenkins.py") @RunnerArguments
$CampaignExitCode = $LASTEXITCODE
if ($CampaignExitCode -ne 0) {
    throw "xpact validation or CI infrastructure returned $CampaignExitCode. Read run.json in $OutputDirectory; both implementations' comparison evidence is retained."
}
