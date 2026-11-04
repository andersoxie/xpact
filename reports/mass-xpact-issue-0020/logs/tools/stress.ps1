# stress.ps1 <dll dir name under build> <runs>: the deep-entity test under GC stress; one line per run.
param([string] $Dir, [int] $Runs = 3)
$exe = "C:\xpact\xpact-student-Mass\build\libexpat-native-static\cbuild\Debug\xpact_libexpat_runtests.exe"
$env:EIF_MEMORY_SCAVENGE = "65536"
$env:EIF_FULL_COLLECTION_PERIOD = "1"
$env:PATH = "C:\xpact\xpact-student-Mass\build\$Dir\native-eiffel;$env:PATH"
foreach ($k in 1..$Runs) {
	$t = Measure-Command { $o = & $exe --timeout 600 --test test_deep_nested_attribute_entity 2>&1 | Out-String }
	$r = if ($o -match "Checks: 1, Failed: 0") { "pass" } elseif ($o -match "0x[0-9A-F]{8}") { "crash " + $Matches[0] } else { "fail" }
	"$Dir stress run $k ($([int]$t.TotalSeconds) s): $r"
}
