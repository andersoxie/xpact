# build.ps1: the libexpat runner of build\libexpat-native-static relinked with watch.c, plus wselftest.exe (mass-xpact #20).
$ErrorActionPreference = "Stop"
$Out = $PSScriptRoot
$Obj = "C:\xpact\xpact-student-Mass\build\libexpat-native-static\cbuild\xpact_libexpat_runtests.dir\Debug"
$Lib = "C:\xpact\xpact-student-Mass\build\static\native-eiffel\xpact.lib"
$objs = (Get-ChildItem "$Obj\*.obj" | ForEach-Object { "`"$($_.FullName)`"" }) -join " "
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
cmd.exe /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul && cd /d `"$Out`" && cl /nologo /c /O2 /MDd watch.c && link /NOLOGO /DEBUG /INCREMENTAL:NO /SUBSYSTEM:CONSOLE /MACHINE:X64 /OUT:xpact_libexpat_runtests.exe $objs watch.obj `"$Lib`" dbghelp.lib kernel32.lib user32.lib advapi32.lib && cl /nologo /MDd /Od wselftest.c watch.obj dbghelp.lib"
if ($LASTEXITCODE -ne 0) { throw "build failed: $LASTEXITCODE" }
