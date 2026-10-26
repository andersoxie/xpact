# #110: tests on student-Mass @ e8c5cb3 after the sync with main (#101).
# Every step in a fresh powershell, ISE_C_COMPILER=msc_vc140; a failing step
# does not stop the next one.
param([string] $Repo = "C:\Users\masou\Desktop\Lia\xpact3.0\xpact-codex-w3c-xml-conformance-benchmarks")

$Logs = $PSScriptRoot
$Summary = Join-Path $Logs "steps.tsv"
"step`texit`tseconds" | Set-Content -Encoding utf8 $Summary
Set-Location $Repo
$env:ISE_C_COMPILER = "msc_vc140"
$env:Path = "C:\Users\masou\AppData\Local\Programs\Python\Python314\Scripts\;C:\Users\masou\AppData\Local\Programs\Python\Python314\;" + $env:Path

$Msvc = ". .\scripts\import_msvc_environment.ps1; "
$Exe = "`$t = Get-ChildItem build\dotnet\XpactDllTests\bin -Recurse -Filter XpactDllTests.exe | Select-Object -First 1; & `$t.FullName"
$Steps = [ordered]@{
	"1-matrix" = ".\scripts\run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All"
	"2-dll-production" = $Msvc + ".\scripts\build_native_eiffel.ps1"
	"3-dll-assertions" = $Msvc + ".\scripts\build_native_eiffel.ps1 -BuildTier Assertions"
	"4-dll-tests-assertions" = "dotnet build tests\dotnet\XpactDllTests -c Release | Out-Null; " + $Exe
	"5-dll-tests-production" = $Exe + " --dll build\native-eiffel\xpact.dll"
	"6-benchmarks-w3c" = $Msvc + ".\scripts\run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions -SkipWslC"
	"7-python-3.14" = "python --version; python -m unittest discover -s tests/python"
}

foreach ($Name in $Steps.Keys) {
	$Log = Join-Path $Logs "$Name.txt"
	$Start = Get-Date
	"# $($Start.ToString('s'))  $Repo  ISE_C_COMPILER=$env:ISE_C_COMPILER`n# $($Steps[$Name])`n" | Set-Content -Encoding utf8 $Log
	cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -Command `"$($Steps[$Name].Replace('"', '\"'))`" >> `"$Log`" 2>&1"
	$Code = $LASTEXITCODE
	"`n# exit code: $Code" | Add-Content -Encoding utf8 $Log
	"$Name`t$Code`t$([int] ((Get-Date) - $Start).TotalSeconds)" | Add-Content -Encoding utf8 $Summary
}
