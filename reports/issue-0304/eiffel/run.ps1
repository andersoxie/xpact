# #304: build the pure-Eiffel thread test (finalized, multi-threaded) and run it with 1, 2, 4, 16 threads.
#   powershell -File reports\issue-0304\eiffel\run.ps1 [-Rounds 4000] [-Repeat 3] [-SkipBuild]
param([int] $Rounds = 4000, [int] $Repeat = 3, [switch] $SkipBuild)
$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
$Repo = (Resolve-Path "$Here\..\..\..").Path
. (Join-Path $Repo "scripts\import_msvc_environment.ps1") | Out-Null
if ($env:ISE_C_COMPILER -notlike "msc*") { $env:ISE_C_COMPILER = "msc_vc140" }
$Exe = Join-Path $Here "EIFGENs\mt_parse_test\F_code\mt_parse_test.exe"
if (-not $SkipBuild) {
	Push-Location $Here
	try {
		ec -batch -clean -finalize -c_compile -config mt_parse_test.ecf -target mt_parse_test | Select-Object -Last 3
		if ($LASTEXITCODE -or -not (Test-Path $Exe)) { throw "build failed (exit $LASTEXITCODE)" }
	} finally { Pop-Location }
}
foreach ($Threads in 1, 2, 4, 16) {
	$Ok = 0; $Crash = 0; $Times = @()
	for ($i = 1; $i -le $Repeat; $i++) {
		$Watch = [Diagnostics.Stopwatch]::StartNew()
		$Out = & $Exe $Threads ([int]($Rounds * 4 / $Threads)) 2>&1
		$Watch.Stop()
		if ($LASTEXITCODE -eq 0 -and "$Out" -match "bad 0") { $Ok++; $Times += $Watch.Elapsed.TotalSeconds } else { $Crash++ }
	}
	$Median = if ($Times.Count) { ($Times | Sort-Object)[[int][Math]::Floor($Times.Count / 2)] } else { "-" }
	"threads {0,2}: {1} ok, {2} failed, median {3} s (total {4} parses)" -f $Threads, $Ok, $Crash, $Median, ($Rounds * 4)
}
