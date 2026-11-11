param([string]$Out, [string]$TestSource = "threads")
$ErrorActionPreference = "Stop"
$Repo = "C:\xpact\xpact-student-Mass"
. (Join-Path $Repo "scripts\import_msvc_environment.ps1")
Push-Location $Out
cl /nologo /O2 /W3 "/I$Repo\include" "$Repo\reports\issue-0274\$($TestSource).c" /Fe:$($TestSource)-xpact.exe /link "/LIBPATH:$Repo\build\native-eiffel" xpact.lib
Pop-Location
