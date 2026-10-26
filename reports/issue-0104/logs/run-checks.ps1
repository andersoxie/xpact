# Full check of the local folder after the 2026-10-26 sync (student-Mass @ 41731c8).
# Same steps as reports/issue-0079/final-steps.txt (minus the Eiffel matrix,
# run separately), plus the C# DLL tests. Every step runs in a fresh
# powershell; a failing step does not stop the next one.
param([string] $Repo = "C:\Users\masou\Desktop\Lia\xpact3.0\xpact-codex-w3c-xml-conformance-benchmarks")

$Logs = $PSScriptRoot
$Summary = Join-Path $Logs "steps.tsv"
"step`texit`tseconds" | Set-Content -Encoding utf8 $Summary
Set-Location $Repo

$Msvc = ". .\scripts\import_msvc_environment.ps1; "
$Steps = [ordered]@{
	"01-python-unit-tests" = "python -m unittest discover -s tests/python"
	"02-dll-production" = $Msvc + ".\scripts\build_native_eiffel.ps1"
	"03-dll-assertions" = $Msvc + ".\scripts\build_native_eiffel.ps1 -BuildTier Assertions"
	"04-native-abi-tests" = $Msvc + ".\scripts\run_native_abi_tests.ps1 -Target Windows"
	"05-native-runtime-smoke" = $Msvc + ".\scripts\run_native_runtime_smoke.ps1"
	"06-chunked-crc-corpus" = $Msvc + ".\scripts\run_chunked_crc_corpus.ps1 -Target Xpact -ParseMode All -SkipBuild"
	"07-incremental-shim-audit" = $Msvc + ".\scripts\run_incremental_shim_audit.ps1 -SkipBuild"
	"08-contributed-examples" = $Msvc + ".\scripts\run_contributed_examples.ps1"
	"09-dotnet-build" = "dotnet build tests\dotnet\XpactDllTests -c Release"
	"10-dll-tests-assertions" = "`$t = Get-ChildItem build\dotnet\XpactDllTests\bin -Recurse -Filter XpactDllTests.exe | Select-Object -First 1; & `$t.FullName"
	"11-dll-tests-production" = "`$t = Get-ChildItem build\dotnet\XpactDllTests\bin -Recurse -Filter XpactDllTests.exe | Select-Object -First 1; & `$t.FullName --dll build\native-eiffel\xpact.dll"
	"12-benchmarks-w3c" = $Msvc + ".\scripts\run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions -SkipWslC"
}

foreach ($Name in $Steps.Keys) {
	$Log = Join-Path $Logs "$Name.txt"
	$Start = Get-Date
	"# $($Start.ToString('s'))  $Repo`n# $($Steps[$Name])`n" | Set-Content -Encoding utf8 $Log
	cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -Command `"$($Steps[$Name].Replace('"', '\"'))`" >> `"$Log`" 2>&1"
	$Code = $LASTEXITCODE
	$Seconds = [int] ((Get-Date) - $Start).TotalSeconds
	"`n# exit code: $Code" | Add-Content -Encoding utf8 $Log
	"$Name`t$Code`t$Seconds" | Add-Content -Encoding utf8 $Summary
}
"done" | Set-Content (Join-Path $Logs "steps.done")
