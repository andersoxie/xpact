Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

ec -batch -config tests\xpact_tests.ecf -target xpact_tests
.\EIFGENs\xpact_tests\W_code\xpact_tests.exe

ec -batch -config benchmarks\xpact_benchmarks.ecf -target xpact_benchmarks
.\EIFGENs\xpact_benchmarks\W_code\xpact_benchmarks.exe
