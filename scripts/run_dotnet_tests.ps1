# Runs the .NET test suites that need the Eiffel-backed DLLs, for Jenkins and by hand.
#   .\scripts\run_dotnet_tests.ps1 -Suite Dll       # C# DLL tests, production and assertions DLL
#   .\scripts\run_dotnet_tests.ps1 -Suite Website   # website backend end-to-end tests
# Needs the .NET 10 SDK and build\native-eiffel\xpact*.dll (scripts\build_native_eiffel.ps1, both tiers).
# Exit code 0 only when every case passes.
[CmdletBinding()]
param(
	[Parameter(Mandatory)] [ValidateSet("Dll", "Website")] [string] $Suite,
	[string] $OutputDir = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
$Native = Join-Path $Repo "build\native-eiffel"
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { throw "dotnet not found: install the .NET 10 SDK on this agent." }
foreach ($Name in "xpact.dll", "xpact_assertions.dll") {
	if (-not (Test-Path -LiteralPath (Join-Path $Native $Name))) { throw "$Name not found in $Native. Run scripts\build_native_eiffel.ps1 (both tiers) first." }
}
$Failed = @()

if ($Suite -eq "Dll") {
	if (-not $OutputDir) { $OutputDir = Join-Path $Repo "build\dotnet-dll-tests" }
	$Project = Join-Path $Repo "tests\dotnet\XpactDllTests\XpactDllTests.csproj"
	dotnet build $Project -c Release --nologo -v q
	if ($LASTEXITCODE) { throw "XpactDllTests build failed" }
	foreach ($Tier in @(@{ Name = "production"; Dll = "xpact.dll" }, @{ Name = "assertions"; Dll = "xpact_assertions.dll" })) {
		$Out = Join-Path $OutputDir $Tier.Name
		Write-Host "== C# DLL tests, $($Tier.Name) ($($Tier.Dll))"
		dotnet run --project $Project -c Release --no-build -- --dll (Join-Path $Native $Tier.Dll) --out $Out
		if ($LASTEXITCODE) { $Failed += "DLL tests $($Tier.Name) (exit $LASTEXITCODE)" }
		$Summary = Join-Path $Out "summary.txt"
		if (Test-Path -LiteralPath $Summary) { Get-Content -LiteralPath $Summary | Select-Object -First 15 }
	}
}
else {
	if (-not $OutputDir) { $OutputDir = Join-Path $Repo "build\website-tests" }
	& (Join-Path $Repo "website\scripts\build-dll.ps1") -SkipBuild
	Write-Host "== Website backend tests"
	dotnet test (Join-Path $Repo "website\backend\Xpact.Web.slnx") -c Release --nologo `
		--logger "trx;LogFileName=website-backend.trx" --logger "console;verbosity=normal" --results-directory $OutputDir
	if ($LASTEXITCODE) { $Failed += "website backend tests (exit $LASTEXITCODE)" }
}

if ($Failed.Count) { Write-Host "FAILED: $($Failed -join '; ')" -ForegroundColor Red; exit 1 }
Write-Host "All $Suite tests passed." -ForegroundColor Green
