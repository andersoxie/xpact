# stress-path.ps1 <dll directory> <runs>: the deep-entity test under GC stress, with that directory first on PATH.
param([string] $Dir, [int] $Runs = 3)
$exe = "C:\xpact\xpact-student-Mass\build\libexpat-native-static\cbuild\Debug\xpact_libexpat_runtests.exe"
if (-not (Test-Path (Join-Path $Dir "xpact.dll"))) { throw "no xpact.dll in $Dir" }
$env:EIF_MEMORY_SCAVENGE = "65536"
$env:EIF_FULL_COLLECTION_PERIOD = "1"
$env:PATH = "$Dir;$env:PATH"
foreach ($k in 1..$Runs) {
	$t = Measure-Command { $o = & $exe --timeout 600 --test test_deep_nested_attribute_entity 2>&1 | Out-String }
	$r = if ($o -match "Checks: 1, Failed: 0") { "pass" } elseif ($o -match "0x[0-9A-F]{8}") { "crash " + $Matches[0] } else { "fail" }
	"$Dir stress run $k ($([int]$t.TotalSeconds) s): $r"
}
