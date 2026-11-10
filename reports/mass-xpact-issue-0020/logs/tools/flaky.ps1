# Repeat test_deep_nested_attribute_entity with each DLL; log the result of every run and the output of failures.
$exe = "C:\xpact\xpact-student-Mass\build\libexpat-native-static\cbuild\Debug\xpact_libexpat_runtests.exe"
$out = "C:\xpact\xpact-student-Mass\build\evidence\flaky"
New-Item -ItemType Directory -Force $out | Out-Null
$old = $env:PATH
foreach ($k in 1..30) {
	foreach ($d in @("inline4", "static")) {
		$env:PATH = "C:\xpact\xpact-student-Mass\build\$d\native-eiffel;$old"
		$o = & $exe --timeout 120 --test test_deep_nested_attribute_entity 2>&1 | Out-String
		$ok = $o -match "Checks: 1, Failed: 0"
		Add-Content "$out\runs.tsv" "$k`t$d`t$ok"
		if (-not $ok) { Set-Content "$out\fail-$d-$k.txt" $o }
	}
}
$env:PATH = $old
"done"
