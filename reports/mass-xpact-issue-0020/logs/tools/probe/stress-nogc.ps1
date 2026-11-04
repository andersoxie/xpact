# stress-nogc.ps1 <dll dir> <runs> <tag>: the deep-entity test with DEFAULT GC settings (no EIF_* stress), probe runner (#20).
# The full output of every run that does not pass goes to out\<tag>-<run>.txt.
param([string] $Dir, [int] $Runs = 3, [string] $Tag = "a")
$exe = Join-Path $PSScriptRoot "xpact_libexpat_runtests.exe"
if (-not (Test-Path (Join-Path $Dir "xpact.dll"))) { throw "no xpact.dll in $Dir" }
$env:XPACT_CRASH_DIR = Join-Path $PSScriptRoot "out"
$env:PATH = "$Dir;$env:PATH"
foreach ($k in 1..$Runs) {
	$t = Measure-Command { $o = & $exe --timeout 1800 --test test_deep_nested_attribute_entity 2>&1 | Out-String }
	$r = if ($o -match "Checks: 1, Failed: 0") { "pass" } elseif ($o -match "0x[0-9A-F]{8}") { "crash " + $Matches[0] } else { "fail" }
	if ($r -ne "pass") { Set-Content -Encoding utf8 -Path (Join-Path $env:XPACT_CRASH_DIR "$Tag-$k.txt") -Value $o }
	"$Tag run $k ($([int]$t.TotalSeconds) s): $r"
}
