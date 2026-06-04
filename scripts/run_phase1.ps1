Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All

ec -batch -config benchmarks\xpact_benchmarks.ecf -target xpact_benchmarks
.\EIFGENs\xpact_benchmarks\W_code\xpact_benchmarks.exe
