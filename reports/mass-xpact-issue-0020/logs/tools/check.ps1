# Quick type check (workbench melt, no C compile) of the production target; prints the conversion sites.
Set-Location C:\xpact\xpact-student-Mass
$log = "build\static-check.log"
ec -batch -config tests\xpact_native_library.ecf -target xpact_native_library -project_path build\static-check-project *> $log
$py = "C:\Users\masou\AppData\Roaming\uv\python\cpython-3.15.0-windows-x86_64-none\python.exe"
& $py -I C:\Users\masou\AppData\Local\Temp\claude\c--xpact-xpact-student-Mass\a1df27f3-4bcf-4e06-b574-128daf781d5b\scratchpad\obs.py $log
