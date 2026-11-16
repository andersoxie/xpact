# Build the allocation probe (finalized, single-threaded) and run it on the fair-speed inputs, GC on and off.
#   powershell -File reports\perf-allocations\run.ps1 [-Rounds 20] [-SkipBuild]
param([int] $Rounds = 20, [switch] $SkipBuild)
$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
$Repo = (Resolve-Path "$Here\..\..").Path
. (Join-Path $Repo "scripts\import_msvc_environment.ps1") | Out-Null
if ($env:ISE_C_COMPILER -notlike "msc*") { $env:ISE_C_COMPILER = "msc_vc140" }
$Exe = Join-Path $Here "EIFGENs\alloc_probe\F_code\alloc_probe.exe"
if (-not $SkipBuild) {
	Push-Location $Here
	try {
		ec -batch -clean -finalize -c_compile -config probe.ecf -target alloc_probe | Select-Object -Last 2
		if ($LASTEXITCODE -or -not (Test-Path $Exe)) { throw "build failed (exit $LASTEXITCODE)" }
	} finally { Pop-Location }
}
$Inputs = Join-Path $Repo "build\perf-inputs"
if (-not (Test-Path (Join-Path $Inputs "elements-1MB-utf8.xml"))) {
	python -I (Join-Path $Repo "benchmarks\fair_speed\gen_inputs.py") $Inputs | Out-Null
}
foreach ($Name in "elements-1MB-utf8.xml", "attributes-1MB-utf8.xml", "text-1MB-utf8.xml", "dtd-1MB-utf8.xml") {
	$File = Join-Path $Inputs $Name
	"{0,-26} GC on : {1}" -f $Name, (& $Exe $File $Rounds)
	"{0,-26} GC off: {1}" -f $Name, (& $Exe $File $Rounds off)
}
