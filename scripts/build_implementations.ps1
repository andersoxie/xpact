[CmdletBinding()]
param(
    [ValidateSet("Both", "Xpact", "Xpact-core")]
    [string] $Implementation = "Both",
    [switch] $Offline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "import_msvc_environment.ps1")
$RunnerArguments = @("--implementation", $Implementation.ToLowerInvariant())
if ($Offline) {
    $RunnerArguments += "--offline"
}
& python (Join-Path $PSScriptRoot "build_implementations.py") @RunnerArguments
if ($LASTEXITCODE -ne 0) {
    throw "An implementation build failed. See the run.json path and build logs above."
}
