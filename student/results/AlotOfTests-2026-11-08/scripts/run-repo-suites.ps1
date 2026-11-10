# Queue D: the repository's own suites on incremental-test (w13-incremental). Run alone (timing).
$ErrorActionPreference = "Continue"
$Repo = "C:\Users\masou\Desktop\Lia\xpact\w13-incremental"
$Out = Join-Path $PSScriptRoot "repo-suites"
New-Item -ItemType Directory -Force $Out | Out-Null
Set-Location $Repo
function Step($Name, [scriptblock] $Body) {
	$t = Get-Date
	"[$($t.ToString('HH:mm:ss'))] START $Name"
	& $Body *> (Join-Path $Out "$Name.txt")
	$rc = $LASTEXITCODE
	$s = [int]((Get-Date) - $t).TotalSeconds
	"[$((Get-Date).ToString('HH:mm:ss'))] END   $Name rc=$rc ${s}s"
	"$Name rc=$rc seconds=$s" | Add-Content (Join-Path $Out "summary.txt")
}
$Dll = Join-Path $Repo "build\native-eiffel"
$TestExe = Join-Path $Repo "build\dotnet\XpactDllTests\bin\Release\net10.0\XpactDllTests.exe"
Step "dll-tests-build" { dotnet build tests\dotnet\XpactDllTests -c Release -o (Split-Path $TestExe) }
Step "dll-tests-normal" { & $TestExe --dll "$Dll\xpact.dll" --out "$Out\dll-normal" }
Step "dll-tests-assertions" { & $TestExe --dll "$Dll\xpact_assertions.dll" --out "$Out\dll-assertions" }
Step "python-suite" { python -m unittest discover -s tests\python -v }
Step "eiffel-matrix" { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_eiffel_test_matrix.ps1 }
Step "w3c-all-lanes-and-benchmarks" { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions -W3cAllCases -SkipWslC }
"QUEUE D DONE"
